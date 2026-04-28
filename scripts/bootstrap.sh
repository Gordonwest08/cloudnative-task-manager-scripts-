
#!/bin/bash
# scripts/bootstrap.sh
# Run once after every terraform apply.
# Usage: ./scripts/bootstrap.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

echo ">>> Reading Terraform outputs..."
CLUSTER_NAME=$(terraform -chdir="$TERRAFORM_DIR" output -raw cluster_name)
REGION="us-east-1"
ALB_ROLE_ARN=$(terraform -chdir="$TERRAFORM_DIR" output -raw alb_controller_role_arn)
EBS_ROLE_ARN=$(terraform -chdir="$TERRAFORM_DIR" output -raw ebs_csi_driver_role_arn)
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Project,Values=taskmanager" \
  --query 'Vpcs[0].VpcId' \
  --output text \
  --region $REGION)

echo "  Cluster : $CLUSTER_NAME"
echo "  Region  : $REGION"
echo "  VPC ID  : $VPC_ID"
echo "  ALB Role: $ALB_ROLE_ARN"
echo "  EBS Role: $EBS_ROLE_ARN"
echo ""

# STEP 1 — Configure kubectl
echo ">>> Configuring kubectl..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"
echo "    Done."

# STEP 2 — Wait for nodes
echo ">>> Waiting for nodes to be Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s
echo "    All nodes Ready."

# STEP 3 — Metrics Server
echo ">>> Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl rollout status deployment/metrics-server \
  -n kube-system --timeout=12000s
echo "    Metrics Server ready."

# STEP 4 — EBS CSI Driver
echo ">>> Installing EBS CSI Driver..."
aws eks create-addon \
  --cluster-name "$CLUSTER_NAME" \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn "$EBS_ROLE_ARN" \
  --resolve-conflicts OVERWRITE \
  --region "$REGION" 2>/dev/null || \
aws eks update-addon \
  --cluster-name "$CLUSTER_NAME" \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn "$EBS_ROLE_ARN" \
  --resolve-conflicts OVERWRITE \
  --region "$REGION"

echo ">>> Waiting for EBS CSI Driver to be active..."
for i in $(seq 1 20); do
  STATUS=$(aws eks describe-addon \
    --cluster-name "$CLUSTER_NAME" \
    --addon-name aws-ebs-csi-driver \
    --region "$REGION" \
    --query 'addon.status' \
    --output text 2>/dev/null)
  echo "    Status: $STATUS"
  if [ "$STATUS" = "ACTIVE" ]; then
    echo "    EBS CSI Driver ready."
    break
  fi
  sleep 30
done

# STEP 5 — cert-manager
echo ">>> Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
echo "    Waiting 30s for cert-manager pods to initialise..."
sleep 30
kubectl wait --for=condition=Ready pods \
  --all -n cert-manager --timeout=120s
echo "    cert-manager ready."

# STEP 6 — ALB Controller Service Account
echo ">>> Creating ALB Controller Service Account..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${ALB_ROLE_ARN}
EOF
echo "    Service account created."

# # STEP 7 — ALB Controller
echo ">>> Installing AWS Load Balancer Controller..."
curl -sLo /tmp/alb-controller.yaml \
  https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.7.2/v2_7_2_full.yaml

# Inject cluster name, VPC ID and region
sed -i "s/--cluster-name=your-cluster-name/--cluster-name=${CLUSTER_NAME}\n        - --aws-vpc-id=${VPC_ID}\n        - --aws-region=${REGION}/g" \
  /tmp/alb-controller.yaml

# CRITICAL: Remove the ServiceAccount from the manifest before applying
# The manifest has empty annotations which overwrites our IAM role annotation
# We created the service account in STEP 6 with the correct annotation
python3 -c "
import yaml, sys

with open('/tmp/alb-controller.yaml', 'r') as f:
    content = f.read()

docs = list(yaml.safe_load_all(content))
filtered = [d for d in docs if d is not None and
            not (d.get('kind') == 'ServiceAccount' and
                 d.get('metadata', {}).get('name') == 'aws-load-balancer-controller')]

with open('/tmp/alb-controller-filtered.yaml', 'w') as f:
    yaml.dump_all(filtered, f, default_flow_style=False)

print(f'Filtered {len(docs) - len(filtered)} ServiceAccount resource(s)')
"

kubectl apply -f /tmp/alb-controller-filtered.yaml
rm /tmp/alb-controller.yaml /tmp/alb-controller-filtered.yaml

echo ">>> Verifying service account annotation is intact..."
kubectl get serviceaccount aws-load-balancer-controller \
  -n kube-system -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
echo ""

echo ">>> Waiting for ALB Controller..."
kubectl rollout status deployment/aws-load-balancer-controller \
  -n kube-system --timeout=180s
echo "    ALB Controller ready."



# STEP 8 — IngressClass
echo ">>> Creating IngressClass..."
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: alb
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: ingress.k8s.aws/alb
EOF
echo "    IngressClass created."

# FINAL — Health check
echo ""
echo "=================================================="
echo "  Bootstrap complete. Cluster health summary:"
echo "=================================================="
echo ""
kubectl get nodes -o wide
echo ""
echo "--- kube-system pods ---"
kubectl get pods -n kube-system
echo ""
echo "--- cert-manager pods ---"
kubectl get pods -n cert-manager
echo ""
kubectl top nodes
echo ""
echo "✅ Cluster ready. Now run:"
echo "   kubectl apply -f k8s/namespaces/"
echo "   kubectl apply -f k8s/database/"
echo "   kubectl apply -f k8s/backend/"
echo "   kubectl apply -f k8s/frontend/"
echo "   kubectl apply -f k8s/ingress/"



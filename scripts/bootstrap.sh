#!/bin/bash
# scripts/bootstrap.sh
#
# Run once after every terraform apply.
# Installs in-cluster components that cannot live in Terraform state.
# Usage: ./scripts/bootstrap.sh

set -euo pipefail

# -------------------------------------------------------------------
# CONFIG — read from Terraform outputs automatically
# -------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

echo ">>> Reading outputs from Terraform state..."
CLUSTER_NAME=$(terraform -chdir="$TERRAFORM_DIR" output -raw cluster_name)
REGION="us-east-1"
ALB_ROLE_ARN=$(terraform -chdir="$TERRAFORM_DIR" output -raw alb_controller_role_arn)
VPC_ID=$(terraform -chdir="$TERRAFORM_DIR" output -raw vpc_id)

echo "  Cluster : $CLUSTER_NAME"
echo "  Region  : $REGION"
echo "  VPC ID  : $VPC_ID"
echo "  ALB Role: $ALB_ROLE_ARN"
echo ""

# -------------------------------------------------------------------
# STEP 1 — Configure kubectl
# -------------------------------------------------------------------
echo ">>> Configuring kubectl..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"
echo "    Done."

# -------------------------------------------------------------------
# STEP 2 — Verify nodes are ready before installing anything
# -------------------------------------------------------------------
echo ">>> Waiting for nodes to be Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s
echo "    All nodes Ready."

# -------------------------------------------------------------------
# -------------------------------------------------------------------
# STEP 3 — Install Metrics Server (Robust Version)
# -------------------------------------------------------------------
echo ">>> Installing Metrics Server..."
# Download locally first to prevent stream timeouts
curl -sLo /tmp/metrics-server.yaml https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Apply with validation turned off to handle network jitter
kubectl apply -f /tmp/metrics-server.yaml --validate=false

# Wait for it to pull the image
echo "Waiting for Metrics Server image to pull..."
sleep 10
kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s
echo "    Metrics Server ready."

# -------------------------------------------------------------------
# STEP 4 — Install cert-manager
# Required by ALB controller for webhook TLS certificates
# Must be fully ready BEFORE the ALB controller is installed
# -------------------------------------------------------------------
echo ">>> Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
echo "    Waiting 30s for cert-manager pods to initialise..."
sleep 30
kubectl wait --for=condition=Ready pods \
  --all \
  -n cert-manager \
  --timeout=120s
echo "    cert-manager ready."

# -------------------------------------------------------------------
# STEP 5 — Create ALB Controller Service Account
# The annotation links it to the IAM role Terraform created
# This is the IRSA binding — pod identity without stored credentials
# -------------------------------------------------------------------
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

# -------------------------------------------------------------------
# STEP 6 — Install AWS Load Balancer Controller
# Translates Kubernetes Ingress resources into real AWS ALBs
# VPC ID and region passed explicitly — avoids IMDSv2 auth issues
# -------------------------------------------------------------------
echo ">>> Installing AWS Load Balancer Controller..."
curl -sLo /tmp/alb-controller.yaml \
  https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.7.2/v2_7_2_full.yaml

# Inject cluster name, VPC ID and region into the controller args
sed -i "s/--cluster-name=your-cluster-name/--cluster-name=${CLUSTER_NAME}\n        - --aws-vpc-id=${VPC_ID}\n        - --aws-region=${REGION}/g" \
  /tmp/alb-controller.yaml

# Apply the full manifest — cert-manager CRDs now exist so no errors
kubectl apply -f /tmp/alb-controller.yaml

rm /tmp/alb-controller.yaml

# Reapply the service account annotation — the manifest overwrites it
kubectl annotate serviceaccount aws-load-balancer-controller \
  -n kube-system \
  eks.amazonaws.com/role-arn=$ALB_ROLE_ARN \
  --overwrite

echo ">>> Waiting for ALB Controller to be ready..."
kubectl rollout status deployment/aws-load-balancer-controller \
  -n kube-system --timeout=180s
echo "    ALB Controller ready."

# -------------------------------------------------------------------
# FINAL — Health check
# -------------------------------------------------------------------
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
echo "✅ Ready to apply k8s/ manifests."
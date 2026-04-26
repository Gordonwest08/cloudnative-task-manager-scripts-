#!/bin/bash
# scripts/destroy.sh
# Clean teardown of all infrastructure
# Usage: ./scripts/destroy.sh

set -euo pipefail

echo "⚠️  This will destroy ALL infrastructure."
echo "    Press Ctrl+C within 5 seconds to cancel..."
sleep 5

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

# Step 1 — Delete ingress (releases ALB)
echo ">>> Deleting ingress (releasing AWS ALB)..."
kubectl delete ingress taskmanager-ingress \
  -n production 2>/dev/null || true
echo "    Waiting 30s for ALB to be released..."
sleep 30

# Step 2 — Delete namespaces
echo ">>> Deleting namespaces..."
kubectl delete namespace production 2>/dev/null || true
kubectl delete namespace monitoring 2>/dev/null || true

# Step 3 — Delete ALB controller
echo ">>> Deleting ALB controller..."
kubectl delete deployment aws-load-balancer-controller \
  -n kube-system 2>/dev/null || true
kubectl delete mutatingwebhookconfiguration \
  aws-load-balancer-webhook 2>/dev/null || true
kubectl delete validatingwebhookconfiguration \
  aws-load-balancer-webhook 2>/dev/null || true
kubectl delete ingressclass alb 2>/dev/null || true

# Step 4 — Delete cert-manager
echo ">>> Deleting cert-manager..."
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml \
  2>/dev/null || true

# Step 5 — Delete EBS CSI addon
echo ">>> Deleting EBS CSI addon..."
aws eks delete-addon \
  --cluster-name taskmanager-cluster \
  --addon-name aws-ebs-csi-driver \
  --region us-east-1 2>/dev/null || true
echo "    Waiting 30s for addon deletion..."
sleep 30

# Step 6 — Terraform destroy
echo ">>> Running terraform destroy..."
cd "$TERRAFORM_DIR"
terraform destroy -var-file="terraform.tfvars"

# Step 7 — Verify
echo ""
echo ">>> Verifying cleanup..."
echo "EKS clusters remaining:"
aws eks list-clusters --region us-east-1

echo "VPCs remaining:"
aws ec2 describe-vpcs \
  --filters "Name=tag:Project,Values=taskmanager" \
  --query 'Vpcs[*].VpcId' \
  --output text

echo ""
echo "✅ Teardown complete. See you next time!"
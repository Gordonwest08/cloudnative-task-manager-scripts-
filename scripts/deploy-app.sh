
#!/bin/bash
# scripts/deploy-app.sh
#
# Run after terraform apply + bootstrap.sh
# Builds and pushes images, applies k8s manifests,
# updates deployments with correct image tags and ALB URL
#
# Usage: ./scripts/deploy-app.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
TERRAFORM_DIR="$ROOT_DIR/terraform"

# -------------------------------------------------------------------
# CONFIG
# -------------------------------------------------------------------
echo ">>> Reading configuration..."
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_TAG=$(git -C "$ROOT_DIR" rev-parse --short HEAD)

echo "  Account  : $AWS_ACCOUNT_ID"
echo "  Registry : $ECR_REGISTRY"
echo "  Image tag: $IMAGE_TAG"
echo ""

# -------------------------------------------------------------------
# STEP 1 — Apply namespaces and database first
# -------------------------------------------------------------------
echo ">>> Applying Kubernetes namespaces..."
kubectl apply -f "$ROOT_DIR/k8s/namespaces/"

echo ">>> Applying database manifests..."
kubectl apply -f "$ROOT_DIR/k8s/database/"

echo ">>> Waiting for PostgreSQL to be ready..."
kubectl rollout status statefulset/postgres \
  -n production --timeout=120s
echo "    PostgreSQL ready."

# -------------------------------------------------------------------
# STEP 2 — Apply backend and frontend manifests
# (uses whatever image tag is currently in the yaml)
# -------------------------------------------------------------------
echo ">>> Applying backend manifests..."
kubectl apply -f "$ROOT_DIR/k8s/backend/"

echo ">>> Applying frontend manifests..."
kubectl apply -f "$ROOT_DIR/k8s/frontend/"

# -------------------------------------------------------------------
# STEP 3 — Apply ingress
# -------------------------------------------------------------------
echo ">>> Applying ingress..."
kubectl apply -f "$ROOT_DIR/k8s/ingress/"

# -------------------------------------------------------------------
# STEP 4 — Authenticate to ECR
# -------------------------------------------------------------------
echo ">>> Authenticating to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login \
  --username AWS \
  --password-stdin "$ECR_REGISTRY"
echo "    Authenticated."

# -------------------------------------------------------------------
# STEP 5 — Build and push backend
# -------------------------------------------------------------------
echo ">>> Building backend image..."
cd "$ROOT_DIR/app/backend"
docker build \
  -t "$ECR_REGISTRY/taskmanager/backend:$IMAGE_TAG" \
  -t "$ECR_REGISTRY/taskmanager/backend:latest" \
  .

echo ">>> Pushing backend image..."
docker push "$ECR_REGISTRY/taskmanager/backend:$IMAGE_TAG"
docker push "$ECR_REGISTRY/taskmanager/backend:latest"
echo "    Backend pushed: $IMAGE_TAG"

# -------------------------------------------------------------------
# STEP 6 — Wait for ALB URL to be available
# -------------------------------------------------------------------
echo ">>> Waiting for ALB URL to be provisioned..."
ALB_URL=""
for i in $(seq 1 20); do
  ALB_URL=$(kubectl get ingress taskmanager-ingress \
    -n production \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
    2>/dev/null || echo "")

  if [ -n "$ALB_URL" ]; then
    echo "    ALB URL: http://$ALB_URL"
    break
  fi

  echo "    Waiting... attempt $i/20"
  sleep 30
done

if [ -z "$ALB_URL" ]; then
  echo "⚠️  ALB URL not available after 10 minutes"
  echo "    Building frontend with placeholder URL"
  ALB_URL="localhost:5000"
fi

# -------------------------------------------------------------------
# STEP 7 — Build and push frontend with correct ALB URL
# -------------------------------------------------------------------
echo ">>> Building frontend image with ALB URL: http://$ALB_URL"
cd "$ROOT_DIR/app/frontend"
docker build \
  --build-arg VITE_API_URL="http://$ALB_URL" \
  -t "$ECR_REGISTRY/taskmanager/frontend:$IMAGE_TAG" \
  -t "$ECR_REGISTRY/taskmanager/frontend:latest" \
  .

echo ">>> Pushing frontend image..."
docker push "$ECR_REGISTRY/taskmanager/frontend:$IMAGE_TAG"
docker push "$ECR_REGISTRY/taskmanager/frontend:latest"
echo "    Frontend pushed: $IMAGE_TAG"

# -------------------------------------------------------------------
# STEP 8 — Update deployments with new image tags
# -------------------------------------------------------------------
echo ">>> Updating backend deployment..."
kubectl set image deployment/backend \
  backend="$ECR_REGISTRY/taskmanager/backend:$IMAGE_TAG" \
  -n production

kubectl rollout status deployment/backend \
  -n production --timeout=120s

echo ">>> Updating frontend deployment..."
kubectl set image deployment/frontend \
  frontend="$ECR_REGISTRY/taskmanager/frontend:$IMAGE_TAG" \
  -n production

kubectl rollout restart deployment/frontend -n production

kubectl rollout status deployment/frontend \
  -n production --timeout=120s

# -------------------------------------------------------------------
# STEP 9 — Update yaml files with current image tag
# -------------------------------------------------------------------
echo ">>> Updating deployment yaml files with current image tag..."
sed -i "s|taskmanager/backend:.*|taskmanager/backend:$IMAGE_TAG|g" \
  "$ROOT_DIR/k8s/backend/deployment.yaml"
sed -i "s|taskmanager/frontend:.*|taskmanager/frontend:$IMAGE_TAG|g" \
  "$ROOT_DIR/k8s/frontend/deployment.yaml"

# -------------------------------------------------------------------
# FINAL — Health check
# -------------------------------------------------------------------
echo ""
echo "=================================================="
echo "  Deployment complete. Application summary:"
echo "=================================================="
echo ""
kubectl get pods -n production
echo ""
echo "  Application URL : http://$ALB_URL"
echo "  Backend health  : $(curl -s http://$ALB_URL/health | python3 -c 'import sys,json; print(json.load(sys.stdin)["status"])' 2>/dev/null || echo 'not ready yet')"
echo ""
echo "✅ Application deployed successfully."
echo ""
echo "Next steps:"
echo "  Deploy monitoring : ./scripts/deploy-monitoring.sh"
echo "  Access Grafana    : ./scripts/port-forward-grafana.sh"



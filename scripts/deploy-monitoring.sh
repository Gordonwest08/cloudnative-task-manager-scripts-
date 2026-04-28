
#!/bin/bash
# scripts/deploy-monitoring.sh
# Deploy monitoring stack to the cluster
# Usage: ./scripts/deploy-monitoring.sh

set -euo pipefail

echo ">>> Deploying monitoring stack..."

kubectl apply -f k8s/monitoring/prometheus/rbac.yaml
kubectl apply -f k8s/monitoring/prometheus/configmap.yaml
kubectl apply -f k8s/monitoring/prometheus/pvc.yaml
kubectl apply -f k8s/monitoring/prometheus/deployment.yaml
kubectl apply -f k8s/monitoring/prometheus/service.yaml

kubectl apply -f k8s/monitoring/grafana/secret.yaml
kubectl apply -f k8s/monitoring/grafana/configmap.yaml
kubectl apply -f k8s/monitoring/grafana/pvc.yaml
kubectl apply -f k8s/monitoring/grafana/deployment.yaml
kubectl apply -f k8s/monitoring/grafana/service.yaml

echo ">>> Waiting for monitoring pods..."
kubectl rollout status deployment/prometheus \
  -n monitoring --timeout=120s
kubectl rollout status deployment/grafana \
  -n monitoring --timeout=120s

echo ""
kubectl get pods -n monitoring
echo ""
echo "✅ Monitoring ready."
echo "   Run: ./scripts/port-forward-grafana.sh"
echo "   Then open: http://localhost:3000"
echo "   User: admin / Pass: taskmanager123"
EOF


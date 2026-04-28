#!/bin/bash
# scripts/port-forward-grafana.sh
# Access Grafana locally without exposing it to the internet
# Usage: ./scripts/port-forward-grafana.sh

echo "Starting port-forward to Grafana..."
echo "Open: http://localhost:3000"
echo "User: admin"
echo "Pass: taskmanager123"
echo ""
echo "Press Ctrl+C to stop"

kubectl port-forward \
  service/grafana-service \
  3000:3000 \
  -n monitoring

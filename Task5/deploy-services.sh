#!/usr/bin/env bash
# Развёртывание четырёх сервисов (nginx) с метками-ролями в namespace default.
set -euo pipefail

for role in front-end back-end-api admin-front-end admin-back-end-api; do
  if ! kubectl get pod "$role-app" >/dev/null 2>&1; then
    kubectl run "$role-app" --image=nginx --labels "role=$role" --expose --port 80
  fi
done

kubectl wait --for=condition=Ready pod -l 'role in (front-end,back-end-api,admin-front-end,admin-back-end-api)' --timeout=180s
kubectl get pods,svc --show-labels

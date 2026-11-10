#!/usr/bin/env bash
# Связывание групп пользователей с ролями (ClusterRoleBinding / RoleBinding).
# Запуск: ./03-bind-roles.sh   (после 02-create-roles.sh, под админским контекстом)
set -euo pipefail

# ---------- Кластерные привязки ----------
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: propdev-cluster-admins, labels: {propdev.io/rbac: "true"}}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: propdev-cluster-admin}
subjects:
  - {apiGroup: rbac.authorization.k8s.io, kind: Group, name: "propdev:cluster-admins"}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: propdev-security-officers-secrets, labels: {propdev.io/rbac: "true"}}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: propdev-secrets-reader}
subjects:
  - {apiGroup: rbac.authorization.k8s.io, kind: Group, name: "propdev:security-officers"}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: propdev-platform-engineers, labels: {propdev.io/rbac: "true"}}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: propdev-cluster-configurator}
subjects:
  - {apiGroup: rbac.authorization.k8s.io, kind: Group, name: "propdev:platform-engineers"}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: propdev-cluster-viewers, labels: {propdev.io/rbac: "true"}}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: propdev-cluster-viewer}
subjects:
  - {apiGroup: rbac.authorization.k8s.io, kind: Group, name: "propdev:cluster-viewers"}
  - {apiGroup: rbac.authorization.k8s.io, kind: Group, name: "propdev:security-officers"}
EOF

# ---------- Привязки в namespace доменов ----------
for ns in sales housing finance data; do
  kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: propdev-$ns-devops, namespace: $ns, labels: {propdev.io/rbac: "true"}}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: propdev-namespace-deployer}
subjects:
  - {apiGroup: rbac.authorization.k8s.io, kind: Group, name: "propdev:$ns-devops"}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: propdev-$ns-developers, namespace: $ns, labels: {propdev.io/rbac: "true"}}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: propdev-namespace-viewer}
subjects:
  - {apiGroup: rbac.authorization.k8s.io, kind: Group, name: "propdev:$ns-developers"}
EOF
done

echo "Привязки созданы:"
kubectl get clusterrolebindings -l propdev.io/rbac=true
kubectl get rolebindings -A -l propdev.io/rbac=true

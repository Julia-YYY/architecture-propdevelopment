#!/usr/bin/env bash
# Создание namespaces доменов PropDevelopment и ролей (ClusterRole) из таблицы roles.md.
# Запуск: ./02-create-roles.sh   (под админским контекстом)
set -euo pipefail

kubectl apply -f - <<'EOF'
# ---------- Namespaces по оргструктуре (доменам) ----------
apiVersion: v1
kind: Namespace
metadata: {name: sales, labels: {propdev.io/domain: sales}}
---
apiVersion: v1
kind: Namespace
metadata: {name: housing, labels: {propdev.io/domain: housing}}
---
apiVersion: v1
kind: Namespace
metadata: {name: finance, labels: {propdev.io/domain: finance}}
---
apiVersion: v1
kind: Namespace
metadata: {name: data, labels: {propdev.io/domain: data}}
---
# ---------- 1. Полный доступ (break-glass) ----------
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-cluster-admin
  labels: {propdev.io/rbac: "true"}
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
  - nonResourceURLs: ["*"]
    verbs: ["*"]
---
# ---------- 2. Привилегированная роль: просмотр секретов ----------
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-secrets-reader
  labels: {propdev.io/rbac: "true"}
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "watch"]
---
# ---------- 3. Настройка кластера (без секретов и без RBAC) ----------
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-cluster-configurator
  labels: {propdev.io/rbac: "true"}
rules:
  - apiGroups: [""]
    resources: ["namespaces", "resourcequotas", "limitranges", "persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch", "patch", "update"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["networkpolicies", "ingresses", "ingressclasses"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["scheduling.k8s.io"]
    resources: ["priorityclasses"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apiextensions.k8s.io"]
    resources: ["customresourcedefinitions"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["policy"]
    resources: ["poddisruptionbudgets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  # просмотр рабочих нагрузок для диагностики
  - apiGroups: [""]
    resources: ["pods", "pods/log", "services", "endpoints", "configmaps", "events", "serviceaccounts", "persistentvolumeclaims"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps", "batch"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
---
# ---------- 4. Только просмотр всего кластера (без секретов) ----------
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-cluster-viewer
  labels: {propdev.io/rbac: "true"}
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "services", "endpoints", "configmaps", "events", "namespaces", "nodes",
                "persistentvolumes", "persistentvolumeclaims", "resourcequotas", "limitranges",
                "serviceaccounts", "replicationcontrollers"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps", "batch", "autoscaling", "policy", "networking.k8s.io", "storage.k8s.io", "discovery.k8s.io"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
---
# ---------- 5. Деплой в namespace своего домена (через RoleBinding) ----------
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-namespace-deployer
  labels: {propdev.io/rbac: "true"}
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "persistentvolumeclaims", "serviceaccounts"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["pods/log", "events", "endpoints"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods/exec", "pods/portforward"]
    verbs: ["create", "get"]
  # секреты: только запись/ротация, без чтения
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["create", "update", "patch", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets", "daemonsets", "replicasets", "deployments/scale", "statefulsets/scale"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["networkpolicies"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
# ---------- 6. Просмотр namespace своего домена (через RoleBinding) ----------
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-namespace-viewer
  labels: {propdev.io/rbac: "true"}
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "services", "endpoints", "configmaps", "events", "persistentvolumeclaims"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps", "batch", "autoscaling"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses", "networkpolicies"]
    verbs: ["get", "list", "watch"]
EOF

echo "Роли созданы:"
kubectl get clusterroles -l propdev.io/rbac=true

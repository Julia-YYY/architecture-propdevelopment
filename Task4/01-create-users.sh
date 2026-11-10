#!/usr/bin/env bash
# Создание пользователей Kubernetes (x509-сертификаты) для Minikube.
# CN сертификата = имя пользователя, O = группы (по ним выдаются роли).
# Запуск: ./01-create-users.sh   (текущий контекст kubectl должен быть админским, например minikube)
set -euo pipefail

CERT_DIR="${CERT_DIR:-$(cd "$(dirname "$0")" && pwd)/users}"
CLUSTER="$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')"
SERVER_CTX="$(kubectl config current-context)"
MINIKUBE_CA_DIR="${MINIKUBE_HOME:-$HOME}/.minikube"

# пользователь:группа1,группа2
USERS=(
  "alexey:propdev:cluster-admins"
  "irina:propdev:security-officers,propdev:cluster-viewers"
  "pavel:propdev:platform-engineers"
  "maria:propdev:cluster-viewers"
  "olga:propdev:sales-devops"
  "dmitry:propdev:housing-developers"
)

mkdir -p "$CERT_DIR"
echo "Кластер: $CLUSTER (контекст $SERVER_CTX), сертификаты: $CERT_DIR"

sign_with_csr_api() {
  local user="$1" csr_file="$2" crt_file="$3"
  kubectl delete csr "propdev-$user" --ignore-not-found >/dev/null
  cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: propdev-$user
spec:
  request: $(base64 < "$csr_file" | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 31536000
  usages: ["client auth"]
EOF
  kubectl certificate approve "propdev-$user" >/dev/null
  for _ in $(seq 1 15); do
    local cert
    cert="$(kubectl get csr "propdev-$user" -o jsonpath='{.status.certificate}')"
    if [ -n "$cert" ]; then
      echo "$cert" | openssl base64 -d -A > "$crt_file"
      return 0
    fi
    sleep 2
  done
  return 1
}

sign_with_minikube_ca() {
  local csr_file="$1" crt_file="$2"
  [ -f "$MINIKUBE_CA_DIR/ca.crt" ] && [ -f "$MINIKUBE_CA_DIR/ca.key" ] || return 1
  openssl x509 -req -in "$csr_file" -CA "$MINIKUBE_CA_DIR/ca.crt" -CAkey "$MINIKUBE_CA_DIR/ca.key" \
    -CAcreateserial -out "$crt_file" -days 365 2>/dev/null
}

for entry in "${USERS[@]}"; do
  user="${entry%%:*}"
  groups="${entry#*:}"
  subj="/CN=$user"
  IFS=',' read -r -a group_list <<< "$groups"
  for g in "${group_list[@]}"; do subj="$subj/O=$g"; done

  key="$CERT_DIR/$user.key"; csr="$CERT_DIR/$user.csr"; crt="$CERT_DIR/$user.crt"
  openssl genrsa -out "$key" 2048 2>/dev/null
  # MSYS_NO_PATHCONV: не даём Git Bash на Windows превратить "/CN=..." в путь
  MSYS_NO_PATHCONV=1 openssl req -new -key "$key" -out "$csr" -subj "$subj"

  if sign_with_csr_api "$user" "$csr" "$crt"; then
    how="CSR API"
  elif sign_with_minikube_ca "$csr" "$crt"; then
    how="CA minikube"
  else
    echo "ОШИБКА: не удалось подписать сертификат для $user" >&2
    exit 1
  fi

  kubectl config set-credentials "$user" --client-certificate="$crt" --client-key="$key" --embed-certs=true >/dev/null
  kubectl config set-context "$user@$CLUSTER" --cluster="$CLUSTER" --user="$user" >/dev/null
  echo "  + $user  [$groups]  (подписан: $how, контекст: $user@$CLUSTER)"
done

kubectl config use-context "$SERVER_CTX" >/dev/null
echo "Готово. Пример: kubectl --context=maria@$CLUSTER get pods -A"

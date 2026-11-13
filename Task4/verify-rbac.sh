#!/usr/bin/env bash
# Проверка ролевой модели: выполняет kubectl auth can-i от имени каждого созданного пользователя
# (через его собственный контекст и сертификат) и сравнивает с ожидаемым результатом.
# Запуск: ./verify-rbac.sh   (после 01..03)
set -uo pipefail

CLUSTER="$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')"
fail=0

check() { # user expected verb resource [namespace]
  local user="$1" expected="$2" verb="$3" res="$4" ns="${5:-}"
  local args=("$verb" "${res%%/*}")
  # подресурсы (pods/log, pods/exec) передаются через --subresource, иначе "pods/log" = pod с именем log
  if [[ "$res" == */* ]]; then args+=(--subresource="${res#*/}"); fi
  if [ -n "$ns" ]; then args+=(-n "$ns"); else args+=(--all-namespaces); fi
  local got
  got="$(kubectl --context="$user@$CLUSTER" auth can-i "${args[@]}" 2>/dev/null | head -1)"
  [ -z "$got" ] && got="no"
  local mark="OK  "
  if [ "$got" != "$expected" ]; then mark="FAIL"; fail=1; fi
  printf '%s %-7s %-6s %-26s %-8s ожидалось=%-3s получено=%s\n' "$mark" "$user" "$verb" "$res" "${ns:-*}" "$expected" "$got"
}

# администратор
check alexey yes delete  nodes
check alexey yes get     secrets
check alexey yes create  clusterrolebindings
# ИБ: видит всё, включая секреты, но ничего не меняет
check irina  yes get     secrets            sales
check irina  yes list    pods
check irina  no  delete  pods               sales
check irina  no  create  deployments        housing
# платформенный инженер: настраивает кластер, секретов не видит, RBAC не меняет
check pavel  yes create  namespaces
check pavel  yes create  networkpolicies    housing
check pavel  yes create  resourcequotas     finance
check pavel  no  get     secrets            sales
check pavel  no  create  clusterrolebindings
# только просмотр
check maria  yes list    pods
check maria  yes list    deployments.apps
check maria  no  get     secrets            sales
check maria  no  create  pods               sales
check maria  no  create  pods/exec          sales
# DevOps домена продаж: деплой только в sales, секреты только на запись
check olga   yes create  deployments.apps   sales
check olga   yes create  secrets            sales
check olga   no  get     secrets            sales
check olga   no  create  deployments.apps   housing
check olga   no  list    pods               finance
# разработчик ЖКУ: только просмотр своего namespace
check dmitry yes list    pods               housing
check dmitry yes get     pods/log           housing
check dmitry no  create  deployments.apps   housing
check dmitry no  list    pods               sales
check dmitry no  get     secrets            housing

echo
if [ "$fail" -eq 0 ]; then echo "ИТОГ: все проверки пройдены"; else echo "ИТОГ: есть расхождения (FAIL)"; fi
exit "$fail"

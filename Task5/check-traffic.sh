#!/usr/bin/env bash
# Автоматическая проверка сетевых политик: из временного пода alpine с заданной меткой role
# выполняется wget к каждому сервису, результат сравнивается с ожидаемым.
set -uo pipefail

ROLES=(front-end back-end-api admin-front-end admin-back-end-api)
fail=0

expected() { # from to -> allow|deny
  case "$1>$2" in
    "front-end>back-end-api"|"back-end-api>front-end"|\
    "admin-front-end>admin-back-end-api"|"admin-back-end-api>admin-front-end") echo allow ;;
    *) echo deny ;;
  esac
}

probe() { # label target-service -> allow|deny
  local labels="$1" target="$2"
  local out
  out="$(kubectl run "test-$RANDOM" --rm -i --restart=Never --image=alpine $labels --quiet \
          -- wget -qO- -T 2 "http://$target" 2>&1)"
  if echo "$out" | grep -q "Welcome to nginx"; then echo allow; else echo deny; fi
}

for from in "${ROLES[@]}" none; do
  for to in "${ROLES[@]}"; do
    [ "$from" = "$to" ] && continue
    if [ "$from" = "none" ]; then labels=""; exp="deny"; else labels="--labels=role=$from"; exp="$(expected "$from" "$to")"; fi
    got="$(probe "$labels" "$to-app")"
    mark="OK  "; [ "$got" != "$exp" ] && { mark="FAIL"; fail=1; }
    printf '%s %-20s -> %-22s ожидалось=%-5s получено=%s\n' "$mark" "$from" "$to-app" "$exp" "$got"
  done
done

echo
if [ "$fail" -eq 0 ]; then echo "ИТОГ: все проверки пройдены"; else echo "ИТОГ: есть расхождения (FAIL)"; fi
exit "$fail"

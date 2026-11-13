# Задание 4. Ролевая модель доступа к Kubernetes

## Организационная модель в кластере

Доступ разграничен по оргструктуре компании, то есть по доменам. Каждому домену соответствует свой namespace:

| Namespace | Домен | Что разворачивается |
| --- | --- | --- |
| `sales` | Группа сервисов для продаж | витрина, client-crm-app, client-mart-app, client-mart-estate-app, client-tour-app, auth-service-1 |
| `housing` | Группа сервисов ЖКУ | витрина собственников (BFF), tenant-core-app, CRM, smart-home-service, partner-integration-gateway |
| `finance` | Финансы | accountant-service-1 |
| `data` | Дата | ETL/CDC, BI |

Группы пользователей передаются в кластер через поле `O` (Organization) клиентского сертификата. В продуктиве то же самое делается через claim `groups` в OIDC-токене (Keycloak или AD). Все привязки ролей сделаны **к группам, а не к людям**: при смене сотрудника меняется только его членство в группе. Это закрывает проблему потери информации при смене руководителей команд.

## Роли

| Роль | Права роли | Группы пользователей |
| --- | --- | --- |
| `propdev-cluster-admin` (ClusterRole + ClusterRoleBinding) | Полный доступ ко всем ресурсам кластера (`*` на `*`), включая RBAC, секреты и узлы. Учётная запись break-glass: использование только по заявке, с MFA и обязательным аудитом | `propdev:cluster-admins` — руководитель эксплуатации и 1–2 ведущих платформенных инженера |
| `propdev-secrets-reader` (ClusterRole + ClusterRoleBinding) — **привилегированная** | `get`, `list`, `watch` на `secrets` во всех namespace. Других прав нет, роль выдаётся вместе с `propdev-cluster-viewer` | `propdev:security-officers` — специалист ИБ (аудит секретов, расследование инцидентов) |
| `propdev-cluster-configurator` (ClusterRole + ClusterRoleBinding) | **Настройка кластера.** Полное управление (`create/update/patch/delete`) ресурсами `namespaces`, `resourcequotas`, `limitranges`, `networkpolicies`, `ingresses`, `ingressclasses`, `storageclasses`, `persistentvolumes`, `priorityclasses`, `customresourcedefinitions`, `poddisruptionbudgets`, `horizontalpodautoscalers`. По узлам — `get/list/watch/patch` (cordon, метки, taints). Просмотр workload-ресурсов. **Нельзя:** читать секреты и менять RBAC (защита от эскалации привилегий) | `propdev:platform-engineers` — DevOps-инженеры платформенной команды |
| `propdev-cluster-viewer` (ClusterRole + ClusterRoleBinding) | **Только просмотр.** `get/list/watch` на все основные ресурсы (pods, pods/log, services, deployments, statefulsets, jobs, configmaps, events, nodes, namespaces, ingresses, networkpolicies, PV/PVC, quotas) во всех namespace. **Секреты недоступны**, `exec` и `port-forward` запрещены | `propdev:cluster-viewers` — инженеры по эксплуатации всех доменов, бизнес-аналитики, специалист ИБ, внешние аудиторы на время аудита |
| `propdev-namespace-deployer` (ClusterRole, выдаётся через **RoleBinding в namespace своего домена**) | В пределах своего namespace: полное управление `deployments`, `statefulsets`, `daemonsets`, `replicasets`, `pods`, `services`, `configmaps`, `jobs`, `cronjobs`, `ingresses`, `horizontalpodautoscalers`, `persistentvolumeclaims`; `pods/log`, `pods/exec`, `pods/portforward`. Секреты **только на запись** (`create/update/patch/delete`), то есть можно ротировать, но нельзя прочитать. Нельзя менять RBAC, quotas и NetworkPolicy своего namespace | `propdev:sales-devops` → `sales`; `propdev:housing-devops` → `housing`; `propdev:finance-devops` → `finance`; `propdev:data-devops` → `data` (DevOps-инженеры функциональных команд) |
| `propdev-namespace-viewer` (ClusterRole, выдаётся через **RoleBinding в namespace своего домена**) | В пределах своего namespace: `get/list/watch` на workload-ресурсы, `pods/log`, events, configmaps. Без секретов и без exec | `propdev:sales-developers` → `sales`; `propdev:housing-developers` → `housing`; `propdev:finance-developers` → `finance`; `propdev:data-developers` → `data` (разработчики функциональных команд) |

## Тестовые пользователи (скрипт `01-create-users.sh`)

| Пользователь (CN) | Группы (O) | Ожидаемые права |
| --- | --- | --- |
| `alexey` | `propdev:cluster-admins` | Всё |
| `irina` | `propdev:security-officers`, `propdev:cluster-viewers` | Просмотр всего, включая секреты. Изменять ничего нельзя |
| `pavel` | `propdev:platform-engineers` | Настройка кластера (namespaces, quotas, NetworkPolicy). Секретов не видит |
| `maria` | `propdev:cluster-viewers` | Только просмотр, без секретов |
| `olga` | `propdev:sales-devops` | Деплой в `sales`. В `housing` и других namespace доступа нет. Секреты может записывать, но не читать |
| `dmitry` | `propdev:housing-developers` | Только просмотр в `housing` |

## Файлы

| Файл | Назначение |
| --- | --- |
| `01-create-users.sh` | Создаёт ключи и CSR (`openssl`), подписывает сертификаты через Kubernetes CSR API (если CSR API не выдаёт сертификат — через CA minikube), добавляет пользователей и контексты `<user>@<cluster>` в kubeconfig |
| `02-create-roles.sh` | Создаёт namespaces доменов и 6 ClusterRole из таблицы |
| `03-bind-roles.sh` | Создаёт ClusterRoleBinding и RoleBinding групп с ролями |
| `verify-rbac.sh` | Дополнительно: автоматическая проверка матрицы прав от имени каждого пользователя |

# Terragrunt: module → unit → stack на одном примере

Учебная копия схемы из `terragrunt-infrastructure-catalog` + `terragrunt-infrastructure`.
Папку `terraform/` рядом это не трогает: здесь отдельные ресурсы со своим state.

Пример: «отчётный пайплайн» = сервисный аккаунт `reporting-bot` + топик Pub/Sub `reports`
с двумя подписками, на которые этому аккаунту выдана роль `pubsub.subscriber`.

```
terragrunt/
├── catalog/                                   ← аналог terragrunt-infrastructure-catalog
│   ├── modules/gcp/                           УРОВЕНЬ 1: чистый Terraform, «как создать»
│   │   ├── service-account/  main.tf variables.tf outputs.tf
│   │   └── pubsub/           main.tf variables.tf outputs.tf
│   ├── units/gcp/                             УРОВЕНЬ 2: модуль + откуда брать значения
│   │   ├── service-account/terragrunt.hcl
│   │   └── pubsub/terragrunt.hcl              (зависит от service-account)
│   └── stacks/gcp/
│       └── reporting/terragrunt.stack.hcl     УРОВЕНЬ 3: какие юниты идут вместе
│
└── live/                                      ← аналог terragrunt-infrastructure
    ├── root.hcl                               общий provider + backend для всех юнитов
    └── floci-local/                           окружение
        ├── project.hcl                        ВСЕ значения окружения
        └── gcp/terragrunt.stack.hcl           какие стеки развернуть здесь
```

## Как значения доходят до ресурса

```
live/floci-local/gcp/terragrunt.stack.hcl
  stack "reporting"  ──▶ catalog/stacks/gcp/reporting
                           ├─ unit "service-account" ──▶ catalog/units/gcp/service-account
                           │     читает project.hcl → locals.service_account
                           │     запускает        → catalog/modules/gcp/service-account
                           │     outputs: member = "serviceAccount:reporting-bot@..."
                           │                │
                           └─ unit "pubsub" ◀┘ dependency "service_account"
                                 читает project.hcl → locals.pubsub
                                 запускает        → catalog/modules/gcp/pubsub
```

`find_in_parent_folders("project.hcl")` внутри юнита ищет файл **вверх от места запуска**.
Юниты генерируются внутрь `live/floci-local/gcp/.terragrunt-stack/...`, поэтому находят
`live/floci-local/project.hcl`. Сделай `live/floci-stage/` со своим `project.hcl`, и тот же
каталог создаст другие ресурсы.

## Запуск

Нужны terraform ≥ 1.6 и terragrunt ≥ 1.0 (например `brew install terragrunt`).

```bash
cd terragrunt/live/floci-local/gcp

terragrunt stack generate               # разложить стеки/юниты в .terragrunt-stack/
find .terragrunt-stack -name '*.hcl'    # посмотреть, что получилось
terragrunt dag graph                    # порядок: service-account → pubsub
terragrunt stack run plan
terragrunt stack run apply
terragrunt stack run destroy            # убрать
```

Проверка в floci-ui (Pub/Sub) или `gcloud iam service-accounts list`.

## Что попробовать

1. **Поменять значение**: добавь в `project.hcl` подписку `reports-alerts = {}` → `plan`.
   Каталог не трогаешь.
2. **Поменять логику**: в `modules/gcp/pubsub` добавь `message_retention_duration` в
   подписку, прокинь переменную через `units/gcp/pubsub` → `plan`.
3. **Новый юнит в стек**: сделай `modules/gcp/secret` + `units/gcp/secret` (секрет с
   доступом для того же сервисного аккаунта через `dependency`) и добавь
   `unit "secret"` в `stacks/gcp/reporting`.

## Отличия от рабочих репозиториев

| Здесь | В terragrunt-infrastructure |
|---|---|
| `source = "${local.catalog}/..."` (локальный путь) | `git::git@github.com:B2Spin/terragrunt-infrastructure-catalog.git//...?ref=master` |
| state в `live/.state/` | GCS-бакет `terragrunt-<project_id>` |
| провайдер смотрит в floci | настоящий GCP + Vault |

Локальный путь здесь работает так же, как `mise run switch_to_local` в рабочих репах.

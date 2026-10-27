# orders-lab: GCP-проект на floci-gcp

Небольшой, но «настоящий» проект: инфра на Terraform, приложение на Python, gcloud для
ручных операций. Всё как в обычном GCP-проекте, только API отвечает floci-gcp.

## Что строим

Пайплайн обработки заказов от партнёров:

```
партнёр ── CSV ──▶ GCS  floci-local-uploads/incoming/
                      │  (bucket notification, OBJECT_FINALIZE)
                      ▼
                  Pub/Sub  uploads ──▶ worker
                                         ├─ Secret Manager   partner-api-key  → HMAC-подпись заказа
                                         ├─ Cloud KMS        orders/customer-pii → шифрует e-mail
                                         ├─ Firestore        orders/{id}      → операционные данные
                                         ├─ BigQuery         orders.orders    → аналитика без PII
                                         ├─ Cloud Tasks      receipts         → «отправить чек» по оплаченным
                                         ├─ Cloud Logging    orders-worker    → журнал обработки
                                         └─ GCS              floci-local-processed/done/ ← перенос файла

Cloud Scheduler (каждую минуту) ──▶ Pub/Sub report-requests ──▶ worker ──▶ отчёт в Cloud Logging
```

Кроме того Terraform для галочки создаёт **Cloud Run** (nginx, раздаёт страницу из GCS),
**Cloud SQL** (Postgres) и **IAM** service account, а в заданиях есть **GKE** через gcloud.

| Сервис | Кто создаёт | Кто использует |
|---|---|---|
| Cloud Storage | Terraform | `upload`, `worker`, Cloud Run |
| Pub/Sub | Terraform | `worker`, GCS-нотификация, Scheduler |
| Secret Manager | Terraform | `worker`, `reveal` |
| Cloud KMS | Terraform | `worker`, `reveal` |
| BigQuery | Terraform | `worker`, `report` |
| IAM | Terraform | привязки к топикам и секретам |
| Firestore | — (default DB) | `worker`, `report`, `reveal` |
| Cloud Tasks | `lab.py bootstrap` | `worker`, `report` |
| Cloud Scheduler | `lab.py bootstrap` | сам стреляет в Pub/Sub |
| Cloud Logging | — | `worker`, `report` |
| Cloud Run, Cloud SQL | Terraform (`with_compute`) | только посмотреть |
| GKE | gcloud (задание 6) | только посмотреть |

## Что нужно

- floci-gcp доступен по HTTP (по умолчанию `http://localhost:4588`)
- Python 3.11+, Terraform ≥ 1.6, Terragrunt ≥ 1.0
- gcloud CLI для заданий (не обязателен)

## Запуск

Адрес floci, проект и регион для инфраструктуры задаются в `gcp-infra/root.hcl`.
Если floci не на localhost, поправь `endpoint` там. Приложение читает `FLOCI_ENDPOINT`,
а без неё ходит на `http://localhost:4588`.

```bash
# 1. Инфраструктура (state хранится в бакете floci-local-tfstate на floci)
cd gcp-infra/infra/dev/orders-lab
terragrunt apply                 # with_compute = false в terragrunt.hcl, если Cloud Run / SQL не нужны
cd ../../../..

# 2. Приложение
python -m venv .venv && source .venv/bin/activate
pip install -r app/requirements.txt
cd app
python lab.py bootstrap          # нотификация GCS → Pub/Sub, очередь Tasks, cron в Scheduler
python lab.py demo               # upload → worker --once → report
```

После `demo` открой floci-ui (`localhost:4500`): в Storage, Pub/Sub, Secret Manager,
Cloud Scheduler, Cloud Run и Database появятся ресурсы. Firestore, KMS, BigQuery, Tasks и
Logging в UI пока нет, их видно через `python lab.py report` и gcloud.

Воркер в режиме «сервиса», пока ты поштучно загружаешь файлы:

```bash
python lab.py worker             # терминал 1
python lab.py upload -n 50       # терминал 2, сколько угодно раз
```

Раз в минуту в логе воркера будет строка `scheduled report: N paid orders`: это Cloud Scheduler
через Pub/Sub.

Можно запустить воркер и в k3d, как сервис в GKE (см. `k8s/worker.yaml`):

```bash
docker build -t orders-lab:dev app
k3d image import orders-lab:dev -c <cluster>
kubectl apply -f k8s/worker.yaml   # сначала поправь FLOCI_ENDPOINT в манифесте
```

## Задания («как будто ты в GCP»)

gcloud по умолчанию ходит в настоящий GCP. Один раз создай для него отдельную конфигурацию
с адресами floci:

```bash
printf 'floci-fake-token' > ~/.config/gcloud/floci-token
gcloud config configurations create floci          # создаёт и сразу активирует
gcloud config set core/project floci-local
gcloud config set core/disable_prompts true
gcloud config set auth/access_token_file ~/.config/gcloud/floci-token
gcloud config set api_endpoint_overrides/storage        http://localhost:4588/storage/v1/
gcloud config set api_endpoint_overrides/secretmanager  http://localhost:4588/
gcloud config set api_endpoint_overrides/cloudkms       http://localhost:4588/
gcloud config set api_endpoint_overrides/iam            http://localhost:4588/
gcloud config set api_endpoint_overrides/cloudscheduler http://localhost:4588/
gcloud config set api_endpoint_overrides/container      http://localhost:4588/container/
gcloud config set api_endpoint_overrides/serviceusage   http://localhost:4588/
```

Переключение: `gcloud config configurations activate floci` перед заданиями и
`gcloud config configurations activate default`, чтобы вернуться в настоящий GCP.
Всё ниже выполняется с активной конфигурацией `floci`.

**1. Посмотреть, что лежит в бакетах**
```bash
gcloud storage ls gs://floci-local-uploads/
gcloud storage ls gs://floci-local-processed/done/
gcloud storage cat gs://floci-local-processed/done/<файл>.csv | head
```

**2. Загрузить файл руками, как партнёр**
```bash
printf 'order_id,email,country,status,amount\nmanual0001,me@example.com,ES,paid,42.00\n' > /tmp/o.csv
gcloud storage cp /tmp/o.csv gs://floci-local-uploads/incoming/manual.csv
# воркер подхватит его сам; затем:
python app/lab.py reveal manual0001
```

**3. Ротация секрета**
```bash
gcloud secrets versions list partner-api-key
printf 'pk_live_v2_rotated' | gcloud secrets versions add partner-api-key --data-file=-
gcloud secrets versions access latest --secret=partner-api-key
python app/lab.py reveal manual0001    # «подпись НЕ совпадает»: заказ подписан старым ключом
```
В floci `versions add` может завершиться с ошибкой CRC32C, хотя версия создаётся. Это известное
ограничение, описано в compat-тестах.

**4. KMS**
```bash
gcloud kms keyrings list --location=us-central1
gcloud kms keys list --keyring=orders --location=us-central1
gcloud kms keys describe customer-pii --keyring=orders --location=us-central1
```
`gcloud kms encrypt/decrypt` против floci не работают (проверка CRC32C). Шифрование
проверяется через `lab.py reveal`.

**5. Управление cron-задачей**
```bash
gcloud scheduler jobs list --location=us-central1
gcloud scheduler jobs pause  minutely-report --location=us-central1   # отчёты в логе прекратятся
gcloud scheduler jobs resume minutely-report --location=us-central1
gcloud scheduler jobs run    minutely-report --location=us-central1   # выстрелить сейчас
```

**6. GKE-кластер (control plane или настоящий k3s, если floci без mock)**
```bash
gcloud container clusters create orders-gke --region=us-central1 --async
gcloud container clusters list --region=us-central1
gcloud container clusters delete orders-gke --region=us-central1 --async --quiet
```

**7. IAM и Service Usage**
```bash
gcloud iam service-accounts list
gcloud iam service-accounts create reporting-bot --display-name="Reporting bot"
gcloud services list --enabled
```

**8. BigQuery на полном SQL**
`lab.py report` сначала делает `COUNT(*) … WHERE status = 'paid'`: этот запрос работает и в
mock-режиме. Затем он пробует `GROUP BY country`, а это требует DuckDB-сайдкар
(`FLOCI_GCP_SERVICES_BIGQUERY_MOCK=false` и Docker socket). В mock-режиме увидишь понятную
ошибку `invalidQuery`.

**9. Terraform-цикл, как в жизни**
Добавь в `gcp-infra/infra-modules/main.tf` новый топик `orders-dlq` и подпиши `uploads-worker` на него как
dead-letter, затем `terragrunt plan` / `apply` из `gcp-infra/infra/dev/orders-lab`. Потом
`terragrunt destroy` и заново `apply`:
убедись, что `bootstrap` идемпотентен.

## Особенности floci, которые встретились по пути

- **GCS → Pub/Sub нотификации.** Штатные клиенты (Python SDK, `google_storage_notification`)
  передают топик как `//pubsub.googleapis.com/projects/…`. floci сохраняет эту строку как есть
  и при публикации не находит топик, так что события молча пропадают (видно только warning в
  логах floci). Поэтому `bootstrap` создаёт нотификацию прямым REST-запросом с
  `projects/…/topics/…`. Похоже на баг, о нём можно завести issue в floci-io/floci-gcp.
- **Cloud Tasks** хранит задачи, но не доставляет их по HTTP. Поэтому URL
  `receipts.invalid` никуда не ведёт, и это нормально.
- **Pub/Sub через gcloud** не работает (у floci Pub/Sub для gcloud недоступен). Через SDK и
  Terraform работает.
- Сервисы без `*_EMULATOR_HOST` (KMS, Logging, Tasks, Scheduler, Secret Manager в Python)
  подключаются через явный plaintext gRPC-канал. Как это сделано, смотри в
  `app/labgcp/clients.py`.

# floci-lab

A local playground for AWS and GCP infrastructure. Nothing touches a real cloud: every API call
goes to the floci emulators running in Docker.

| Folder | What it is | Talks to |
|---|---|---|
| `app/` | Emulators (docker compose) and the orders worker image | — |
| `gcp-infra/` | GCP infra for the orders pipeline, Terragrunt per environment | floci-gcp `:4588` |
| `aws-infra/` | AWS VPC + EKS + cluster add-ons, Terragrunt per environment | floci-aws `:4566` |
| `terragrunt/` | Terragrunt stacks example: catalog of modules, units and stacks | floci-gcp `:4588` |

## Start the emulators

```bash
cd app
docker compose up -d
```

| Service | Port | Purpose |
|---|---|---|
| floci-aws | 4566 | AWS API emulator |
| floci-gcp | 4588 | GCP API emulator |
| floci-ui | 4500 | Web UI for both emulators |

## app

```
docker-compose.yaml ── floci-aws, floci-gcp, floci-ui
Dockerfile ─────────── worker image: python lab.py worker
```

The Dockerfile expects `lab.py`, `labgcp/` and `requirements.txt` next to it.

## gcp-infra

GCP resources for the orders pipeline: GCS buckets, Pub/Sub, Secret Manager, KMS, BigQuery,
a service account and, optionally, Cloud Run and Cloud SQL.

```
gcp-infra/
├── root.hcl ─────────────── floci endpoint, project, region
│     ├─ generates provider.tf   google provider pointed at floci
│     ├─ generates backend.tf    gcs backend: floci-local-tfstate/<env>/default.tfstate
│     ├─ before_hook             creates the state bucket on init
│     └─ reads infra/<env>/env.hcl → passes env to the module
├── infra/
│   └── dev/
│       ├── env.hcl ──────── env = "dev"
│       └── terragrunt.hcl ─ include root.hcl, source = infra-modules, with_compute
└── infra-modules/ ──────── one module, every name is prefixed with env
      main.tf      buckets, Pub/Sub, secret, KMS, BigQuery, service account
      compute.tf   Cloud Run + Cloud SQL (with_compute)
```

```bash
cd gcp-infra/infra/dev
terragrunt plan
terragrunt apply
```

New environment: copy `infra/dev` to `infra/stage` and set `env = "stage"` in `env.hcl`.
Resource names and the state folder change automatically.

## aws-infra

An AWS network with an EKS cluster and the cluster autoscaler.

```
aws-infra/
├── root.hcl ─────────────── provider.tf (aws → floci :4566), local state in state/
├── infra/
│   ├── dev/
│   │   ├── env.hcl ──────── env = "dev"
│   │   ├── vpc ─────────────────▶ infra-modules/vpc
│   │   ├── eks ─────────────────▶ infra-modules/eks                 depends on vpc
│   │   └── kubernetes-addons ───▶ infra-modules/kubernetes-addons   depends on eks
│   └── stage/
│       └── vpc ─────────────────▶ infra-modules/vpc
└── infra-modules/
      vpc                 VPC, subnets, IGW, NAT, route tables
      eks                 cluster, node group, IAM, IRSA
      kubernetes-addons   cluster-autoscaler (helm)
```

```bash
cd aws-infra/infra/dev
terragrunt run --all plan     # vpc → eks → kubernetes-addons
terragrunt run --all apply
```

## terragrunt

A Terragrunt stacks example with four levels: module → unit → stack → environment.
All environment values live in one file, `live/<env>/project.hcl`.

```
terragrunt/
├── live/
│   ├── root.hcl ─────────── provider.tf + local state in live/.state/, reads project.hcl
│   └── floci-local/
│       ├── project.hcl ──── project, region, endpoint, labels, unit values
│       └── gcp/terragrunt.stack.hcl ─▶ stack "reporting"
└── catalog/
    ├── stacks/gcp/reporting ─▶ units service-account + pubsub
    ├── units/gcp/
    │   ├── service-account ─▶ modules/gcp/service-account
    │   └── pubsub ──────────▶ modules/gcp/pubsub        depends on service-account
    └── modules/gcp/
          service-account   google_service_account
          pubsub            topic, subscriptions, subscriber IAM
```

```bash
cd terragrunt/live/floci-local/gcp
terragrunt stack generate
terragrunt stack run plan
terragrunt stack run apply
```

## Requirements

- Docker
- Terraform ≥ 1.6
- Terragrunt ≥ 1.0

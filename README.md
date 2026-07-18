# Terraform EKS Platform

A modular, production-style Terraform project that provisions Amazon EKS
clusters across dev, staging, and prod — with reusable modules, environment
isolation via Terraform workspaces, and a full Jenkins CI/CD pipeline that
gates every change behind format checks, validation, and a manual approval
step before it ever touches AWS.

```
terraform init
terraform workspace select dev
terraform apply -var-file=environments/dev/terraform.tfvars
```

That's it — VPC, IAM roles, EKS control plane, addons, and managed node
groups, all stood up from one command (or one Jenkins build).

## Why this exists

Most "getting started" EKS tutorials give you a single `main.tf` with
everything hardcoded. That doesn't survive contact with a real team: no
environment separation, no code reuse, no review process before changes hit
production. This project is built the way a platform team would actually
structure it — modular, environment-aware, and gated by CI/CD from day one.

## Architecture

```
                    ┌─────────────────────────┐
                    │      Jenkins CI/CD       │
                    │  plan → approve → apply  │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────────────────────┐
                    │               Amazon VPC                 │
                    │  ┌──────────────┐   ┌───────────────────┐│
                    │  │Public subnet │   │  Private subnet    ││
                    │  │              │   │                    ││
                    │  │ NAT gateway  │   │ EKS control plane  ││
                    │  │              │   │        │           ││
                    │  │              │   │  ┌─────┴──────┐    ││
                    │  │              │   │  │ Node groups │   ││
                    │  │              │   │  └────────────┘    ││
                    │  └──────────────┘   └───────────────────┘│
                    └───────────────────────────────────────────┘
```

## Features

- **Modular by design** — separate, reusable modules for `vpc`, `iam`, `eks`,
  and `node-group`. Each is independently testable and composable.
- **Multi-environment via Terraform workspaces** — dev, staging, and prod
  share one codebase but are fully isolated in state and configuration.
  Each environment has its own `terraform.tfvars`: dev runs cheap
  (single NAT gateway, spot-friendly sizing), prod runs hardened
  (private-only API endpoint, multiple node pools, one NAT gateway per AZ).
- **Remote state** — S3 + DynamoDB backend for safe collaboration and state
  locking.
- **Map-driven node groups** — define any number of node pools (on-demand vs
  spot, tainted vs general-purpose) entirely from `tfvars`, no code changes.
- **IRSA-ready** — OIDC provider wired up correctly so pods can assume IAM
  roles directly.
- **Jenkins pipeline** — parameterized (`ENVIRONMENT`, `ACTION`,
  `AUTO_APPROVE`) with format check → init → validate → optional tfsec
  security scan → plan → manual approval → apply/destroy → kubeconfig
  update + live smoke test.
- **Optional tfsec security scanning** — static analysis for
  misconfigurations (public endpoints, unencrypted resources, overly broad
  IAM), toggleable per build.

## Project structure

```
.
├── main.tf                    # Root module — wires vpc/iam/eks/node-group together
├── variables.tf                # Root input variables
├── outputs.tf                  # cluster name, endpoint, kubeconfig command, etc.
├── providers.tf                # aws / kubernetes / helm providers
├── backend.tf                  # S3 + DynamoDB remote state backend
├── versions.tf                 # Terraform & provider version constraints
├── Jenkinsfile                 # CI/CD pipeline definition
├── environments/
│   ├── dev/terraform.tfvars
│   ├── staging/terraform.tfvars
│   └── prod/terraform.tfvars
└── modules/
    ├── vpc/                    # VPC, subnets, IGW, NAT gateways, route tables
    ├── iam/                    # EKS cluster role + node role
    ├── eks/                    # EKS cluster + core addons (vpc-cni, coredns, kube-proxy)
    └── node-group/              # Managed node groups (map-based, multi-pool support)
```

## Getting started

**Prerequisites:** Terraform ≥ 1.6, AWS CLI configured with EKS/EC2/IAM/VPC
permissions, an S3 bucket + DynamoDB table for remote state.

```bash
# One-time: create the state backend
aws s3api create-bucket --bucket <your-unique-bucket-name> --region us-east-1
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# Update backend.tf with your bucket name, then:
terraform init
terraform workspace new dev
terraform plan  -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars

# Connect kubectl
terraform output configure_kubectl   # prints the aws eks update-kubeconfig command
kubectl get nodes
```

Switching environments is just a workspace change:

```bash
terraform workspace select staging
terraform plan -var-file=environments/staging/terraform.tfvars
```

## CI/CD with Jenkins

The `Jenkinsfile` implements a parameterized pipeline:

| Parameter | Options | Purpose |
|---|---|---|
| `ENVIRONMENT` | `dev` / `staging` / `prod` | Selects the Terraform workspace + tfvars |
| `ACTION` | `plan` / `apply` / `destroy` | What to run |
| `AUTO_APPROVE` | on/off | Skip the manual approval gate (not recommended for prod) |
| `RUN_SECURITY_SCAN` | on/off | Run the tfsec static analysis stage |

**Pipeline stages:** checkout → `fmt -check` → `init` → `validate` →
(optional) tfsec scan → workspace select/create → `plan` → manual approval →
`apply`/`destroy` → kubeconfig update + `kubectl get nodes` smoke test.

Every plan output is archived as a build artifact, so every change to
infrastructure has a reviewable paper trail before it's applied.

## Notes from building this

A few real issues surfaced while standing this up, worth knowing if you're
adapting this for your own AWS account:

- **CoreDNS is a Deployment, not a DaemonSet** — it needs a schedulable node
  to place pods on. Creating it alongside the cluster (before any nodes
  exist) leaves it stuck `DEGRADED`. This project creates it explicitly
  *after* the node group, with an explicit `depends_on`.
- **New/restricted AWS accounts** may be limited to Free Tier–eligible
  instance types (`t3.micro`) until billing history builds up — attempting
  `t3.medium` or Spot instances can fail with
  `InvalidParameterCombination`.
- **ARM vs x86** matters if you're running Jenkins in Docker on Apple
  Silicon — make sure to build/run with `--platform linux/arm64` and use
  architecture-appropriate binaries for Terraform/AWS CLI/kubectl.

## Production hardening ideas

- Migrate `backend.tf` from `dynamodb_table` locking to the newer
  `use_lockfile` (S3 native locking).
- Bootstrap the state bucket/table itself in a separate, one-time Terraform
  config (avoids the chicken-and-egg problem of needing state to create
  your state backend).
- Add Slack/Teams notifications to the Jenkins `post` block.
- Consider Karpenter or Cluster Autoscaler for dynamic node scaling.
- Enable KMS encryption on the EKS cluster and CloudWatch log group.

## License

MIT — use freely, adapt for your own infrastructure.
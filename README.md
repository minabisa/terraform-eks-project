# Terraform EKS Project

Production-style Terraform project that provisions an Amazon EKS cluster using
reusable modules, per-environment `tfvars`, Terraform **workspaces** for
dev/staging/prod isolation, and a **Jenkins** pipeline for CI/CD.

## Structure

```
.
├── main.tf                  # Root module: wires vpc/iam/eks/node-group together
├── variables.tf              # Root input variables (defaults; overridden by tfvars)
├── outputs.tf                # Root outputs (cluster name, endpoint, kubeconfig cmd, etc.)
├── providers.tf              # aws / kubernetes / helm providers
├── backend.tf                 # S3 + DynamoDB remote state backend
├── versions.tf                # Terraform & provider version constraints
├── Jenkinsfile                # CI/CD pipeline definition
├── environments/
│   ├── dev/terraform.tfvars
│   ├── staging/terraform.tfvars
│   └── prod/terraform.tfvars
└── modules/
    ├── vpc/                  # VPC, subnets, IGW, NAT gateways, route tables
    ├── iam/                  # EKS cluster role + node role
    ├── eks/                  # EKS cluster + core addons (vpc-cni, coredns, kube-proxy)
    └── node-group/            # Managed node groups (map-based, supports multiple groups)
```

## Prerequisites

1. Terraform >= 1.6
2. AWS CLI configured / IAM permissions for EKS, EC2, IAM, VPC
3. An S3 bucket + DynamoDB table for remote state locking (create once):

```bash
aws s3api create-bucket --bucket my-company-terraform-state-eks --region us-east-1
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

Update `backend.tf` with your actual bucket name.

## Usage (local / manual)

```bash
terraform init

# Create / select a workspace per environment
terraform workspace new dev      # first time only
terraform workspace select dev

terraform plan  -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars

# Switch environment
terraform workspace select staging
terraform plan -var-file=environments/staging/terraform.tfvars
```

After apply:

```bash
terraform output configure_kubectl
# then run the printed `aws eks update-kubeconfig ...` command
kubectl get nodes
```

## Workspaces & tfvars

- `terraform.workspace` is used inside `main.tf` (`local.env`) to namespace
  resource names/tags so dev, staging and prod never collide even though they
  share the same backend key prefix (`env:/<workspace>/...` under the hood).
- Each environment has its own `terraform.tfvars` file under `environments/`
  controlling CIDR ranges, node group sizing, capacity type, endpoint access, etc.

## CI/CD with Jenkins

The included `Jenkinsfile` implements a parameterized pipeline:

- **ENVIRONMENT**: `dev` / `staging` / `prod` — selects the Terraform workspace
  and matching tfvars file
- **ACTION**: `plan` / `apply` / `destroy`
- **AUTO_APPROVE**: skip the manual approval gate (not recommended for prod)

Pipeline stages: checkout → `fmt -check` → `init` → `validate` → workspace
select/create → `plan` → manual approval (for apply/destroy) → `apply` or
`destroy` → kubeconfig update + smoke test (`kubectl get nodes`).

### Jenkins setup

1. Install plugins: Pipeline, AWS Credentials, Terraform (optional).
2. Add credentials in Jenkins with ID `aws-terraform-eks-creds`
   (Access Key/Secret, or better: use an IAM instance profile / OIDC role
   instead of static keys).
3. Create a Pipeline job (or Multibranch Pipeline) pointing at this repo,
   using `Jenkinsfile` from SCM.
4. Run the job, choosing ENVIRONMENT and ACTION.

## Notes / production hardening ideas

- Add `tfsec` / `checkov` static analysis stage before apply.
- Store the S3 bucket/DynamoDB table itself in a separate bootstrap
  Terraform config (chicken-and-egg problem with backend).
- Consider `terraform-aws-modules/eks/aws` registry module for even more
  batteries-included features (Fargate profiles, aws-auth management, etc.) —
  this project intentionally builds from raw resources for transparency and
  full control.
- Add Slack/Teams notification steps in the Jenkins `post` block.
- Enable EKS cluster encryption (KMS) and private-only endpoints for prod
  (already set in `environments/prod/terraform.tfvars`).

# Remote state backend (S3 + DynamoDB lock table)
# Bucket/table must exist before `terraform init` (create once via bootstrap or console/CLI).
#
# Workspaces are used for dev/staging/prod isolation. State path automatically
# includes the workspace name because of "env:/" prefix injected by S3 backend
# when workspaces are used, so no need to hardcode env in the key.

terraform {
  backend "s3" {
    bucket         = "my-company-terraform-state-eks-1784242722" # CHANGE ME - must be globally unique
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

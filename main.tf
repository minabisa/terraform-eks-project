locals {
  # terraform.workspace gives us dev / staging / prod automatically
  env = terraform.workspace

  common_tags = merge(var.tags, {
    Environment = local.env
    Project     = var.project_name
  })

  full_cluster_name = "${var.project_name}-${var.cluster_name}-${local.env}"
}

module "vpc" {
  source = "./modules/vpc"

  project_name         = "${var.project_name}-${local.env}"
  cluster_name         = local.full_cluster_name
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  tags                 = local.common_tags
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  cluster_name = local.full_cluster_name
  tags         = local.common_tags
}

module "eks" {
  source = "./modules/eks"

  cluster_name                    = local.full_cluster_name
  cluster_version                 = var.cluster_version
  cluster_role_arn                = module.iam.cluster_role_arn
  public_subnet_ids               = module.vpc.public_subnet_ids
  private_subnet_ids              = module.vpc.private_subnet_ids
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  cluster_log_types               = var.cluster_log_types
  tags                            = local.common_tags
}

# OIDC provider created after the cluster exists (needs its issuer URL for IRSA)
data "tls_certificate" "eks" {
  url = module.eks.cluster_oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = module.eks.cluster_oidc_issuer_url

  tags = local.common_tags
}

module "node_group" {
  source = "./modules/node-group"

  cluster_name  = module.eks.cluster_name
  node_role_arn = module.iam.node_role_arn
  subnet_ids    = module.vpc.private_subnet_ids
  node_groups   = var.node_groups
  tags          = local.common_tags

  depends_on = [module.eks]
}

# CoreDNS is a Deployment (not a DaemonSet) - it needs at least one schedulable
# node to place its pods on, so it must be created AFTER the node group exists.
# Creating it alongside the cluster (before nodes) leaves it stuck DEGRADED.
resource "aws_eks_addon" "coredns" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.common_tags

  depends_on = [module.node_group]
}

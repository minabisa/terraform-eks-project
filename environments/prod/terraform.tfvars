project_name = "myapp"
aws_region   = "us-east-1"

vpc_cidr             = "10.2.0.0/16"
azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.2.0.0/24", "10.2.1.0/24", "10.2.2.0/24"]
private_subnet_cidrs = ["10.2.10.0/24", "10.2.11.0/24", "10.2.12.0/24"]
enable_nat_gateway   = true
single_nat_gateway   = false # one NAT per AZ for HA

cluster_name    = "eks"
cluster_version = "1.30"

cluster_endpoint_public_access  = false # private only for prod
cluster_endpoint_private_access = true

node_groups = {
  general = {
    instance_types = ["m5.large"]
    capacity_type  = "ON_DEMAND"
    desired_size   = 3
    min_size       = 3
    max_size       = 6
    disk_size      = 50
    labels         = { environment = "prod", workload = "general" }
    taints         = []
  }
  compute = {
    instance_types = ["c5.xlarge"]
    capacity_type  = "ON_DEMAND"
    desired_size   = 2
    min_size       = 1
    max_size       = 5
    disk_size      = 50
    labels         = { environment = "prod", workload = "compute" }
    taints = [
      {
        key    = "workload"
        value  = "compute"
        effect = "NO_SCHEDULE"
      }
    ]
  }
}

tags = {
  Owner      = "platform-team"
  CostCenter = "prod-infra"
}

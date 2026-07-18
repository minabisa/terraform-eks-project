project_name = "myapp"
aws_region   = "us-east-1"

vpc_cidr             = "10.1.0.0/16"
azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24", "10.1.12.0/24"]
enable_nat_gateway   = true
single_nat_gateway   = false

cluster_name    = "eks"
cluster_version = "1.30"

cluster_endpoint_public_access  = true
cluster_endpoint_private_access = true

node_groups = {
  default = {
    instance_types = ["t3.large"]
    capacity_type  = "ON_DEMAND"
    desired_size   = 2
    min_size       = 2
    max_size       = 4
    disk_size      = 30
    labels         = { environment = "staging" }
    taints         = []
  }
}

tags = {
  Owner = "platform-team"
}

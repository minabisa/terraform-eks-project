project_name = "myapp"
aws_region   = "us-east-1"

vpc_cidr             = "10.0.0.0/16"
azs                  = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
enable_nat_gateway   = true
single_nat_gateway   = true # cheaper for dev

cluster_name    = "eks"
cluster_version = "1.35"

cluster_endpoint_public_access  = true
cluster_endpoint_private_access = true

node_groups = {
  default = {
    instance_types = ["t3.micro"]
    capacity_type  = "SPOT"
    desired_size   = 2
    min_size       = 1
    max_size       = 3
    disk_size      = 20
    labels         = { environment = "dev" }
    taints         = []
  }
}

tags = {
  Owner = "platform-team"
}

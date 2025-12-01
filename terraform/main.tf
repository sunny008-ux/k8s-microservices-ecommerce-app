# =============================================================================
# MAIN INFRASTRUCTURE RESOURCES
# =============================================================================

# =============================================================================
# VPC CONFIGURATION
# =============================================================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  # NAT Gateway configuration
  enable_nat_gateway = true
  single_nat_gateway = var.enable_single_nat_gateway

  # Internet Gateway
  create_igw = true

  # DNS configuration
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Manage default resources for better control
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${var.cluster_name}-default-nacl" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${var.cluster_name}-default-rt" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${var.cluster_name}-default-sg" }

  # Apply Kubernetes-specific tags to subnets
  public_subnet_tags  = merge(local.common_tags, local.public_subnet_tags)
  private_subnet_tags = merge(local.common_tags, local.private_subnet_tags)

  tags = local.common_tags
}

# =============================================================================
# EKS CLUSTER CONFIGURATION
# =============================================================================

module "retail_app_eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  # Basic cluster configuration
  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  # Cluster access configuration
  cluster_endpoint_public_access           = true
  cluster_endpoint_private_access          = true
  enable_cluster_creator_admin_permissions = true

  # EKS Auto Mode configuration - simplified node management
  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  # Network configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # KMS configuration to avoid conflicts
  create_kms_key                  = true
  kms_key_description             = "EKS cluster ${local.cluster_name} encryption key"
  kms_key_deletion_window_in_days = 7

  # Cluster logging (optional - can be expensive)
  cluster_enabled_log_types = []

  tags = local.common_tags
}

# =============================================================================
# CLEANUP LOAD BALANCERS BEFORE VPC DESTRUCTION
# =============================================================================

resource "null_resource" "cleanup_load_balancers" {
  triggers = {
    cluster_name = local.cluster_name
    region       = var.aws_region
    vpc_id       = module.vpc.vpc_id
  }

  # Clean up any remaining load balancers before destroying VPC
  provisioner "local-exec" {
    when        = destroy
    command     = <<-EOT
      echo "Cleaning up load balancers in VPC ${self.triggers.vpc_id}..."
      for lb in $(aws elbv2 describe-load-balancers --region ${self.triggers.region} --query "LoadBalancers[?VpcId=='${self.triggers.vpc_id}'].LoadBalancerArn" --output text 2>nul); do
        echo "Deleting load balancer: $lb"
        aws elbv2 delete-load-balancer --load-balancer-arn $lb --region ${self.triggers.region} 2>nul || echo "Failed to delete $lb"
      done
      for lb in $(aws elb describe-load-balancers --region ${self.triggers.region} --query "LoadBalancerDescriptions[?VPCId=='${self.triggers.vpc_id}'].LoadBalancerName" --output text 2>nul); do
        echo "Deleting classic load balancer: $lb"
        aws elb delete-load-balancer --load-balancer-name $lb --region ${self.triggers.region} 2>nul || echo "Failed to delete $lb"
      done
      echo "Waiting 30 seconds for load balancers to be deleted..."
      timeout /t 30 /nobreak >nul 2>&1 || ping 127.0.0.1 -n 31 >nul
    EOT
    interpreter = ["cmd", "/C"]
  }

  depends_on = [module.retail_app_eks]
}

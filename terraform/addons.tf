# =============================================================================
# EKS ADD-ONS AND EXTENSIONS
# =============================================================================
# DISABLED: This module has provider configuration issues
# Using direct Helm releases in addons-direct.tf instead

# module "eks_addons" {
#   source  = "aws-ia/eks-blueprints-addons/aws"
#   version = "~> 1.0"
#
#   # Cluster information
#   cluster_name      = module.retail_app_eks.cluster_name
#   cluster_endpoint  = module.retail_app_eks.cluster_endpoint
#   cluster_version   = module.retail_app_eks.cluster_version
#   oidc_provider_arn = module.retail_app_eks.oidc_provider_arn
#
#   enable_cert_manager = true
#   cert_manager = {
#     most_recent = true
#     namespace   = "cert-manager"
#   }
#
#   enable_ingress_nginx = true
#   ingress_nginx = {
#     most_recent = true
#     namespace   = "ingress-nginx"
#   }
#
#   enable_kube_prometheus_stack = var.enable_monitoring
#   kube_prometheus_stack = {
#     most_recent = true
#     namespace   = "monitoring"
#   }
#
#   enable_aws_load_balancer_controller = true
#   aws_load_balancer_controller = {
#     most_recent = true
#     namespace   = "kube-system"
#   }
#
#   depends_on = [module.retail_app_eks]
# }

# =============================================================================
# OUTPUT VALUES - STEP BY STEP FORMAT
# =============================================================================

# =============================================================================
# STEP 1: CLUSTER DETAILS
# =============================================================================

output "step_1_cluster_details" {
  description = "STEP 1: Complete EKS Cluster Information"
  value = {
    cluster_name              = module.retail_app_eks.cluster_name
    cluster_name_base         = var.cluster_name
    cluster_name_suffix       = random_string.suffix.result
    cluster_endpoint          = module.retail_app_eks.cluster_endpoint
    cluster_version           = module.retail_app_eks.cluster_version
    cluster_region            = var.aws_region
    cluster_security_group_id = module.retail_app_eks.cluster_security_group_id
    cluster_oidc_issuer_url   = module.retail_app_eks.cluster_oidc_issuer_url
    vpc_id                    = module.vpc.vpc_id
    vpc_cidr_block            = module.vpc.vpc_cidr_block
    private_subnets           = module.vpc.private_subnets
    public_subnets            = module.vpc.public_subnets
  }
}

output "step_1_configure_kubectl" {
  description = "STEP 1: Command to configure kubectl access to the cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.retail_app_eks.cluster_name}"
}

output "step_1_cluster_commands" {
  description = "STEP 1: Useful commands to verify cluster"
  value = {
    get_nodes        = "kubectl get nodes"
    get_pods_all     = "kubectl get pods -A"
    describe_cluster = "kubectl cluster-info"
  }
}

# =============================================================================
# STEP 2: ARGOCD DETAILS
# =============================================================================

output "step_2_argocd_details" {
  description = "STEP 2: ArgoCD Installation and Access Information"
  value = {
    namespace           = var.argocd_namespace
    username            = "admin"
    loadbalancer_name   = "${var.cluster_name}-argocd-server"
    get_url_command     = "kubectl get svc -n ${var.argocd_namespace} argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
    full_url_command    = "echo 'http://'$(kubectl get svc -n ${var.argocd_namespace} argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
    port_forward_option = "kubectl port-forward svc/argocd-server -n ${var.argocd_namespace} 8080:443"
  }
}

output "step_2_argocd_password_command" {
  description = "STEP 2: Command to retrieve ArgoCD admin password"
  value       = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  sensitive   = true
}

output "step_2_argocd_applications" {
  description = "STEP 2: Command to view ArgoCD applications"
  value       = "kubectl get applications -n ${var.argocd_namespace}"
}

# =============================================================================
# STEP 3: INGRESS CONTROLLER DETAILS
# =============================================================================

output "step_3_ingress_controller_details" {
  description = "STEP 3: Ingress NGINX Controller Information"
  value = {
    namespace                = "ingress-nginx"
    service_name             = "ingress-nginx-controller"
    get_loadbalancer_command = "kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
    check_status_command     = "kubectl get svc -n ingress-nginx"
    check_pods_command       = "kubectl get pods -n ingress-nginx"
  }
}

# =============================================================================
# STEP 4: APPLICATION UI DETAILS
# =============================================================================

output "step_4_retail_store_ui_details" {
  description = "STEP 4: Retail Store Application UI Access"
  value = {
    application_url_command = "echo 'http://'$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
    namespace               = "retail-store"
    check_pods_command      = "kubectl get pods -n retail-store"
    check_ingress_command   = "kubectl get ingress -A"
    services = {
      ui       = "retail-store-ui"
      cart     = "retail-store-cart"
      catalog  = "retail-store-catalog"
      checkout = "retail-store-checkout"
      orders   = "retail-store-orders"
    }
  }
}

# =============================================================================
# STEP 5: GRAFANA DETAILS
# =============================================================================

output "step_5_grafana_details" {
  description = "STEP 5: Grafana Monitoring Dashboard Information"
  value = var.enable_monitoring ? {
    namespace                = "monitoring"
    service_name             = "kube-prometheus-stack-grafana"
    username                 = "admin"
    password                 = "admin123 (CHANGE THIS IN PRODUCTION!)"
    get_loadbalancer_command = "kubectl get svc -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
    full_url_command         = "echo 'http://'$(kubectl get svc -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
    port_forward_option      = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
    access_url               = "http://localhost:3000 (when using port-forward)"
    } : {
    status = "Monitoring not enabled. Set enable_monitoring=true in variables"
  }
}

# =============================================================================
# STEP 6: PROMETHEUS DETAILS
# =============================================================================

output "step_6_prometheus_details" {
  description = "STEP 6: Prometheus Metrics and Monitoring Information"
  value = var.enable_monitoring ? {
    namespace                = "monitoring"
    service_name             = "kube-prometheus-stack-prometheus"
    port                     = "9090"
    get_loadbalancer_command = "kubectl get svc -n monitoring kube-prometheus-stack-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
    full_url_command         = "echo 'http://'$(kubectl get svc -n monitoring kube-prometheus-stack-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}':9090)"
    port_forward_option      = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
    access_url               = "http://localhost:9090 (when using port-forward)"
    check_targets_command    = "kubectl get servicemonitors -n monitoring"
    } : {
    status = "Monitoring not enabled. Set enable_monitoring=true in variables"
  }
}

# =============================================================================
# STEP 7: ALERTMANAGER DETAILS
# =============================================================================

output "step_7_alertmanager_details" {
  description = "STEP 7: Alertmanager Alert Management Information"
  value = var.enable_monitoring ? {
    namespace                = "monitoring"
    service_name             = "kube-prometheus-stack-alertmanager"
    port                     = "9093"
    get_loadbalancer_command = "kubectl get svc -n monitoring kube-prometheus-stack-alertmanager -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
    full_url_command         = "echo 'http://'$(kubectl get svc -n monitoring kube-prometheus-stack-alertmanager -o jsonpath='{.status.loadBalancer.ingress[0].hostname}':9093)"
    port_forward_option      = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093"
    access_url               = "http://localhost:9093 (when using port-forward)"
    check_alerts_command     = "kubectl get prometheusrules -n monitoring"
    } : {
    status = "Monitoring not enabled. Set enable_monitoring=true in variables"
  }
}

# =============================================================================
# MONITORING STATUS
# =============================================================================

output "monitoring_stack_status" {
  description = "Overall monitoring stack status and commands"
  value = var.enable_monitoring ? {
    enabled                  = true
    namespace                = "monitoring"
    get_all_pods_command     = "kubectl get pods -n monitoring"
    get_all_services_command = "kubectl get svc -n monitoring"
    components = {
      grafana      = "Visualization and Dashboards"
      prometheus   = "Metrics Collection and Storage"
      alertmanager = "Alert Management and Routing"
    }
    message = "Monitoring stack is enabled and running"
    } : {
    enabled                  = false
    namespace                = "not-applicable"
    get_all_pods_command     = "Monitoring not enabled"
    get_all_services_command = "Monitoring not enabled"
    components = {
      grafana      = "Not enabled"
      prometheus   = "Not enabled"
      alertmanager = "Not enabled"
    }
    message = "Monitoring stack is not enabled. Set enable_monitoring=true in terraform.tfvars"
  }
}

# =============================================================================
# AWS LOAD BALANCER INFORMATION
# =============================================================================

output "aws_load_balancers" {
  description = "AWS Load Balancer names for identification in AWS Console"
  value = {
    argocd       = "${var.cluster_name}-argocd-server"
    ingress      = "Managed by ingress-nginx (check EC2 > Load Balancers for auto-generated name)"
    prometheus   = var.enable_monitoring ? "${var.cluster_name}-prometheus" : "Not enabled"
    grafana      = var.enable_monitoring ? "${var.cluster_name}-grafana" : "Not enabled"
    alertmanager = var.enable_monitoring ? "${var.cluster_name}-alertmanager" : "Not enabled"
  }
}

# =============================================================================
# COMPLETE SUMMARY OUTPUT
# =============================================================================

output "complete_deployment_summary" {
  description = "Complete step-by-step summary of all deployed resources"
  value       = <<-EOT
    ================================================================================
    DEPLOYMENT COMPLETE - ACCESS INFORMATION
    ================================================================================
    
    STEP 1: CLUSTER DETAILS
    ------------------------
    Cluster Name: ${module.retail_app_eks.cluster_name}
    Region: ${var.aws_region}
    Version: ${module.retail_app_eks.cluster_version}
    Endpoint: ${module.retail_app_eks.cluster_endpoint}
    
    Configure kubectl:
    aws eks update-kubeconfig --region ${var.aws_region} --name ${module.retail_app_eks.cluster_name}
    
    STEP 2: ARGOCD DETAILS
    ----------------------
    Namespace: ${var.argocd_namespace}
    Username: admin
    
    Get ArgoCD URL:
    kubectl get svc -n ${var.argocd_namespace} argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
    
    Get ArgoCD Password:
    kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
    
    STEP 3: INGRESS CONTROLLER DETAILS
    -----------------------------------
    Namespace: ingress-nginx
    Service: ingress-nginx-controller
    
    Get LoadBalancer URL:
    kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
    
    STEP 4: APPLICATION UI DETAILS
    -------------------------------
    Retail Store UI URL:
    echo 'http://'$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    Check Application Status:
    kubectl get pods -n retail-store
    
    STEP 5: GRAFANA DETAILS
    ------------------------
    ${var.enable_monitoring ? "Namespace: monitoring\nUsername: admin\nPassword: admin123 (CHANGE IN PRODUCTION!)\n\nGet Grafana URL:\nkubectl get svc -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'\n\nPort Forward:\nkubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80\nAccess: http://localhost:3000" : "Monitoring not enabled. Set enable_monitoring=true"}
    
    STEP 6: PROMETHEUS DETAILS
    ---------------------------
    ${var.enable_monitoring ? "Namespace: monitoring\nPort: 9090\n\nGet Prometheus URL:\nkubectl get svc -n monitoring kube-prometheus-stack-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'\n\nPort Forward:\nkubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090\nAccess: http://localhost:9090" : "Monitoring not enabled. Set enable_monitoring=true"}
    
    STEP 7: ALERTMANAGER DETAILS
    -----------------------------
    ${var.enable_monitoring ? "Namespace: monitoring\nPort: 9093\n\nGet Alertmanager URL:\nkubectl get svc -n monitoring kube-prometheus-stack-alertmanager -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'\n\nPort Forward:\nkubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093\nAccess: http://localhost:9093" : "Monitoring not enabled. Set enable_monitoring=true"}
    
    ================================================================================
  EOT
}

# =============================================================================
# DESTROY HELPER
# =============================================================================

output "destroy_instructions" {
  description = "Instructions for clean destruction of all resources"
  value       = <<-EOT
    To destroy all resources cleanly, run these commands in order:
    
    1. First, configure kubectl:
       aws eks update-kubeconfig --region ${var.aws_region} --name ${module.retail_app_eks.cluster_name}
    
    2. Delete all ArgoCD applications (to prevent them from recreating resources):
       kubectl delete applications.argoproj.io --all -n ${var.argocd_namespace} --timeout=60s
    
    3. Delete all LoadBalancer services (to clean up AWS load balancers):
       kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer --timeout=60s
    
    4. Wait 30 seconds for AWS to clean up load balancers
    
    5. Run terraform destroy:
       terraform destroy -auto-approve
    
    OR simply run: terraform destroy -auto-approve
    (The cleanup scripts are now automated in the Terraform configuration)
  EOT
}

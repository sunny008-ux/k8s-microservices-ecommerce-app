# =============================================================================
# ARGOCD INSTALLATION AND CONFIGURATION
# =============================================================================

# Wait for the cluster and add-ons to be ready
resource "time_sleep" "wait_for_cluster" {
  create_duration = "30s"
  depends_on = [
    module.retail_app_eks,
    helm_release.cert_manager,
    helm_release.ingress_nginx
  ]
}

# =============================================================================
# CLEANUP RESOURCES ON DESTROY
# =============================================================================

resource "null_resource" "cleanup_k8s_resources" {
  count = var.skip_cleanup_on_destroy ? 0 : 1

  # This resource helps clean up Kubernetes resources before destroying the cluster

  triggers = {
    cluster_name = module.retail_app_eks.cluster_name
    region       = var.aws_region
  }

  # On destroy, clean up all LoadBalancer services and finalizers
  provisioner "local-exec" {
    when        = destroy
    command     = <<-EOT
      echo "Cleaning up Kubernetes resources..."
      aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} 2>nul || echo "Cluster may already be deleted"
      kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer --timeout=60s 2>nul || echo "Services already deleted or cluster unavailable"
      kubectl delete applications.argoproj.io --all -n argocd --timeout=30s 2>nul || echo "ArgoCD apps already deleted"
      kubectl delete appprojects.argoproj.io --all -n argocd --timeout=30s 2>nul || echo "ArgoCD projects already deleted"
      kubectl patch applications.argoproj.io --all -n argocd -p "{\"metadata\":{\"finalizers\":[]}}" --type=merge 2>nul || echo "No finalizers to remove"
      kubectl patch appprojects.argoproj.io --all -n argocd -p "{\"metadata\":{\"finalizers\":[]}}" --type=merge 2>nul || echo "No finalizers to remove"
      echo "Kubernetes cleanup completed"
    EOT
    interpreter = ["cmd", "/C"]
  }

  depends_on = [
    kubectl_manifest.argocd_apps,
    kubectl_manifest.argocd_projects,
    helm_release.argocd,
    helm_release.kube_prometheus_stack,
    helm_release.ingress_nginx
  ]
}

# =============================================================================
# ARGOCD HELM INSTALLATION
# =============================================================================

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.argocd_namespace
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  # Cleanup settings for reliable destroy
  cleanup_on_fail  = true
  wait             = true
  timeout          = 600
  wait_for_jobs    = false
  disable_webhooks = true

  # ArgoCD configuration values
  values = [
    yamlencode({
      # Server configuration
      server = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"   = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
            "service.beta.kubernetes.io/aws-load-balancer-name"   = "${var.cluster_name}-argocd-server"
          }
        }
        ingress = {
          enabled = false
        }
        # Enable insecure mode for easier access (HTTP instead of HTTPS)
        extraArgs = [
          "--insecure"
        ]
      }

      # Controller configuration
      controller = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }

      # Repo server configuration
      repoServer = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }

      # Redis configuration
      redis = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "128Mi"
          }
        }
      }
    })
  ]

  depends_on = [time_sleep.wait_for_cluster]
}

# =============================================================================
# ARGOCD CONFIGURATION
# =============================================================================

resource "kubectl_manifest" "argocd_projects" {
  for_each  = fileset("${path.module}/../argocd/projects", "*.yaml")
  yaml_body = file("${path.module}/../argocd/projects/${each.value}")

  # Force delete on destroy to avoid hanging
  force_conflicts   = true
  server_side_apply = true
  wait              = false

  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "argocd_apps" {
  for_each  = fileset("${path.module}/../argocd/applications", "*.yaml")
  yaml_body = file("${path.module}/../argocd/applications/${each.value}")

  # Force delete on destroy to avoid hanging
  force_conflicts   = true
  server_side_apply = true
  wait              = false

  depends_on = [kubectl_manifest.argocd_projects]
}

module "gitops_bridge_bootstrap" {
  source = "../modules/gitops-terraform-bridge"

  count = var.enable_gitops_bridge ? 1 : 0

  cluster = {
    cluster_name = local.kubernetes_name
    environment  = local.env
    metadata     = local.addons_metadata
    addons       = local.addons
  }

  argocd = {
    namespace     = "argocd"
    chart         = "argo-cd"
    chart_version = var.argocd_chart_version

    values = [local.argocd_helm_values]
  }

  apps = local.argocd_apps
}

locals {
  name   = "ex-${replace(basename(path.cwd), "_", "-")}"
  env    = var.environment
  region = var.region
  cloud  = var.cloud_provider
  domain = var.domain_name
  type   = var.cluster_type

  kubernetes_distro  = var.kubernetes_distro
  kubernetes_version = var.kubernetes_version
  kubernetes_name    = "${var.cluster_type}-${var.environment}"
  kubeconfig_path    = "${dirname(dirname(dirname(path.cwd)))}/kubeconfigs/hub-spoke/${local.kubernetes_name}"

  gitops_addons_url      = "${var.gitops_org}/${var.gitops_addons_repo}"
  gitops_addons_basepath = var.gitops_addons_basepath
  gitops_addons_path     = var.gitops_addons_path
  gitops_addons_revision = var.gitops_addons_revision

  gitops_addons_extras_url      = "${var.gitops_org}/${var.gitops_addons_extras_repo}"
  gitops_addons_extras_basepath = var.gitops_addons_extras_basepath
  gitops_addons_extras_revision = var.gitops_addons_extras_revision

  gitops_workloads_url      = "${var.gitops_org}/${var.gitops_workloads_repo}"
  gitops_workloads_basepath = var.gitops_workloads_basepath
  gitops_workloads_path     = var.gitops_workloads_path
  gitops_workloads_revision = var.gitops_workloads_revision

  # Cluster labels
  # Argocd secret labels for cluster selector
  argocd_cluster_labels = merge({
    cloud   = local.cloud
    region  = local.region
    env     = local.env
    type    = "workload"
    version = local.kubernetes_version
    distro  = local.kubernetes_distro
  })


  addons = try(var.addons, {})
  allowed_addons = formatlist("enable_%s", var.allowed_addons)
  unknown_addons = tolist(setsubtract(toset(keys(var.addons)), toset(local.allowed_addons)))

  # Secret Metadata Annotations
  addons_metadata = merge(
    {
      addons_repo_url      = local.gitops_addons_url
      addons_repo_basepath = local.gitops_addons_basepath
      addons_repo_path     = local.gitops_addons_path
      addons_repo_revision = local.gitops_addons_revision
    },
    {
      addons_extras_repo_url      = local.gitops_addons_extras_url
      addons_extras_repo_basepath = local.gitops_addons_extras_basepath
      addons_extras_repo_revision = local.gitops_addons_extras_revision
    },
    {
      workloads_repo_url      = local.gitops_workloads_url
      workloads_repo_basepath = local.gitops_workloads_basepath
      workloads_repo_path     = local.gitops_workloads_path
      workloads_repo_revision = local.gitops_workloads_revision
    },
  )

  argocd_helm_values = <<-EOT
    dex:
      enabled: false
    notifications:
      enabled: false
    global:
      addPrometheusAnnotations: true
    controller:
      logFormat: json
      metrics:
        enabled: true
    EOT

  tags = {
    Blueprint  = local.name
    GithubRepo = "https://github.com/SilexConsulting/gitops-control-plane.git"
  }
}

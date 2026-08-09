locals {
  name   = "on-prem-hub"
  env    = var.environment
  region = var.region
  cloud  = var.cloud_provider
  domain = var.domain_name
  type   = var.cluster_type

  kubernetes_distro  = var.kubernetes_distro
  kubernetes_version = var.kubernetes_version
  kubernetes_name    = var.kubeconfig_context

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

  # Private deployments repos (GIT-13) — SSH-accessed. URL is empty unless a repo is set
  # (opt-in), so a public-only trial cluster emits no private annotation and the root
  # bootstrap appset falls back to the public catalogue.
  gitops_addons_private_url         = var.gitops_addons_private_repo == "" ? "" : "${var.gitops_private_org}/${var.gitops_addons_private_repo}"
  gitops_addons_private_basepath    = var.gitops_addons_private_basepath
  gitops_addons_private_revision    = var.gitops_addons_private_revision
  gitops_workloads_private_url      = var.gitops_workloads_private_repo == "" ? "" : "${var.gitops_private_org}/${var.gitops_workloads_private_repo}"
  gitops_workloads_private_basepath = var.gitops_workloads_private_basepath
  gitops_workloads_private_revision = var.gitops_workloads_private_revision

  # Cluster labels
  argocd_cluster_labels = merge({
    cloud   = local.cloud
    region  = local.region
    env     = local.env
    type    = local.type
    is_hub  = "true"
    version = local.kubernetes_version
    distro  = local.kubernetes_distro
  })

  addons = merge(
    local.argocd_cluster_labels,
    var.addons
  )

  # enable_* key validation (GIT-20): recognise add-on, workload and resources master keys.
  allowed_addons      = formatlist("enable_%s", var.allowed_addons)
  allowed_workloads   = formatlist("enable_%s", var.allowed_workloads)
  allowed_enable_keys = distinct(concat(local.allowed_addons, local.allowed_workloads, ["enable_resources"]))
  unknown_addons      = tolist(setsubtract(toset(keys(var.addons)), toset(local.allowed_enable_keys)))

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
    {
      # Private overlay / deployments repos (GIT-13). Consumed by the private repo's
      # bootstrap Kustomize (deployments mode) to template per-cluster overlay sources.
      addons_private_repo_url         = local.gitops_addons_private_url
      addons_private_repo_basepath    = local.gitops_addons_private_basepath
      addons_private_repo_revision    = local.gitops_addons_private_revision
      workloads_private_repo_url      = local.gitops_workloads_private_url
      workloads_private_repo_basepath = local.gitops_workloads_private_basepath
      workloads_private_repo_revision = local.gitops_workloads_private_revision
    },
  )

  # Keys become Helm release names (must be RFC1123: lowercase, hyphens — no underscores).
  # Empty values are filtered out below so gated-off entries don't create empty releases.
  argocd_apps_all = {
    addons    = var.argocd_files_config.load_addons ? file("${path.module}/../../bootstrap/hub/addons.yaml") : ""
    workloads = var.argocd_files_config.load_workloads ? file("${path.module}/../../bootstrap/hub/workloads.yaml") : ""
    # GIT-20: resource roots. TRIAL-ONLY — they source the PUBLIC repos' top-level bootstrap/.
    # In deployments mode (a private repo is set) the private bootstrap imports & patches the
    # resources appset instead, so the root is omitted to avoid delivering the appset twice.
    "addons-resources-root"   = var.argocd_files_config.load_resources && local.gitops_addons_private_url == "" ? file("${path.module}/../../bootstrap/hub/addons-resources-root.yaml") : ""
    "workload-resources-root" = var.argocd_files_config.load_resources && local.gitops_workloads_private_url == "" ? file("${path.module}/../../bootstrap/hub/workload-resources-root.yaml") : ""
  }
  argocd_apps = { for k, v in local.argocd_apps_all : k => v if v != "" }

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
    server:
      service:
        type: LoadBalancer
    EOT
}

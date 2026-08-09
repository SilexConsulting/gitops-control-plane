variable "environment" {
  description = "Name of the environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "uat", "prod"], lower(var.environment))
    error_message = "Invalid environment. Must be one of 'dev', 'uat' or 'prod'."
  }
}

variable "region" {
  description = "region of the kubernetes cluster"
  type        = string
  default     = "north-america"

  validation {
    condition     = contains(["north-america", "europe", "asia-pacific"], lower(var.region))
    error_message = "Invalid environment. Must be one of 'north-america', 'europe' or 'asia-pacific'."
  }
}

variable "cluster_type" {
  description = "Type of the kubernetes cluster"
  type        = string
  default     = "hub"
  validation {
    condition     = contains(["hub"], lower(var.cluster_type))
    error_message = "Invalid cluster type. Must be one of 'hub'."
  }
}

variable "domain_name" {
  description = "Domain name"
  type        = string
  default     = "cluster.local"
}

variable "kubernetes_distro" {
  description = "Name of the kubernetes distro"
  type        = string
  default     = "kind"

  validation {
    condition     = contains(["kind", "k3d", "k0s"], lower(var.kubernetes_distro))
    error_message = "Invalid kubernetes distro. Must be one of 'kind', 'k3d' or 'k0s'."
  }
}

variable "kubernetes_version" {
  description = "Version of the Kind node image"
  type        = string
  default     = "1.33.1"
}

variable "cloud_provider" {
  type        = string
  description = "Cloud provider to deploy infrastructure to"
  default     = "local"

  validation {
    condition     = contains(["aws", "azure", "gcp", "local"], lower(var.cloud_provider))
    error_message = "Invalid cloud provider. Must be one of 'local', 'aws', 'azure' or 'gcp'."
  }
}

variable "enable_gitops_bridge" {
  description = "Enable gitops bridge"
  type        = bool
  default     = true
}

variable "argocd_files_config" {
  type = object({
    load_addons    = bool
    load_workloads = bool
    load_resources = optional(bool, true)
  })
  default = {
    load_addons    = true
    load_workloads = true
    load_resources = true
  }
}

variable "argocd_chart_version" {
  description = "Argocd helm chart version"
  type        = string
  default     = "8.5.4"
}

variable "addons" {
  description = "Addon selector labels. Keys must match ^enable_[a-z0-9_-]+$"
  type        = map(bool)
  default = {            # keep existing defaults
    enable_argocd = true # hub
  }
  validation {
    condition = alltrue([
      for k in keys(var.addons) : can(regex("^enable_[a-z0-9_-]+$", k))
    ])
    error_message = "All addon keys must start with 'enable_' and use [a-z0-9_-]."
  }
}

variable "allowed_addons" {
  description = "Optional allowlist of known addon flags. Extend here (tfvars) when new add-ons are added to the catalogue."
  type        = list(string)
  default     = ["argocd", "keycloak", "velero", "cnpg"]
}

variable "allowed_workloads" {
  description = "Optional allowlist of known workload flags (enable_<workload>). Extend here (tfvars) when new workloads are added to the catalogue. Used to validate enable_* keys alongside allowed_addons."
  type        = list(string)
  default     = ["home-assistant", "opensearch"]
}

variable "allow_unknown_addons" {
  description = "Validation mode for addon keys: strict (error on unknown) or lenient (warn via output)."
  type        = bool
  default     = true
}

# Addons Git
variable "gitops_org" {
  description = "Git repository org/user contains for addons"
  type        = string
  default     = "https://github.com/SilexConsulting"
}

# Private overlay Git org/prefix. Distinct from gitops_org because the private
# overlay repo is accessed over SSH (deploy key), e.g. "git@github.com:SilexConsulting".
variable "gitops_private_org" {
  description = "Git org/prefix (SSH) for the private overlay repo(s)"
  type        = string
  default     = "git@github.com:SilexConsulting"
}

variable "gitops_addons_repo" {
  description = "Git repository contains for addons"
  type        = string
  default     = "gitops-addons"
}

variable "gitops_addons_revision" {
  description = "Git repository revision/branch/ref for addons"
  type        = string
  default     = "main"
}

variable "gitops_addons_basepath" {
  description = "Git repository base path for addons"
  type        = string
  default     = "gitops"
}

variable "gitops_addons_path" {
  description = "Git repository path for addons"
  type        = string
  default     = "addons"
}

# Addons Extra Git
variable "gitops_addons_extras_repo" {
  description = "Git repository contains for addon resources"
  type        = string
  default     = "helm-charts"
}

variable "gitops_addons_extras_basepath" {
  description = "Git repository base path for addon resources"
  type        = string
  default     = "charts"
}

variable "gitops_addons_extras_revision" {
  description = "Git repository revision/branch/ref for addon resources"
  type        = string
  default     = "main"
}

# Workloads Git
variable "gitops_workloads_repo" {
  description = "Git repository contains for workload"
  type        = string
  default     = "gitops-workloads"
}

variable "gitops_workloads_basepath" {
  description = "Git repository base path for workload"
  type        = string
  default     = "gitops"
}

variable "gitops_workloads_path" {
  description = "Git repository path for workload"
  type        = string
  default     = "workloads"
}

variable "gitops_workloads_revision" {
  description = "Git repository revision/branch/ref for workload"
  type        = string
  default     = "main"
}

# Private deployments repo (GIT-13). OPT-IN: empty by default so a public-only "trial"
# install never references it (the root bootstrap appset falls back to the public catalogue).
# Set the repo name (per cluster, via tfvars) to enable the deployments overlay: the root
# appset then targets this repo's bootstrap/, which imports the clean public appsets and
# layers private values + adds extra apps. addons and workloads may share one repo or split.
variable "gitops_addons_private_repo" {
  description = "Private deployments repo for addons (empty = trial/public-only; set to opt in)"
  type        = string
  default     = ""
}

variable "gitops_addons_private_basepath" {
  description = "Subtree within the private repo for addons (basepath); enables one-repo-or-two"
  type        = string
  default     = "addons"
}

variable "gitops_addons_private_revision" {
  description = "Private overlay repo revision/branch/ref for addons values"
  type        = string
  default     = "main"
}

variable "gitops_workloads_private_repo" {
  description = "Private deployments repo for workloads (empty = trial/public-only; set to opt in)"
  type        = string
  default     = ""
}

variable "gitops_workloads_private_basepath" {
  description = "Subtree within the private repo for workloads (basepath); enables one-repo-or-two"
  type        = string
  default     = "workloads"
}

variable "gitops_workloads_private_revision" {
  description = "Private overlay repo revision/branch/ref for workloads values"
  type        = string
  default     = "main"
}

variable "extra_port_mappings" {
  description = "List of extra port mappings  to add to the control-plane node"
  type = list(object({
    container_port = string
    host_port      = string
  }))
  default = []
}

variable "kubeconfig_context" {
  description = "The kubeconfig context to use for the existing cluster"
  type        = string
}

variable "environment" {
  description = "Name of the environment"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "uat", "prod"], lower(var.environment))
    error_message = "Invalid environment. Must be one of 'dev', 'uat' or 'prod'."
  }
}

variable "region" {
  description = "region of the kubernetes cluster"
  type        = string
  default     = "local"
}

variable "cluster_type" {
  description = "Type of the kubernetes cluster"
  type        = string
  default     = "workload"
}

variable "domain_name" {
  description = "Domain name"
  type        = string
  default     = "cluster.local"
}

variable "kubernetes_distro" {
  description = "Name of the kubernetes distro"
  type        = string
  default     = "microk8s"
}

variable "kubernetes_version" {
  description = "Version of the kubernetes cluster"
  type        = string
  default     = "1.31"
}

variable "cloud_provider" {
  type        = string
  description = "Cloud provider"
  default     = "on-prem"
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
  })
  default = {
    load_addons    = true
    load_workloads = true
  }
}

variable "argocd_chart_version" {
  description = "Argocd helm chart version"
  type        = string
  default     = "7.7.12"
}

variable "addons" {
  description = "Addon selector labels. Keys must match ^enable_[a-z0-9_-]+$"
  type        = map(bool)
  default     = {
    enable_argocd   = true
  }
}

variable "allowed_addons" {
  description = "Optional allowlist of known addon flags."
  type        = list(string)
  default     = ["argocd", "keycloak", "velero", "cnpg", "private_overlays"]
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

# Private overlay Git (GIT-13)
# Values-only overlay repo layered over the public catalogues; environments/ and
# clusters/ live at repo root, so a `ref` source consumes only repo + revision.
# addons and workloads point at the same repo by default (single private repo);
# set different repos to split them.
variable "gitops_addons_private_repo" {
  description = "Private overlay repo for addons values"
  type        = string
  default     = "gitops-private"
}

variable "gitops_addons_private_revision" {
  description = "Private overlay repo revision/branch/ref for addons values"
  type        = string
  default     = "main"
}

variable "gitops_workloads_private_repo" {
  description = "Private overlay repo for workloads values"
  type        = string
  default     = "gitops-private"
}

variable "gitops_workloads_private_revision" {
  description = "Private overlay repo revision/branch/ref for workloads values"
  type        = string
  default     = "main"
}

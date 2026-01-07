terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.2"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = var.kubeconfig_context
}

provider "helm" {
  kubernetes = {
    config_path    = "~/.kube/config"
    config_context = var.kubeconfig_context
  }
}

provider "kubectl" {
  config_path      = "~/.kube/config"
  config_context   = var.kubeconfig_context
  load_config_file = true
}

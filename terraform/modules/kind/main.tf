resource "kind_cluster" "main" {
  name            = var.cluster_name
  kubeconfig_path = var.kubeconfig_path
  node_image      = "kindest/node:v${var.kubernetes_version}"
  wait_for_ready  = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"
    node {
      role = "control-plane"

      dynamic "extra_mounts" {
        for_each = var.extra_mounts
        content {
          host_path      = extra_mounts.value.host_path
          container_path = extra_mounts.value.container_path
        }
      }

      kubeadm_config_patches = [
        "kind: InitConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"ingress-ready=true\"\n",
      ]

      dynamic "extra_port_mappings" {
        for_each = var.extra_port_mappings
        content {
          container_port   = extra_port_mappings.value.container_port
          host_port        = extra_port_mappings.value.host_port
        }
      }
    }

    node {
      role = "worker"
    }
  }
}

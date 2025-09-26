# KIND Terraform Module

A lightweight Terraform module to spin up a local Kubernetes cluster using Kind (Kubernetes in Docker). It provisions a control-plane node (with optional mounts and port mappings) and a worker node, exports kubeconfig, and outputs connection details for use with other Terraform providers.

## Requirements

| Name | Version  |
|------|----------|
| Terraform | >= 1.0   |
| Provider tehcyx/kind | >= 0.9.0 |

## Providers

| Name | Version  |
|------|----------|
| kind | >= 0.9.0 |

## Resources

| Name | Type |
|------|------|
| [kind_cluster.main](https://registry.terraform.io/providers/tehcyx/kind/latest/docs/resources/cluster) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the cluster | string | n/a | yes |
| cluster_type | Type of the cluster, used in naming (validated: hub, spoke) | string | "hub" | no |
| environment | Name of the environment (validated: dev, uat, prod) | string | "dev" | no |
| extra_mounts | List of extra mounts to add to the control-plane node | list(object({ host_path = string, container_path = string })) | [] | no |
| extra_port_mappings | List of extra port mappings to add to the control-plane node | list(object({ container_port = string, host_port = string })) | [] | no |
| kubeconfig_path | Path to save the kubeconfig | string | n/a | yes |
| kubernetes_version | Version of the Kind node image (used as kindest/node:v<version>) | string | "1.31.2" | no |

## Outputs

| Name | Description |
|------|-------------|
| client_certificate | The client certificate for the KIND cluster |
| client_key | The client key for the KIND cluster |
| cluster_ca_certificate | The cluster CA certificate for the KIND cluster |
| cluster_endpoint | The endpoint of the KIND cluster |
| cluster_name | The name of the KIND cluster |
| kubeconfig_path | The path to the kubeconfig file for this cluster |

## Usage

- Ensure Docker is running.
- Ensure the kind provider is available (Terraform will install automatically).

Example:

```
module "kind_cluster" {
  source = "../modules/kind"

  cluster_name        = "demo"
  kubeconfig_path     = pathexpand("~/.kube/config-kind-demo")
  kubernetes_version  = "1.31.2"

  extra_mounts = [
    {
      host_path      = pathexpand("~/data")
      container_path = "/data"
    }
  ]

  extra_port_mappings = [
    {
      container_port = "80"
      host_port      = "80"
    },
    {
      container_port = "443"
      host_port      = "443"
    }
  ]
}
```

Notes:
- node_image is pinned to kindest/node:v<kubernetes_version> via the module.
- A worker node is created in addition to the control-plane.
- Outputs can be wired into kubernetes/helm/kubectl providers to manage the cluster from Terraform.

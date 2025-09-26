# GitOps Control Plane (Hub & Spoke)

An opinionated, minimal reference for evaluating GitOps with Argo CD and for building your own add-ons and workload delivery flows using GitOps Bridge. This repository instantiates a hub-and-spoke topology on KinD via Terraform, bootstraps Argo CD, and configures separate add-on and workload catalogues, which live in separate repositories.

Why this repository is useful:
- Demonstrates a clean separation of concerns:
  - Control plane (this repository): cluster life cycle (KinD), Argo CD bootstrap, cluster registration, and ApplicationSets.
  - Add-ons: platform capabilities (for example, Argo CD, Velero, CNPG) managed independently.
  - Workloads: application-facing delivery, decoupled from platform add-ons.
- Reproducible hub-and-spoke pattern that mirrors multi-cluster, multi-environment organisational setups.
- Fast local iteration loop (KinD + Terraform + Makefile) to prove out GitOps flows before pushing to managed Kubernetes.

## Repository layout
- Makefile: convenience targets for KinD, Terraform, and Argo CD.
- terraform/hub-spoke/hub: creates the hub KinD cluster.
- terraform/hub-spoke/spokes: creates named spoke KinD clusters via workspaces (dev/uat/prod). Use ./deploy.sh <workspace>.
- bootstrap/argocd: Argo CD namespace, configuration, and secrets (SOPS-encrypted variant included).
- kubeconfigs/hub-spoke: persisted kubeconfigs.

```md
.
├── Makefile
├── README.md
├── bootstrap
│   ├── argocd
│   │   ├── configmap.yaml
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── root-app.yaml
│   │   ├── secret-generator.yaml
│   │   ├── secrets.enc.yaml
│   │   ├── secrets.yaml
│   │   └── values.yaml
│   ├── hub
│   │   ├── addons.yaml
│   │   └── workloads.yaml
│   └── spoke
├── kubeconfigs
│   ├── README.md
│   └── hub-spoke
│       ├── hub
│       ├── spoke-dev
│       ├── spoke-prod
│       └── spoke-uat
└── terraform
├── hub-spoke
│   ├── hub
│   │   ├── locals.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── terraform.tfstate
│   │   ├── terraform.tfstate.backup
│   │   ├── terraform.tfvars
│   │   └── variables.tf
│   └── spokes
│       ├── deploy.sh
│       ├── locals.tf
│       ├── main.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── terraform.tfvars
│       ├── variables.tf
│       └── workspaces
│           ├── dev.tfvars
│           ├── prod.tfvars
│           └── uat.tfvars
└── modules
└── kind
├── README.md
├── main.tf
├── outputs.tf
├── variables.tf
└── versions.tf
```

### Related repositories and catalogues

Add-ons catalogue: default repository URL: <git organisation>/gitops-addons.git
```md
.
├── README.md
├── clusters
│   ├── hub
│   │   └── addons
│   └── spoke-dev
│       └── addons
├── environments
│   └── default
│       └── addons
│           ├── argo-cd
│           │   └── values.yaml
│           ├── velero-ui
│           │   └── values.yaml
│           └── velero
│               └── values.yaml
└── gitops
    └── addons
        ├── oss
        │   ├── argocd
        │   │   └── addon-argocd-appset.yaml
        │   ├── cloudnative-pg
        │   │   └── addons-cnpg-appset.yaml
        │   └── disaster-recovery
        │       ├── addons-velero-appset.yaml
        │       ├── addons-velero-ui-appset.yaml
        │       └── namespace.yaml
        └── project.yaml
```
Workloads catalogue: default repository URL: <git organisation>/gitops-workloads.git
```md
.
├── clusters
│   ├── hub
│   │   └── workloads
│   └── spoke-dev
│       └── workloads
├── environments
│   ├── default
│   │   └── workloads
│   │       └── home-assistant
│   │           └── values.yaml
│   └── dev
│       └── workloads
└── gitops
├── resources
│   └── pgcluster.yaml
└── workloads
└── home-assistant
└── ApplicationSet.yaml
```
The hierarchy for values files is:
```
  environments/default/[addons/workloads]/<chart>/values.yaml
  environments/<environment>/[addons/workloads]/<chart>/values.yaml
  cluster/<cluster-name>/[addons/workloads]/<chart>/values.yaml
```

This directory structure enables you to use a single repository for everything.

If you split these into separate Git repositories, you will need to create secrets for each repository. An example is included in bootstrap/argocd/secrets.yaml.

## Prerequisites

- A Kubernetes cluster (MicroK8s, k3s, kind, etc). For MicroK8s, enable:
- kubectl (cli)
- k9s (optional but handy)
- kustomize (cli)
- argocd (cli)
- sops and ksops
- direnv (handy for setting variable for accessing kubectl)

# Quick start
We use KinD to provide a playground to experiment with GitOps workflows in a comfortable and reproducible way. The Makefile includes targets to help you create the required clusters.

## Hub cluster
The hub cluster has Argo CD installed and contains a root add-on and workload ApplicationSets which will install the add-ons and workloads ApplicationSets from referenced repositories.

This repository is designed to let you tear down and rebuild hub-and-spoke clusters with ease:

```shell
  make clean-infra
```

```shell
  make hub-cluster
```

This will create a KinD cluster with a control-plane node and a single worker node.
The kubeconfig will be added to kubeconfig/hub-spoke/hub and KUBECONFIG will be set to use this configuration by .envrc.

You should now be able to access your Argo CD instance running in the hub cluster.

## Access Argo CD
Get admin password:
```shell
make argocd-password
```
Port-forward UI:
```shell
make argocd-ui
```
Open https://localhost:8088

Accept the certificate and sign in with the admin user and the password revealed above.

The cluster will install the root add-ons and workloads from the bootstrap folder in this repository, which will then pull the workloads and add-ons from the repositories configured as annotations on the hub cluster secret.

If you have used a private repository, you will need to create the repository secrets or Argo CD will not be able to pull these repositories. You can see an example secrets.yaml in /bootstrap/argocd

You can see these annotations by navigating to Settings / Clusters in the Argo CD user interface and clicking on the 'hub' cluster.

No workload applications will have been created, as the workloads repository generates Applications only for clusters labelled type=workload, and we have not yet created one.

## Spoke clusters
Each spoke cluster is a bare Kubernetes cluster and does not include Argo CD. ApplicationSets installed in the hub cluster use annotations on the Cluster Secret to determine which Application resources to render, and then Argo CD running on the hub accesses each cluster's Kubernetes API to install applications (using Helm, Kustomise or by applying resources directly).

### Development spoke
```shell
  make dev-cluster
```
You might have to run this command twice; the first time Terraform runs it may not have the IP address of the Kubernetes API server. If you see:
```diff
  + argocd_cluster_server  = "https://:6443"
```
in the output, run the make command again. You should then see the correct address for the API.

When you run deploy.sh, a KinD cluster with a control-plane node and a single worker node will be created. The certificate, CA, and key will be added into a kubeconfig in kubeconfig/hub-spoke/, and .envrc will set the KUBECONFIG environment variable to use these configurations.

### Exploring workloads
The Terraform that creates the spoke cluster sets a label type=workload on the cluster secret (see Settings / Clusters → spoke-dev) that is added to the hub Kubernetes API server.

The workload ApplicationSet resources in the gitops-workloads repository use generators to render Application resources, which are added to the hub Kubernetes API server.

```yaml
  generators:
    - merge:
        mergeKeys: [server]
        generators:
          - clusters:
              selector:
                matchLabels:
                  type: "workload"
              values:
                chartVersion: "0.3.10" # Default chart version
          - clusters:
              selector:
                matchLabels:
                  env: dev
              values:
                chartVersion: " 0.3.19" # Default addon chart version for dev
```
In this example, the matchLabels selector will only return clusters
that include the 'type' label with a value of 'workload'. This is how
we discriminate which workloads go where. This is just a simple example, but it is entirely possible to add whatever labels you like to the cluster secret (in the Terraform code) and then use any selector expression to limit where that workload would run.

### Production spoke
You can now go ahead and create a production cluster and start testing how the values files are overridden in environments.
```shell
  make prod-cluster
```
## Install / Bootstrap Argo CD on an existing cluster

### Kustomize (installs Argo CD + root app + uses Helm to install the application-sets chart):
- Edit bootstrap/argocd/values.yaml and set repoURL and targetRevision.
- Note: The same targetRevision from bootstrap/argocd/values.yaml is automatically propagated to:
  - the application-sets Application (so it tracks the same branch/tag/commit), and
  - the application-sets chart value repoURLGitRevision, which controls the targetRevision of all component Applications generated by the chart.
    Build and deploy Argo CD bootstrap configuration:

  ```shell
  kustomize build bootstrap/argocd --enable-alpha-plugins --enable-exec --load-restrictor LoadRestrictionsNone --enable-helm | kubectl apply -n argocd -f -
  ```

## Securing private repositories with Personal Access Tokens (PAT)
If gitops-addons and/or gitops-workloads live in private Git repositories:
- Generate a least-privilege PAT (read-only) in your Git hosting provider.
- In Argo CD, create a repository credential secret:
  - For HTTPS repos:
    - name: your-repo
    - type: git
    - url: https://github.com/your-org/gitops-addons.git (repeat for workloads)
    - username: <your-username or token id>
    - password: <PAT>
  - You can store these as Kubernetes Secrets and manage them with SOPS. Example flow:
  - Create a repository secret manifest conforming to argoproj.io/v1alpha1 Repository spec or core/v1 Secret with Argo CD annotations.
  - Encrypt with SOPS (age/GPG as per your policy).
  - Place under bootstrap/argocd and apply via make argocd-bootstrap.


#### Operational notes
- Tear down all KinD clusters:
  make kind-delete-all-clusters
- List clusters:
  make kind-list-clusters
- Remove Terraform state:
  make terraform-rm-state all|spokes|<workspace>

#### Using GitOps Bridge
This control-plane repository uses the GitOps Bridge Terraform module for composing cross-repository delivery flows. GitOps Bridge is used to set the initial configuration for the ApplicationSets. 

#### Where to start iterating
- Add-ons: define or adjust ApplicationSets under gitops-addons/gitops/addons and tune values under gitops-addons/environments.
- Workloads: define ApplicationSets and manifests under gitops-workloads/gitops and environment values under gitops-workloads/environments.

## Terraform variables and tfvars examples

This repo provisions KinD clusters via Terraform in a hub-and-spoke topology. Variables live under:
- terraform/hub-spoke/hub/variables.tf (Hub cluster)
- terraform/hub-spoke/spokes/variables.tf (Spoke clusters via workspaces)
- terraform/modules/kind/variables.tf (KinD module)

Below is a concise reference of available variables and their defaults. For the authoritative list, 
see the variables.tf files linked above.

Hub (terraform/hub-spoke/hub)
- environment (string, default: "dev") — Environment name. Allowed: dev, uat, prod.
- region (string, default: "north-america") — Logical region. Allowed: north-america, europe, asia-pacific.
- cluster_type (string, default: "hub") — Must be hub.
- domain_name (string, default: "cluster.local") — Cluster DNS domain.
- kubernetes_distro (string, default: "kind") — Allowed: kind, k3d, k0s.
- kubernetes_version (string, default: "1.33.1") — KinD node image version.
- cloud_provider (string, default: "local") — Allowed: local, aws, azure, gcp.
- enable_gitops_bridge (bool, default: true) — Enable GitOps Bridge integration.
- argocd_files_config (object, default: { load_addons=true, load_workloads=true }) — Control which file trees are rendered by Argo CD bootstrap.
- argocd_chart_version (string, default: "8.5.4") — Argo CD Helm chart version used by bootstrap.
- addons (any, default: { enable_argocd=true, enable_keycloak=false, enable_velero=false }) — Toggle add-on families.
- gitops_org (string, default: "https://github.com/SilexConsulting") — Org/user base URL for Git repositories.
- gitops_addons_repo (string, default: "gitops-addons") — Addons repo name.
- gitops_addons_revision (string, default: "main") — Addons repo git ref.
- gitops_addons_basepath (string, default: "gitops") — Base path within addons repo.
- gitops_addons_path (string, default: "addons") — Subpath within addons repo hosting ApplicationSets.
- gitops_addons_extras_repo (string, default: "helm-charts") — Extra charts repo name.
- gitops_addons_extras_basepath (string, default: "charts") — Base path for extra charts repo.
- gitops_addons_extras_revision (string, default: "main") — Extra charts repo git ref.
- gitops_workloads_repo (string, default: "gitops-workloads") — Workloads repo name.
- gitops_workloads_basepath (string, default: "gitops") — Base path within workloads repo.
- gitops_workloads_path (string, default: "workloads") — Subpath for workloads ApplicationSets.
- gitops_workloads_revision (string, default: "main") — Workloads repo git ref.
- extra_port_mappings (list(object), default: []) — Additional host<->container port mappings for KinD control-plane. Keys: container_port, host_port.

Spokes (terraform/hub-spoke/spokes)
- environment (string, default: "dev") — Environment name. Allowed: dev, uat, prod.
- region (string, default: "north-america") — Logical region. Allowed: north-america, europe, asia-pacific.
- cluster_type (string, default: "spoke") — Must be spoke.
- domain_name (string, default: "cluster.local") — Cluster DNS domain.
- kubernetes_distro (string, default: "kind") — Allowed: kind, k3d, k0s.
- kubernetes_version (string, default: "1.33.1") — KinD node image version.
- cloud_provider (string, default: "local") — Allowed: local, aws, azure, gcp.
- enable_gitops_bridge (bool, default: false) — Usually false on spokes; Argo CD runs on hub.
- argocd_files_config (object, default: { load_addons=true, load_workloads=true }).
- argocd_chart_version (string, default: "8.5.4").
- addons (any, default: { enable_argocd=false, enable_keycloak=false, enable_velero=false, enable_cnpg=false }).
- gitops_org (string, default: "https://github.com/SilexConsulting") — Base Git URL for addons/workloads.
- gitops_addons_repo (string, default: "gitops-addons").
- gitops_addons_revision (string, default: "main").
- gitops_addons_basepath (string, default: "gitops").
- gitops_addons_path (string, default: "addons").
- gitops_addons_extras_repo (string, default: "helm-charts").
- gitops_addons_extras_basepath (string, default: "charts").
- gitops_addons_extras_revision (string, default: "main").
- gitops_workloads_repo (string, default: "gitops-workloads").
- gitops_workloads_basepath (string, default: "gitops").
- gitops_workloads_path (string, default: "workloads").
- gitops_workloads_revision (string, default: "main").

KinD module (terraform/modules/kind)
- cluster_name (string, required) — Name of the KinD cluster to create.
- cluster_type (string, default: "hub") — Allowed: hub, spoke.
- environment (string, default: "dev") — Allowed: dev, uat, prod.
- kubernetes_version (string, default: "1.31.2") — KinD node image version for module.
- kubeconfig_path (string, required) — Path where kubeconfig will be written.
- extra_mounts (list(object), default: []) — Additional hostPath mounts. Keys: host_path, container_path.
- extra_port_mappings (list(object), default: []) — Additional port mappings. Keys: container_port, host_port.

Examples (.tfvars)
- Hub example (save in terraform/hub-spoke/hub/terraform.tfvars)

```terraform
gitops_addons_revision = "mynew-addon"
addons = {
  enable_keycloak = true
  enable_velero   = true
  enable_argocd   = true
}
extra_port_mappings = [
  { container_port = 30001, host_port = 30001 },
  { container_port = 30002, host_port = 30002 },
  { container_port = 30080, host_port = 30080 },
  { container_port = 30443, host_port = 30443 }
]
```
By setting the gitops_addons_revision, you can test changes to add-ons from a branch. 

- Spokes common example (see terraform/hub-spoke/spokes/terraform.tfvars)

```terraform
gitops_addons_revision = "cnpg-addon"
addons = {
  enable_keycloak = true
  enable_velero   = true
  enable_cnpg     = true
}
```
After making changes to tfvars, run terraform again and it will update the annotations and labels to allow you to test. 

- Spoke workspace overrides (see terraform/hub-spoke/spokes/workspaces/*.tfvars)

  # dev.tfvars
  environment  = "dev"
  cluster_type = "spoke"

  # uat.tfvars
  environment  = "uat"
  cluster_type = "spoke"

  # prod.tfvars
  environment  = "prod"
  cluster_type = "spoke"
  addons = {
    enable_keycloak = true
    enable_velero   = false
    enable_cnpg     = false
  }

Usage
- Hub
  - cd terraform/hub-spoke/hub
  - terraform init
  - terraform apply -var-file=terraform.tfvars

- Spokes (workspace pattern)
  - cd terraform/hub-spoke/spokes
  - terraform init
  - terraform workspace new dev | true; terraform workspace select dev
  - terraform apply -var-file=terraform.tfvars -var-file=workspaces/dev.tfvars
  - Repeat for uat/prod with the corresponding workspace and tfvars file.

Troubleshooting

License
Apache 2.0

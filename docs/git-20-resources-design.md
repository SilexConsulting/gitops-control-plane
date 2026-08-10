# Operator-backed & cluster resources — design (GIT-20)

Status: **agreed design, pre-implementation** · Jira: **GIT-20** · Last updated: 2026-08-09

## Purpose

Give teams a GitOps-native way to declare **resource instances** — objects that are neither a
Helm-installed add-on nor a workload chart, but plain manifests applied onto a cluster:

- **operator-backed CRD instances** (e.g. a CloudNativePG `Cluster` = a database), which only
  make sense where the backing operator add-on is installed;
- **workload-scoped resources** (e.g. an External Secrets `ExternalSecret`/`SecretStore` an
  application depends on), which only make sense where that workload runs;
- **cluster/platform-wide resources** with no single owner (e.g. an `IngressClass`, a
  `StorageClass`).

The convention is **additive** — it changes nothing about how add-ons or workloads are
installed today — and stays **overridable from the private deployments repo** (see
[private-overlays-design.md](./private-overlays-design.md), GIT-13) so organisations customise
resources without mutating the public catalogues.

## Design goals / non-goals

#### Goals
- Keep the current repository structure for add-ons and workloads intact; only add paths.
- A discoverable, low-ceremony convention: add a manifest + list it in a `kustomization.yaml`
  and it reconciles to the target cluster.
- Resources reconcile **last** (after operators and workloads).
- Resources are gated so they are only evaluated where their owner is enabled.
- Resources are overridable/augmentable per environment and per cluster, and from the private
  deployments repo, via **Kustomize**.

#### Non-goals
- No change to operator/add-on installation (still via add-ons).
- No broad repo rearrangement — only additive paths and manifests.
- No hard cross-Application ordering barrier; **eventual consistency** (Argo retry) is accepted.

## Where resources live

Resources live in a **`resources/` directory** that is a sibling of the existing `workloads/`
and `addons/` value trees, at **three scope levels** — mirroring the established values layering:

```
<repo>/
  bootstrap/
    resources.yaml                       # the resources ApplicationSet (see below)
  environments/
    default/
      addons/<addon>/values.yaml         # unchanged
      workloads/<workload>/values.yaml   # unchanged
      resources/                         # indiscriminate — all resource-enabled clusters
        kustomization.yaml               # lists the manifests to apply
        storageclass/gp3-encrypted-ebs.yaml
        external-secrets/secret-store.yaml
    <env>/
      resources/                         # environment-scoped (e.g. dev, prod)
        kustomization.yaml
        ...
  clusters/
    <cluster_name>/
      resources/                         # cluster-scoped
        kustomization.yaml
        ...
```

Each `resources/` directory has a **single root `kustomization.yaml`** that enumerates the
manifests (organised by kind in sub-directories) it wants applied:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - storageclass/gp3-encrypted-ebs.yaml
  - external-secrets/secret-store.yaml
```

A resource is applied **only if it is listed** in the `kustomization.yaml` that the
ApplicationSet builds. That listing is the selection/gating mechanism: a manifest that is not
listed (because its owning add-on/workload is not enabled on that scope) is simply never
rendered. Association between a resource and its owner is by **convention/naming**, not by
directory nesting under the owner.

Add-on-owned and cluster-wide resources live in **`gitops-addons`**; workload-owned resources
live in **`gitops-workloads`** — each in the repo whose ApplicationSet already carries the
right repo annotations.

## The ApplicationSets

There are **three** resource categories, each an ApplicationSet producing one Application per
cluster named `cluster-<cluster_name>[-<scope>]-resources`:

| ApplicationSet | Application | Category | Source (per scope: `environments/default`, `environments/<env>`, `clusters/<cluster>`) |
|---|---|---|---|
| `resources` (root-level, control-plane `bootstrap/hub/resources.yaml`) | `cluster-<name>-resources` | **cluster-wide** (no owner) — `IngressClass`, `StorageClass` | **`gitops-addons`** `…/resources/` |
| `addons-resources` (`gitops-addons/bootstrap/resources.yaml`) | `cluster-<name>-addons-resources` | **addon-owned** — CNPG `Cluster` | `gitops-addons` `…/addons-resources/` |
| `workloads-resources` (`gitops-workloads/bootstrap/resources.yaml`) | `cluster-<name>-workloads-resources` | **workload-owned** — ESO `ExternalSecret` | `gitops-workloads` `…/resources/` |

> **Signpost — where cluster-wide resources live:** `gitops-addons/environments/default/resources/`
> (plus `environments/<env>/resources/` and `clusters/<cluster>/resources/` overlays). Addon-owned
> resources use the sibling `addons-resources/` tree in the same repo so the two never collide;
> workload-owned resources use `resources/` in the workloads repo.

The global `resources` appset is **root-level** (applied by Terraform in both modes; it reads the
addons repo, which is never repointed). `addons-resources` / `workloads-resources` are delivered
"inside" their catalogue flow: trial mode via the control-plane roots
`bootstrap/hub/{addons,workloads}-resources-root.yaml` (trial-only), deployments mode via the
private repo's `<basepath>/bootstrap` import.

Key properties:

- **Gate: `enable_resources`.** The generator is a `clusters` generator selecting the
  `enable_resources` cluster label (`In ["true"]`), optionally merged with env-specific value
  overrides. This is the per-cluster master switch for the whole resources layer.
- **Layering via Kustomize.** Each scope path is a Kustomize build; later scopes override
  earlier ones (`default → env → cluster`), the same last-wins precedence as Helm value files.
- **GIT-13 overrides via `kustomize.patches`.** The appset can carry `kustomize.patches`
  templated from cluster-secret annotations (e.g. patch a `StorageClass`'s `kmsKeyId` from an
  annotation), so private/per-cluster data is injected without editing the public base.
- **Reconcile last.** Manifests carry a high `argocd.argoproj.io/sync-wave` so they order after
  operators/workloads within a sync; across Applications, Argo retry provides eventual
  consistency (accepted — a resource whose CRD/namespace is not yet present just retries).
- `project: default`, `syncPolicy.automated { prune, selfHeal }`, `# nonk8s` marker, and
  `goTemplate` consistent with the sibling bootstrap files.

## Control-plane wiring & delivery (two modes, no double-delivery)

The clean `resources.yaml` appset lives in each public repo's top-level `bootstrap/`. How it
reaches a cluster depends on the mode, and the two modes are **mutually exclusive per repo** so
the appset is never delivered twice:

- **Trial / public-only** (no `*_private_repo_url`): the control plane's
  `bootstrap/hub/{addons-resources-root,workload-resources-root}.yaml` **root** ApplicationSets deliver it — they
  target the public repo's top-level `bootstrap/` and install the appset onto the Argo hub
  (selector `is_hub: "true"`). These roots are **trial-only**: in `argocd_apps` they resolve to
  `""` when the corresponding `*_private_repo_url` is set, so nothing is emitted in deployments
  mode.
- **Deployments mode** (`*_private_repo_url` set): the private repo's `<basepath>/bootstrap`
  Kustomize **imports** the public `resources.yaml` appset (pin the import to a commit SHA to
  avoid raw-CDN staleness) and may **patch** it — e.g. inject `kustomize.patches` that override a
  public resource. The existing `addons`/`workloads` roots (already pointed at the private
  bootstrap) deliver it; the control-plane resource root stays out of the way (trial-only), so
  there is no duplicate ApplicationSet.

Both paths were validated live on a KinD hub (see "Validation"). The `argocd_apps` map keys
become Helm release names, so they must be RFC1123 (`addons-resources-root`, hyphens — **not**
underscores), and empty entries are filtered out so a trial-only-gated entry creates no release.

Terraform changes (all three stacks: `on-prem`, `hub-spoke/hub`, `hub-spoke/spokes`):

- Add `enable_resources` as a recognised cluster label (the master switch).
- Add an `allowed_workloads` list (mirror of `allowed_addons`) and **widen the unknown-key
  validation** so `keys(var.addons)` is checked against
  `union(allowed_addons, allowed_workloads, ["enable_resources"])` — keeping the
  `allow_unknown_addons` escape hatch. This is the "flexible way to validate these in TF":
  add-on flags, workload flags and the resources master switch are all validated by one
  mechanism.
- Add `load_resources` to `argocd_files_config`; build `argocd_apps` from `argocd_apps_all`
  filtering empties, with the two `resources-*` roots gated to trial mode
  (`load_resources && <repo>_private_url == ""`).

## Gating model — the enablement chain

1. **`enable_resources`** turns the resources ApplicationSet on for a cluster (coarse, per
   cluster).
2. **Per-owner inclusion** is honoured because a disabled owner's manifest is never listed in
   the `kustomization.yaml` the appset reaches, so it is never rendered for that
   scope/cluster.
3. **Belt-and-braces / eventual consistency:** even if a manifest is listed on a cluster where
   its operator/workload is absent, Argo simply retries until (or unless) the dependency
   appears — no hard failure, no ordering barrier required.

Add-on gating reuses the existing `enable_<addon>` labels; workload gating uses the new,
additive `enable_<workload>` labels (existing workload ApplicationSets keep selecting on
`type`/`env` and are **not** rewired).

## Precedence (low → high)

```
public environments/default/resources
  → public environments/<env>/resources
    → public clusters/<cluster>/resources
      → private overlays / annotation-templated kustomize.patches (deployments mode)
```

## Verification

1. `kustomize build` each `environments/default/resources` and `clusters/<cluster>/resources`.
2. `kubectl apply --dry-run=client` the rendered manifests and the two bootstrap appsets.
3. `terraform validate` in all three stacks; confirm the widened allowlist accepts
   `enable_resources` and `enable_<workload>` while still rejecting unknown keys.
4. Live: set `enable_resources = true`, confirm the `*-resources` Applications appear, a listed
   CRD instance (e.g. CNPG `Cluster`) reconciles once its operator is present, and an unlisted /
   disabled-owner resource is not rendered.

### Validation — done 2026-08-09 on a KinD hub (`make hub-cluster`)

- **Both delivery modes at once:** addons in deployments mode (addons-resources delivered by the
  `gitops-private` bootstrap), workloads in trial mode (workload-resources delivered by the
  control-plane trial root). All three resource apps `Synced/Healthy`.
- **Convention + gating:** the public `IngressClass` deployed to the hub (env=dev, cluster=hub);
  the ivylen-scoped CNPG `Cluster` was correctly NOT rendered on the hub.
- **Private override proven:** `gitops-private` patched the imported `addons-resources` appset to
  annotate the public IngressClass; the live object carried
  `git-20.silex-consulting.com/private-override`. Changing the value in `gitops-private` and
  pushing propagated to the live resource — the public repo was never touched.
- **Bugs found & fixed during the test:** (1) `argocd_apps` keys become Helm release names —
  renamed underscores→hyphens (e.g. `addons-resources-root`) and filtered empty entries; (2) the appset used
  a `merge` generator with a single child (`merge` needs ≥2) — replaced with a plain `clusters`
  generator; (3) each enabled `(env, cluster)` needs its `resources/` scope dir to exist or the
  kustomize source 404s — ship empty scope stubs (a future enhancement could tolerate missing
  paths); (4) pin remote Kustomize imports to a commit SHA to avoid GitHub raw-CDN staleness.

## Dependencies / related

- **GIT-13** — private overlays / deployments repo. This design reuses its trial/deployments
  conditional and its private `bootstrap/` superset-import rule.
- **GIT-23** — `enable_pgng` vs `enable_cnpg` bug: the on-prem `ivylen` cluster sets
  `enable_pgng` but the CNPG add-on (and any CNPG resource) selects on `enable_cnpg`, so CNPG
  never deploys there. The CNPG `Cluster` reference resource will not reconcile on `ivylen`
  until GIT-23 is fixed.
- **GIT-6 / GIT-10** — External Secrets Operator does not exist yet; the workload-scoped
  `ExternalSecret` example ships as a documented placeholder until ESO lands.

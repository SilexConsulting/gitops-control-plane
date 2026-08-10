# Private overlays / deployments repo — design (GIT-13)

Status: **agreed design, pre-implementation** · Jira: **GIT-13** · Last updated: 2026-08-08

## Purpose

Let implementers layer **private, credentialed, per-organisation configuration** (values,
secrets, cluster resources) on top of the **public** add-on and workload catalogues —
without modifying or forking the public repos, with a deterministic precedence order.

## Two kinds of repo

| | Public catalogues (`gitops-addons`, `gitops-workloads`) | Private **deployments** repo (e.g. `gitops-private`) |
|---|---|---|
| Role | Generic, reusable capability library (appsets, base/default + environment values, optionally vendored charts) | An organisation's **deployment declaration**: which clusters, add-ons, workloads and resources it runs, plus private/cluster-specific values and secrets |
| Visibility | Public — cloneable/forkable | Private — SSH deploy key |
| Ownership of "what boots" | Provides appsets usable as-is for a **trial** | **Owns `bootstrap/`** — decides which appsets boot for that org, and carries the Kustomize patching that layers private data over the public appsets |

## Two modes of operation

1. **Trial / public-only.** Bootstrap the control plane against just the public catalogues.
   Everything works out of the box so an evaluator can see what GitOps does with near-zero
   effort. Forking the public repos is possible but then you own the divergence.
   **⇒ The public catalogue appsets must stay clean — they must never reference a private repo.**
2. **Deployments mode.** An organisation supplies a private deployments repo. The control-plane
   root app points at the **private repo's `bootstrap/`** instead of the public appsets. That
   bootstrap imports the public appsets and **patches in** the private overlay.

The mode is selected per cluster at registration, via the repo path/basepath annotations on the
Argo CD cluster secret — no code change, no per-cluster label toggle.

## Repository layouts

**Public catalogues stay as they are today** — `basepath` bridges any shape difference, so no
public restructure is required. (Bundling a `charts/` folder in the public repos may make sense
later; deferred.)

**Private deployments repo** (this is the shape `gitops-private` must adopt):

```
<private repo>/
  addons/
    bootstrap/       # ApplicationSets that boot; Kustomize that imports the public
                     # addon appsets and patches in the private source + $private values
    charts/          # vendored Helm charts needed at bootstrap, or unpublished charts
                     # not worth their own repo (secret-gated registries can't be pulled
                     # before the secret exists — chicken-and-egg, e.g. external-secrets)
    clusters/<cluster>/<app>/values.yaml     # per-cluster (private, most specific)
    environments/<env>/<app>/values.yaml     # per-environment (private)
    .gitignore
    README.md
  workloads/
    bootstrap/ | charts/ | clusters/ | environments/ | .gitignore | README.md
```

`addons/` and `workloads/` are **self-contained siblings**, so the same layout serves **one
combined repo or two split repos** by config alone (see the annotation contract).

## Layering mechanism

The private repo's `bootstrap/` uses **Kustomize** (already a first-class dependency of this
repo — see `bootstrap/argocd/kustomization.yaml` + ksops) to:

1. import the clean public appsets as resources, and
2. **patch** each to add a private `ref` source and append the private value files, e.g.

   - add source: `repoURL: '{{ .metadata.annotations.<kind>_private_repo_url }}'`,
     `targetRevision: '{{ … _private_repo_revision }}'`, `ref: private` (URL is
     **annotation-templated**, so each org/cluster patches in **its own** private repo);
   - append valueFiles:
     `$private/<basepath>/environments/{{ env }}/<app>/values.yaml`,
     `$private/<basepath>/clusters/{{ cluster }}/<app>/values.yaml`.

Non-Helm, per-cluster **resources** (StorageClasses, etc.) layer via Argo-native
`source.kustomize.patches` driven by annotations (the `resources` appset pattern) — this is
GIT-20 territory, not required for GIT-13's value/secret layering.

### Precedence (lowest → highest, last wins)

```
public  environments/default/<kind>/<app>/values.yaml
public  environments/<env>/<kind>/<app>/values.yaml
private environments/<env>/<kind>/<app>/values.yaml
private clusters/<cluster>/<kind>/<app>/values.yaml
```

Cluster is the most specific layer and is **private only** — real cluster names, IPs and hosts
are private facts. There is no *organisation* public-cluster layer. (The public repo may retain
a `clusters/` tree for its own trial/demo purposes; org deployments do not use it.)

## Annotation contract (Terraform → Argo CD cluster secret)

Existing (public): `addons_repo_{url,basepath,path,revision}`,
`workloads_repo_{url,basepath,path,revision}`.

New (private, GIT-13): for each kind `{addons, workloads}`:

```
<kind>_private_repo_url        # SSH URL of the deployments repo (per org/cluster)
<kind>_private_repo_basepath   # "addons" | "workloads" — subtree within the private repo
<kind>_private_repo_revision   # branch/ref
```

- **Single private repo:** both `*_private_repo_url` point at the same repo; basepaths are
  `addons` / `workloads`.
- **Two private repos:** point the two URLs at different repos; basepaths unchanged.
- Built from `var.gitops_private_org` (SSH prefix, distinct from the HTTPS `gitops_org`) +
  `var.gitops_{addons,workloads}_private_{repo,revision}`, per Terraform stack.
- No `enable_private_overlays` label is needed — mode is chosen by which appsets the root app
  loads (public vs private `bootstrap/`). *(The toggle added in the first Phase-1 pass is
  therefore dropped.)*

## Secrets

- **SOPS decrypted/applied from outside the cluster only** — no in-cluster SOPS (matches the
  ksops-local pattern already used for the Argo repo secrets). Applied via
  `sops -d … | kubectl apply -f -` / local Kustomize build.
- **Runtime secrets via External Secrets.** ESO does not exist yet — it depends on the
  external-secrets add-on (**GIT-6/GIT-10**) and a backend (**GIT-7**). ESO is required by the
  GIT-13 acceptance criteria, so **GIT-13 cannot be fully closed until ESO lands**; it is the
  next piece of work. Vendored `charts/` in the private `bootstrap/` breaks the chicken-and-egg
  for the external-secrets chart itself.
- The SSH deploy key for the private repo is stored as an Argo CD repository Secret,
  SOPS-encrypted, applied out-of-cluster.

## Scope & related tickets

- **GIT-13 (this):** the private-overlay / deployments-repo pattern for **values + secrets**,
  proven end-to-end on ivylen (single combined private repo).
- **GIT-6 / GIT-10:** external-secrets add-on — blocks final GIT-13 closure.
- **GIT-7:** Vault backend.
- **GIT-20:** per-cluster resources via `source.kustomize.patches` (same annotation-driven
  Kustomize technique, different content).
- Deferred: bundling a `charts/` folder in the public catalogues.

## Implementation phases

1. **Terraform** (`gitops-control-plane`, branch `GIT-13`): add `*_private_repo_basepath`;
   keep `*_private_repo_url/revision` + `gitops_private_org`; remove the now-unused
   `enable_private_overlays` toggle. (Partly done in the first Phase-1 pass; needs the basepath
   addition and toggle removal.)
2. **Private repo** (`gitops-private`): restructure to the `addons/` + `workloads/` layout with
   real `bootstrap/` (Kustomize import-and-patch), `charts/`, `clusters/`, `environments/`.
   Re-home the seeded ivylen home-assistant overlay under `workloads/`.
3. **Control-plane bootstrap:** allow the root app to target the private repo's `bootstrap/`
   for deployments-mode clusters (via path/basepath annotations); public appsets untouched.
4. **Credentials:** private-repo SSH deploy key as a SOPS-encrypted Argo repository Secret.
5. **Validate on ivylen:** public deploys, private overlay overrides a value (LoadBalancer IP),
   no public-catalogue change needed.
6. **ESO integration** (GIT-6/10 + GIT-7) — unblocks final GIT-13 closure.
```

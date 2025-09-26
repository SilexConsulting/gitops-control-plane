### Update: Dynamic addon labels via enable_<addon> flags (decoupled from catalog)

This change introduces a more flexible way to drive cluster selection for addons and workloads: any key in the `addons` map that matches `enable_<addon-name>` (and is set to `true`) becomes a cluster label exposed through the GitOps Bridge. This decouples the control-plane Terraform from the workloads and addons catalogs (no code change required here when the catalog adds new addons).

#### What changed
- You can define arbitrary addon flags in `var.addons`, e.g. `enable_argocd`, `enable_keycloak`, `enable_velero`, `enable_cnpg`, or any other `enable_<name>` that your catalog understands.
- These flags are forwarded to the Argo CD cluster secret as selector labels via the GitOps Bridge module. Catalog apps can then select clusters using those labels (e.g., with Argo CD ApplicationSet label selectors).
- Strict/lenient validation is configurable:
  - `allowed_addons` defines the known/allowed addon names.
  - `allow_unknown_addons` toggles strict mode.

Both hub and spoke stacks support this behavior (see variables and validation in `terraform/hub-spoke/hub` and `terraform/hub-spoke/spokes`).

---

### How to use

#### 1) Define addons in tfvars

Provide a map of addon flags. Keys must match the regex `^enable_[a-z0-9_-]+$`.

Example (`terraform.tfvars`):

```hcl
# hub example
addons = {
  enable_argocd   = true   # hub
  enable_keycloak = true
  enable_velero   = false
  # You can add any new addon without touching this repo:
  enable_cnpg     = true
}

# spoke example
addons = {
  enable_argocd   = false  # hub only
  enable_keycloak = true
  enable_velero   = true
  # Arbitrary new workload your catalog supports:
  enable_payments = true
}
```

These keys and their boolean values are passed through to the GitOps Bridge and become available as labels on the registered cluster secret in the hub. Your catalog can select clusters by these `enable_*` labels.

Tip: Base cluster labels (environment, region, cloud, distro, version, type) are also included by default and remain unchanged.

#### 2) Control validation behavior

- `allowed_addons` (list of strings) defines the allowlist of known addons. Defaults include: `argocd, keycloak, velero, cnpg`.
- `allow_unknown_addons` (bool) controls how unknown `enable_*` keys are treated:
  - `true` (default): lenient mode. Unknown keys are permitted.
  - `false`: strict mode. Terraform will error if unknown addons are found.

Examples (`terraform.tfvars`):

```hcl
# Lenient mode (default)
allow_unknown_addons = true

# Strict mode: only allow known addons
allow_unknown_addons = false
allowed_addons       = ["argocd", "keycloak", "velero", "cnpg", "payments"]
```

To approve a new addon in strict mode, add its bare name to `allowed_addons` (the system internally prefixes with `enable_`).

---

### Error messaging in strict mode

When `allow_unknown_addons = false` and your `addons` map contains unknown keys, plan/apply fails with a detailed message. Example:

```
Unknown addon keys found and allow_unknown_addons is false: enable_argocd, enable_keycloak, enable_nonsense].
Known keys: [enable_velero].
Either fix the key(s), extend allowed_addons in tfvars, or set allow_unknown_addons = true.
```

Notes:
- The message enumerates unknown keys discovered in your `addons` map.
- It also prints the list of known keys derived from your `allowed_addons` variable (each item is shown as `enable_<name>`).
- To resolve: fix typos, extend `allowed_addons` in your tfvars, or switch to lenient mode by setting `allow_unknown_addons = true`.

---

### Reference: key variables

- `variable "addons" (map(bool))`
  - Each key must match `^enable_[a-z0-9_-]+$`.
  - True values mark the addon as enabled and are forwarded as cluster labels via the GitOps Bridge.

- `variable "allowed_addons" (list(string))`
  - The allowlist of known addons (without the `enable_` prefix). Defaults: `argocd`, `keycloak`, `velero`, `cnpg`.

- `variable "allow_unknown_addons" (bool)`
  - Default: `true` (lenient). Set to `false` for strict validation.

---

### Why this helps

- Decouples control-plane code from the addons/workloads catalog. New addons can be introduced solely in the catalog by targeting `enable_<addon>` labels; no Terraform code changes are required here.
- Enables progressive rollout: you can toggle addons per-cluster by flipping the corresponding `enable_<addon>` flag.
- Keeps safety via optional strict validation in environments where you want to enforce a curated set of addons.

If your catalog uses ApplicationSets, you can select clusters with label selectors that match these `enable_*` flags combined with the standard cluster context labels (cloud, region, env, type, distro, version).

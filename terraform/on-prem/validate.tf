resource "null_resource" "addons_validation" {
  triggers = {
    validation_hash = sha1(join(",", concat(local.unknown_addons, local.distro_addon_conflicts)))
  }

  lifecycle {
    precondition {
      condition     = var.allow_unknown_addons || length(local.unknown_addons) == 0
      error_message = "Unknown enable_* keys found and allow_unknown_addons is ${var.allow_unknown_addons}: ${join(", ", local.unknown_addons)}].\nKnown keys: [${join(", ", local.allowed_enable_keys)}].\nEither fix the key(s), extend allowed_addons/allowed_workloads in tfvars, or set allow_unknown_addons = true."
    }
    precondition {
      condition     = length(local.distro_addon_conflicts) == 0
      error_message = "Add-on(s) both distro-provided and enabled via the catalogue: ${join(", ", local.distro_addon_conflicts)}.\nA controller must have one owner: remove it from distro_provided_addons (after disabling the distro add-on, e.g. `microk8s disable <addon>`) or drop enable_<addon>."
    }
  }
}

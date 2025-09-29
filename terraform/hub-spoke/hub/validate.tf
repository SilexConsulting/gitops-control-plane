resource "null_resource" "addons_validation" {
  triggers = {
    validation_hash = sha1(join(",", local.unknown_addons))
  }

  lifecycle {
    precondition {
      condition     = var.allow_unknown_addons || length(local.unknown_addons) == 0
      error_message = "Unknown addon keys found and allow_unknown_addons is ${var.allow_unknown_addons}: ${join(", ", local.unknown_addons)}].\nKnown keys: [${join(", ", local.allowed_addons)}].\nEither fix the key(s), extend allowed_addons in tfvars, or set allow_unknown_addons = true."
    }
  }
}

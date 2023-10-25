
output "f5_username" {
  value = (var.custom_user_data == null) ? var.f5_username : "Username as provided in custom runtime-init"
}

output "bigip_password" {
  value = (var.custom_user_data == null) ? ((var.f5_password == "") ? (var.gcp_secret_manager_authentication ? data.google_secret_manager_secret_version.secret[0].secret_data : random_string.password.result) : var.f5_password) : "Password as provided in custom runtime-init"
}

output "mig_id" {
  value = google_compute_region_instance_group_manager.mig.instance_group
}

output "service_account" {
  value = var.service_account
}

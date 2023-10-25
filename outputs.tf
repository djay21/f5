output "bigip_password" {
  value = module.bigip.*.bigip_password
}
output "bigip_username" {
  value = module.bigip.*.f5_username
}

output "service_account" {
  value = module.bigip.*.service_account
}

output "managed_instance_group_id" {
  value = module.bigip.*.mig_id
}
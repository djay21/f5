output "bigip_password" {
  value = module.bigip1.*.bigip_password
}
output "mgmtPublicIP" {
  value = module.bigip1.*.mgmtPublicIP
}
output "bigip_username" {
  value = module.bigip1.*.f5_username
}
output "mgmtPort" {
  value = module.bigip1.*.mgmtPort
}
output "public_addresses" {
  value = module.bigip1.*.public_addresses
}
output "private_addresses" {
  value = module.bigip1.*.private_addresses
}
output "service_account" {
  value = module.bigip1.*.service_account
}
output "self_link" {
  value = module.bigip1.*.self_link
}
output "name" {
  value = module.bigip1.*.name
}
output "zone" {
  value = module.bigip1.*.zone
}
output "bigip_instance_ids" {
  value = module.bigip1.*.bigip_instance_ids
}

output "target_instance_id" {
   value = module.bigip1[0].target_instance_id
}


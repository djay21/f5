env                  = "common"
disk_encryption_key  = "common-kms-key"
f5_ext_vpc           = "common-ext-vpc"
f5_mgmt_vpc          = "common-mgn-vpc"
f5_int_vpc           = "common-int-vpc"
f5_health_check_port = "443"
f5_username          = "general_user"
region               = "asia-south1"
image = "projects/f5-7626-networks-public/global/images/f5-bigip-16-1-3-3-0-0-3-payg-good-25mbps-221222231809"
#image        = "projects/f5-7626-networks-public/global/images/f5-bigip-16-1-3-3-0-0-3-byol-all-modules-2boot-loc-21222235920"
machine_type = "n2-standard-4"
max_instance = 3
min_instance = 3
network_tags = ["extfw-f5", "egress-internet"]
disk_type    = "pd-balanced"
disk_size_gb = 200
f5_roles = [
  "compute.forwardingRules.get",
  "compute.forwardingRules.list",
  "compute.forwardingRules.setTarget",
  "compute.instances.create",
  "compute.instances.get",
  "compute.instances.list",
  "compute.instances.updateNetworkInterface",
  "compute.networks.updatePolicy",
  "compute.routes.create",
  "compute.routes.delete",
  "compute.routes.get",
  "compute.routes.list",
  "compute.targetInstances.get",
  "compute.targetInstances.list",
  "compute.targetInstances.use",
  "storage.buckets.create",
  "storage.buckets.delete",
  "storage.buckets.get",
  "storage.buckets.list",
  "storage.buckets.update",
  "storage.objects.create",
  "storage.objects.delete",
  "storage.objects.get",
  "storage.objects.list",
  "storage.objects.update",
  "cloudkms.cryptoKeyVersions.useToDecrypt",
  "cloudkms.cryptoKeyVersions.useToEncrypt",
  "cloudkms.locations.get",
  "cloudkms.locations.list",
  "resourcemanager.projects.get"
]

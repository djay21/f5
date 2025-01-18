region = "asia-south1"
zone="asia-south1-a"
prefix ="gadm"
image = "projects/f5-7626-networks-public/global/images/f5-bigip-16-1-3-1-0-0-11-payg-best-plus-25mbps-220721054250"
project_id="prj-glz-d-glz-restrict-9605"
f5_service_account = "servicef5"
instance_count = 1
machine_type = "n1-standard-4"
disk_type ="pd-ssd"
disk_size_gb = 100
f5_username = "admin"
#f5_password = ""
labels= { 
    owner    = "devops"
    org     = "admin"
    }

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
]

mgmt_restricted_ips = [
    "10.0.11.0/24",
    "49.36.237.46/32",
    "103.227.70.94/32",
    "103.240.233.25/32",
    "103.240.0.0/16",
    "103.252.0.0/16",
    "103.252.216.226"
  ]
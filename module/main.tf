terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.31.0"
    }
  }
}
#
# Create a random id
resource "random_id" "module_id" {
  byte_length = 2
}

locals {
  external_nic_count = length([for subnet in var.external_subnet_ids : subnet if subnet.subnet_id != null && subnet.subnet_id != ""]) == 0 ? 0 : 1
  internal_nic_count = length([for subnet in var.internal_subnet_ids : subnet if subnet.subnet_id != null && subnet.subnet_id != ""]) == 0 ? 0 : 1
  multiple_nic_count = local.external_nic_count + local.internal_nic_count
  instance_prefix    = format("%s-%s", var.prefix, random_id.module_id.hex)

  boot_disk = [
    {
      source_image = var.image
      disk_size_gb = var.disk_size_gb
      disk_type    = var.disk_type
      disk_labels  = var.disk_labels
      auto_delete  = var.auto_delete
      boot         = "true"
    },
  ]

  all_disks = concat(local.boot_disk, var.additional_disks)
}


resource "random_string" "password" {
  length      = 16
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  special     = false
}

resource "random_string" "sa_role" {
  length    = 16
  min_lower = 1
  numeric   = false
  upper     = false
  special   = false
}

data "google_secret_manager_secret_version" "secret" {
  count   = var.gcp_secret_manager_authentication ? 1 : 0
  secret  = var.gcp_secret_name
  version = var.gcp_secret_version
}

resource "google_project_iam_member" "gcp_role_member_assignment" {
  count   = var.gcp_secret_manager_authentication ? 1 : 0
  project = var.project_id
  role    = format("projects/${var.project_id}/roles/%s", random_string.sa_role.result)
  member  = "serviceAccount:${var.service_account}"
}

resource "google_project_iam_custom_role" "gcp_custom_roles" {
  count       = var.gcp_secret_manager_authentication ? 1 : 0
  role_id     = random_string.sa_role.result
  title       = random_string.sa_role.result
  description = "IAM for authentication"
  permissions = ["secretmanager.versions.access"]
}


resource "google_compute_address" "mgmt_public_ip" {
  count = length([for address in compact([for subnet in var.mgmt_subnet_ids : subnet.public_ip]) : address if address])
  name  = format("%s-mgmt-publicip-%s", var.prefix, random_id.module_id.hex)
}
resource "google_compute_address" "external_public_ip" {
  count = length([for address in compact([for subnet in var.external_subnet_ids : subnet.public_ip]) : address if address])
  name  = format("%s-ext-publicip-%s-%s", var.prefix, count.index, random_id.module_id.hex)
}


resource "google_compute_instance_template" "f5_vm" {
  name_prefix = var.vm_name == "" ? format("%s", local.instance_prefix) : var.vm_name
  # Scheduling options
  #min_cpu_platform = var.min_cpu_platform
  machine_type = var.machine_type
  scheduling {
    automatic_restart   = var.automatic_restart
    preemptible         = var.preemptible
    on_host_maintenance = "MIGRATE"
  }
  dynamic "disk" {
    for_each = local.all_disks
    content {
      auto_delete  = lookup(disk.value, "auto_delete", null)
      boot         = lookup(disk.value, "boot", null)
      device_name  = lookup(disk.value, "device_name", null)
      disk_name    = lookup(disk.value, "disk_name", null)
      disk_size_gb = lookup(disk.value, "disk_size_gb", lookup(disk.value, "disk_type", null) == "local-ssd" ? "375" : null)
      disk_type    = lookup(disk.value, "disk_type", null)
      interface    = lookup(disk.value, "interface", lookup(disk.value, "disk_type", null) == "local-ssd" ? "NVME" : null)
      mode         = lookup(disk.value, "mode", null)
      source       = lookup(disk.value, "source", null)
      source_image = lookup(disk.value, "source_image", null)
      type         = lookup(disk.value, "disk_type", null) == "local-ssd" ? "SCRATCH" : "PERSISTENT"
      labels       = lookup(disk.value, "disk_labels", null)

      dynamic "disk_encryption_key" {
        for_each = compact([var.disk_encryption_key == null ? null : 1])
        content {
          kms_key_self_link = var.disk_encryption_key
        }
      }
    }
  }
  service_account {
    email = var.service_account
    scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/pubsub",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
    "https://www.googleapis.com/auth/trace.append"]
  }
  can_ip_forward = true

  lifecycle {
    create_before_destroy = "true"
  }

  #Assign external Nic
  dynamic "network_interface" {
    for_each = [for subnet in var.external_subnet_ids : subnet if subnet.subnet_id != null && subnet.subnet_id != ""]
    content {
      subnetwork = network_interface.value.subnet_id
      network_ip = network_interface.value.private_ip_primary
      dynamic "access_config" {
        for_each = element(coalescelist(compact([network_interface.value.public_ip]), [false]), 0) ? [1] : []
        content {
          nat_ip = google_compute_address.external_public_ip[tonumber(network_interface.key)].address
        }
      }
      dynamic "alias_ip_range" {
        for_each = compact([network_interface.value.private_ip_secondary])
        content {
          ip_cidr_range = alias_ip_range.value
        }
      }
    }
  }


  #Assign to Management Nic
  dynamic "network_interface" {
    for_each = [for subnet in var.mgmt_subnet_ids : subnet if subnet.subnet_id != null && subnet.subnet_id != ""]
    content {
      subnetwork = network_interface.value.subnet_id
      network_ip = network_interface.value.private_ip_primary
      dynamic "access_config" {
        for_each = element(coalescelist(compact([network_interface.value.public_ip]), [false]), 0) ? [1] : []
        content {
          # nat_ip       = access_config.value.nat_ip
          network_tier = "PREMIUM"
        }
      }
    }
  }

  # Internal NIC
  dynamic "network_interface" {
    for_each = [for subnet in var.internal_subnet_ids : subnet if subnet.subnet_id != null && subnet.subnet_id != ""]
    content {
      subnetwork = network_interface.value.subnet_id
      network_ip = network_interface.value.private_ip_primary
      dynamic "access_config" {
        for_each = element(coalescelist(compact([network_interface.value.public_ip]), [false]), 0) ? [1] : []
        content {
          nat_ip = google_compute_address.internal_public_ip[tonumber(network_interface.key)].address
        }
      }
    }
  }
  ##
  metadata_startup_script = replace(coalesce(var.custom_user_data, templatefile("${path.module}/startup-script.tpl",
    {
      onboard_log                       = var.onboard_log
      libs_dir                          = var.libs_dir
      bigip_username                    = var.f5_username
      gcp_secret_manager_authentication = var.gcp_secret_manager_authentication
      bigip_password                    = (var.f5_password == "") ? (var.gcp_secret_manager_authentication ? var.gcp_secret_name : random_string.password.result) : var.f5_password
      ssh_keypair                       = file(var.f5_ssh_publickey)
      INIT_URL                          = var.INIT_URL,
      DO_URL                            = var.DO_URL,
      DO_VER                            = format("v%s", split("-", split("/", var.DO_URL)[length(split("/", var.DO_URL)) - 1])[3])
      AS3_URL                           = var.AS3_URL,
      AS3_VER                           = format("v%s", split("-", split("/", var.AS3_URL)[length(split("/", var.AS3_URL)) - 1])[2])
      TS_VER                            = format("v%s", split("-", split("/", var.TS_URL)[length(split("/", var.TS_URL)) - 1])[2])
      TS_URL                            = var.TS_URL,
      CFE_VER                           = format("v%s", split("-", split("/", var.CFE_URL)[length(split("/", var.CFE_URL)) - 1])[3])
      CFE_URL                           = var.CFE_URL,
      FAST_URL                          = var.FAST_URL
      FAST_VER                          = format("v%s", split("-", split("/", var.FAST_URL)[length(split("/", var.FAST_URL)) - 1])[3])
      NIC_COUNT                         = local.multiple_nic_count > 0 ? true : false
  })), "/\r/", "")

  metadata = merge(var.metadata, coalesce(var.f5_ssh_publickey, "unspecified") != "unspecified" ? {
    sshKeys = file(var.f5_ssh_publickey)
    } : {}
  )
  labels = var.labels

  tags = var.network_tags

}

resource "google_compute_region_autoscaler" "f5_autoscaler" {
  name   = "${var.prefix}-autoscaler-${substr(md5(google_compute_instance_template.f5_vm.name), 0, 3)}"
  region = var.region
  target = google_compute_region_instance_group_manager.mig.id

  autoscaling_policy {
    max_replicas    = var.max_instance
    min_replicas    = var.min_instance
    cooldown_period = 60

    cpu_utilization {
      target = 0.5
    }
  }
}


resource "google_compute_region_instance_group_manager" "mig" {
  depends_on = [
    google_compute_instance_template.f5_vm
  ]

  name                      = "${var.prefix}-${substr(md5(google_compute_instance_template.f5_vm.name), 0, 3)}-mig"
  region                    = var.region
  distribution_policy_zones = ["${var.region}-a", "${var.region}-b", "${var.region}-c"]

  version {
    instance_template = google_compute_instance_template.f5_vm.id
    name              = "primary"
  }
  base_instance_name = var.prefix
  target_size        = var.max_instance
  lifecycle {
    create_before_destroy = true
  }
}

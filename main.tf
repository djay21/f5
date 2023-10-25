

# Create a random id
resource "random_id" "id" {
  byte_length = 2
}

# Create random password for BIG-IP
resource "random_string" "password" {
  length      = 16
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  special     = false
}

########################################################################
#                     CUSTOM  SERVICE ACCOUNT                                           #
########################################################################
resource "google_service_account" "f5_sa" {
  account_id   = "${local.base_name}-sa"
  display_name = "Custom Service Account for F5 Resource"
}

resource "google_project_iam_custom_role" "f5_role" {
  role_id     = replace("${local.base_name}_role", "-", "_")
  title       = "f5 WAF Role"
  permissions = var.f5_roles
}
resource "google_project_iam_member" "admin-account-iam" {
  project = local.lz_project_id
  role    = google_project_iam_custom_role.f5_role.id
  member  = "serviceAccount:${google_service_account.f5_sa.email}"
  depends_on = [
    google_service_account.f5_sa
  ]
}

########################################################################
#                       F5 Instance Creation                                    #
########################################################################


module "bigip" {
  source              = "./modules/f5"
  prefix              = local.base_name
  project_id          = local.lz_project_id
  image               = var.image
  f5_username         = var.f5_username
  f5_password         = random_string.password.result
  f5_ssh_publickey    = var.f5_ssh_publickey
  machine_type        = var.machine_type
  max_instance        = var.max_instance
  min_instance        = var.min_instance
  disk_size_gb        = var.disk_size_gb
  disk_encryption_key = local.disk_encryption_key
  service_account     = google_service_account.f5_sa.email
  network_tags        = var.network_tags
  mgmt_subnet_ids     = [{ "subnet_id" = data.google_compute_subnetwork.f5_mgmt_subnetwork.id, "public_ip" = false, "private_ip_primary" = "" }]
  external_subnet_ids = [{ "subnet_id" = data.google_compute_subnetwork.f5_ext_subnetwork.id, "public_ip" = false, "private_ip_primary" = "", "private_ip_secondary" = "" }]
  internal_subnet_ids = [{ "subnet_id" = data.google_compute_subnetwork.f5_int_subnetwork.id, "public_ip" = false, "private_ip_primary" = "", "private_ip_secondary" = "" }]
}








########################################################################
#                        FIREWALL                                      #
########################################################################

# resource "google_compute_firewall" "f5_mgmt_firewall_private" {
#   name    = "${local.base_name}-mgmt-ingress-fw"
#   network = data.google_compute_network.f5_mgmt_vpc.id
#   allow {
#     protocol = "all"
#   }
#   source_ranges = ["${data.google_compute_subnetwork.f5_mgmt_subnetwork.ip_cidr_range}"]
# }

# resource "google_compute_firewall" "f5_ext_private" {
#   name    = "${local.base_name}-ext-ingress-fw"
#   network = data.google_compute_network.f5_ext_vpc.id
#   allow {
#     protocol = "all"
#   }
#   source_ranges = ["${data.google_compute_subnetwork.f5_ext_subnetwork.ip_cidr_range}"]
# }

# resource "google_compute_firewall" "f5_ext_private_egress" {
#   name      = "${local.base_name}-ext-egress-fw"
#   network   = data.google_compute_network.f5_ext_vpc.id
#   direction = "EGRESS"
#   allow {
#     protocol = "all"
#   }
#   destination_ranges = ["${data.google_compute_subnetwork.f5_ext_subnetwork.ip_cidr_range}"]
# }

# resource "google_compute_firewall" "f5_int_private_egress" {
#   name      = "${local.base_name}-int-egress-fw"
#   network   = data.google_compute_network.f5_int_vpc.id
#   direction = "EGRESS"
#   allow {
#     protocol = "all"
#   }
#   destination_ranges = ["${data.google_compute_subnetwork.f5_int_subnetwork.ip_cidr_range}"]
# }

# resource "google_compute_firewall" "f5_int_private" {
#   name    = "${local.base_name}-int-ingress-fw"
#   network = data.google_compute_network.f5_int_vpc.id
#   allow {
#     protocol = "all"
#   }
#   source_ranges = ["${data.google_compute_subnetwork.f5_int_subnetwork.ip_cidr_range}"]
# }

# resource "google_compute_firewall" "f5_ext_restricted" {
#   name = "${local.base_name}-external-nic-mirroring-f5-fw"
#   source_tags = [
#     "extfw-f5"
#   ]
#   target_tags = [
#     "extfw-f5"
#   ]
#   network = data.google_compute_network.f5_ext_vpc.id
#   allow {
#     protocol = "TCP"
#     ports    = [4353]
#   }
#   allow {
#     protocol = "UDP"
#     ports    = [1026]
#   }
# }

# resource "google_compute_firewall" "f5_int_restricted" {
#   name = "${local.base_name}-internal-nic-mirroring-f5-fw"
#   source_tags = [
#     "extfw-f5"
#   ]
#   target_tags = [
#     "extfw-f5"
#   ]
#   network = data.google_compute_network.f5_int_vpc.id
#   allow {
#     protocol = "TCP"
#     ports    = [4353]
#   }
#   allow {
#     protocol = "UDP"
#     ports    = [1026]
#   }
# }
# #****
# resource "google_compute_firewall" "mgmt_firewall" {
#   name    = "${local.base_name}-mgmt-console-allow-access-fw"
#   network = data.google_compute_network.f5_mgmt_vpc.id
#   allow {
#     protocol = "tcp"
#     ports    = ["22", "80", "443", "8443"]
#   }
#   allow {
#     protocol = "icmp"
#   }
#   source_ranges = var.mgmt_restricted_ips
# }
# resource "google_compute_firewall" "ext_firewall" {
#   name    = "${local.base_name}-external-fw"
#   network = data.google_compute_network.f5_ext_vpc.id
#   allow {
#     protocol = "tcp"
#     ports    = ["22", "80", "443", "8443"]
#   }
#   allow {
#     protocol = "icmp"
#   }
#   source_ranges = var.mgmt_restricted_ips
# }

# resource "google_compute_firewall" "lb_health_probe_firewall" {
#   name    = "${local.base_name}-lb-healthprobe-fw"
#   network = data.google_compute_network.f5_ext_vpc.id
#   allow {
#     protocol = "all"
#   }
#   source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
# }



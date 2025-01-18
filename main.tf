terraform {
  required_version = ">= 0.13"
}
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Create a random id
#
resource "random_id" "id" {
  byte_length = 2
}

# Create random password for BIG-IP
#
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
  account_id    = var.f5_service_account
  display_name = "Custom Service Account for F5 Resource"
}

resource "google_project_iam_custom_role" "f5_role" {
  role_id     = "${var.f5_service_account}_role"
  title       = "f5 Role"
  permissions = var.f5_roles
}
resource "google_project_iam_member" "admin-account-iam" {
  project = var.project_id
  role    = google_project_iam_custom_role.f5_role.id
  member  = "serviceAccount:${google_service_account.f5_sa.email}"
  depends_on = [
    google_service_account.f5_sa
  ]
}

########################################################################
#                        VPC                                           #
########################################################################

resource "google_compute_network" "f5_mgmt_vpc" {
  name                    = format("%s-mgmt-%s", var.prefix, random_id.id.hex)
  auto_create_subnetworks = false
}
resource "google_compute_network" "f5_ext_vpc" {
  name                    = format("%s-ext-%s", var.prefix, random_id.id.hex)
  auto_create_subnetworks = false
}
resource "google_compute_network" "f5_int_vpc" {
  name                    = format("%s-int-%s", var.prefix, random_id.id.hex)
  auto_create_subnetworks = false
}


########################################################################
#                        SUBNETWORK                                    #
########################################################################

resource "google_compute_subnetwork" "f5_mgmt_subnetwork" {
  name          = format("%s-mgmt-%s", var.prefix, random_id.id.hex)
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.f5_mgmt_vpc.id
}
resource "google_compute_subnetwork" "f5_ext_subnetwork" {
  name          = format("%s-ext-%s", var.prefix, random_id.id.hex)
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.f5_ext_vpc.id
}
resource "google_compute_subnetwork" "f5_int_subnetwork" {
  name          = format("%s-int-%s", var.prefix, random_id.id.hex)
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.f5_int_vpc.id
}
####

########################################################################
#                        FIREWALL                                      #
########################################################################

resource "google_compute_firewall" "f5_mgmt_firewall_private" {
  name    = format("%s-mgmt-firewall-custom-self-%s", var.prefix, random_id.id.hex)
  network = google_compute_network.f5_mgmt_vpc.id
  allow {
    protocol = "all"
  }
  source_ranges = ["${google_compute_subnetwork.f5_mgmt_subnetwork.ip_cidr_range}"]
}

resource "google_compute_firewall" "f5_ext_private" {
  name    = format("%s-ext-firewall-custom-self-%s", var.prefix, random_id.id.hex)
  network = google_compute_network.f5_ext_vpc.id
  allow {
    protocol = "all"
  }
  source_ranges = ["${google_compute_subnetwork.f5_ext_subnetwork.ip_cidr_range}"]
}
resource "google_compute_firewall" "f5_int_private" {
  name    = format("%s-int-firewall-custom-self-%s", var.prefix, random_id.id.hex)
  network = google_compute_network.f5_int_vpc.id
  allow {
    protocol = "all"
  }
  source_ranges = ["${google_compute_subnetwork.f5_int_subnetwork.ip_cidr_range}"]
}

resource "google_compute_firewall" "f5_ext_restricted" {
  name = "extfirewall-${var.prefix}"
  source_tags = [
    "extfw-${var.prefix}"
  ]
  target_tags = [
    "extfw-${var.prefix}"
  ]
  network = google_compute_network.f5_ext_vpc.id
  allow {
    protocol = "TCP"
    ports = [4353]
  }
  allow {
    protocol = "UDP"
    ports = [1026]
  }
}

resource "google_compute_firewall" "f5_int_restricted" {
  name = "intfirewall-${var.prefix}"
  source_tags = [
    "extfw-${var.prefix}"
  ]
  target_tags = [
    "extfw-${var.prefix}"
  ]
  network = google_compute_network.f5_int_vpc.id
  allow {
    protocol = "TCP"
    ports = [4353]
  }
  allow {
    protocol = "UDP"
    ports = [1026]
  }
}
#****
resource "google_compute_firewall" "mgmt_firewall" {
  name    = format("%s-mgmt-firewall-%s", var.prefix, random_id.id.hex)
  network = google_compute_network.f5_mgmt_vpc.id
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8443"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = var.mgmt_restricted_ips
}
resource "google_compute_firewall" "ext_firewall" {
  name    = format("%s-ext-firewall-%s", var.prefix, random_id.id.hex)
  network = google_compute_network.f5_ext_vpc.id
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8443"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = var.mgmt_restricted_ips
}

module "bigip1" {
  count               = var.instance_count
  source              = "../.."
  prefix              = format("%s-3nic-1", var.prefix)
  project_id          = var.project_id
  # region              = var.region
  zone                = var.zone
  image               = var.image
  f5_username         = var.f5_username
  f5_password         = "helloworld@123"
  machine_type        = var.machine_type
  disk_size_gb        = var.disk_size_gb
  service_account     = google_service_account.f5_sa.email
  network_tags        = ["extfw-${var.prefix}"]
  mgmt_subnet_ids     = [{ "subnet_id" = google_compute_subnetwork.f5_mgmt_subnetwork.id, "public_ip" = true, "private_ip_primary" = "" }]
  external_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.f5_ext_subnetwork.id, "public_ip" = true, "private_ip_primary" = "", "private_ip_secondary" = "10.0.1.240/32" }]
  internal_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.f5_int_subnetwork.id, "public_ip" = false, "private_ip_primary" = "", "private_ip_secondary" = "10.0.2.240/32" }]
}


module "bigip2" {
  count               = var.instance_count
  source              = "../.."
  prefix              = format("%s-3nic-2", var.prefix)
  project_id          = var.project_id
  # region              = var.region
  zone                = var.zone
  image               = var.image
  f5_username         = var.f5_username
  f5_password         = "helloworld@123"
  machine_type        = var.machine_type
  disk_size_gb        = var.disk_size_gb
  service_account     = google_service_account.f5_sa.email
  network_tags        = ["extfw-${var.prefix}"]
  mgmt_subnet_ids     = [{ "subnet_id" = google_compute_subnetwork.f5_mgmt_subnetwork.id, "public_ip" = true, "private_ip_primary" = "" }]
  external_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.f5_ext_subnetwork.id, "public_ip" = true, "private_ip_primary" = "", "private_ip_secondary" = "10.0.1.242/32" }]
  internal_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.f5_int_subnetwork.id, "public_ip" = false, "private_ip_primary" = "", "private_ip_secondary" = "10.0.2.242/32" }]
}
module "bigip3" {
  count               = var.instance_count
  source              = "../.."
  prefix              = format("%s-3nic-3", var.prefix)
  project_id          = var.project_id
  # region              = var.region
  zone                = var.zone
  image               = var.image
  f5_username         = var.f5_username
  f5_password         = "helloworld@123"
  machine_type        = var.machine_type
  disk_size_gb        = var.disk_size_gb
  service_account     = google_service_account.f5_sa.email
  network_tags        = ["extfw-${var.prefix}"]
  mgmt_subnet_ids     = [{ "subnet_id" = google_compute_subnetwork.f5_mgmt_subnetwork.id, "public_ip" = true, "private_ip_primary" = "" }]
  external_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.f5_ext_subnetwork.id, "public_ip" = true, "private_ip_primary" = "", "private_ip_secondary" = "10.0.1.244/32" }]
  internal_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.f5_int_subnetwork.id, "public_ip" = false, "private_ip_primary" = "", "private_ip_secondary" = "10.0.2.244/32" }]
}

resource "google_compute_forwarding_rule" "starter_f7_fr0" {
  name = "${var.prefix}-f5-fr0"
  ip_protocol = "TCP"
  load_balancing_scheme = "EXTERNAL"
  region = var.region
  target = module.bigip1[0].target_instance_id

  depends_on = [
   module.bigip1
  ]
}



# resource "google_compute_instance_group" "webservers" {
#   name        = "f5-instance-group"
#   description = "Terraform test instance group"

#   instances = [
#     module.bigip1[0].target_instance_id,
#      module.bigip2[0].target_instance_id,
#       module.bigip3[0].target_instance_id
#   ]
#   zone = var.zone
# }
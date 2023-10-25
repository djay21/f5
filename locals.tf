locals {
  base_name           = "${var.env}-${data.terraform_remote_state.lz.outputs.restricted_shared_vpc_project_name}-f5"
  lz_project_id       = data.terraform_remote_state.lz.outputs.restricted_shared_vpc_project_id
  disk_encryption_key = data.google_kms_crypto_key.lz-key.id
  org_secrets_project = data.terraform_remote_state.org.outputs.org_secrets_project_id
  internal_dev_vip    = "0.0.0.31"
  internal_uat_vip    = "0.0.0.41"
  internal_prod_vip   = "0.0.0.42"
  internal_cert_vip   = "0.0.0.43"
  internal_dev_vip_m  = "0.0.0.44"
  internal_uat_vip_m  = "0.0.0.45"
  internal_prod_vip_m = "0.0.0.46"
  internal_cert_vip_m = "0.0.0.47"
}

data "google_kms_key_ring" "lz-keyring" {
  provider = google.secret-project
  name     = "${var.disk_encryption_key}ring"
  location = var.region
}

data "google_kms_crypto_key" "lz-key" {
  provider = google.secret-project
  name     = var.disk_encryption_key
  key_ring = data.google_kms_key_ring.lz-keyring.id
}

########################################################################
#                        VPC                                           #
########################################################################
data "google_compute_network" "f5_ext_vpc" {
  name = var.f5_ext_vpc
}

data "google_compute_network" "f5_mgmt_vpc" {
  name = var.f5_mgmt_vpc
}

data "google_compute_network" "f5_int_vpc" {
  name = var.f5_int_vpc
}

########################################################################
#                        SUBNETWORK                                    #
########################################################################
data "google_compute_subnetwork" "f5_ext_subnetwork" {
  name = "common-ext-sb"
}

data "google_compute_subnetwork" "f5_mgmt_subnetwork" {
  name = "common-mgn-sb"
}

data "google_compute_subnetwork" "f5_int_subnetwork" {
  name = "common-int-sb"
}

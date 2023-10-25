
resource "google_compute_region_health_check" "f5_http" {
  name   = "${local.base_name}-hc"
  region = var.region
  https_health_check {
    port = "443"
  }
  log_config {
    enable = true
  }
}

resource "google_compute_region_backend_service" "default" {
  name                            = "${local.base_name}-tcp-int-lb"
  region                          = var.region
  protocol                        = "TCP"
  load_balancing_scheme           = "INTERNAL"
  connection_draining_timeout_sec = 300
  timeout_sec                     = 300
  health_checks                   = [google_compute_region_health_check.f5_http.id]
  session_affinity                = "CLIENT_IP_PORT_PROTO"
  backend {
    group          = module.bigip.*.mig_id[0]
    balancing_mode = "CONNECTION"
  }
  log_config {
    enable      = true
    sample_rate = 1
  }
}

######################## F5 VIP COMPUTE ADDRESSES  ###########################

resource "google_compute_address" "internal_dev_vip" {
  name         = "${local.base_name}-static-dev-vip-ip"
  subnetwork   = data.google_compute_subnetwork.f5_ext_subnetwork.id
  address_type = "INTERNAL"
  address      = local.internal_dev_vip
}

resource "google_compute_address" "internal_uat_vip" {
  name         = "${local.base_name}-static-uat-vip-ip"
  subnetwork   = data.google_compute_subnetwork.f5_ext_subnetwork.id
  address_type = "INTERNAL"
  address      = local.internal_uat_vip
}

resource "google_compute_address" "internal_cert_vip" {
  name         = "${local.base_name}-static-cert-vip-ip"
  subnetwork   = data.google_compute_subnetwork.f5_ext_subnetwork.id
  address_type = "INTERNAL"
  address      = local.internal_cert_vip
}

resource "google_compute_address" "internal_prod_vip" {
  name         = "${local.base_name}-static-prod-vip-ip"
  subnetwork   = data.google_compute_subnetwork.f5_ext_subnetwork.id
  address_type = "INTERNAL"
  address      = local.internal_prod_vip
}

############################### F5 Merchant Compute Addresses ################
resource "google_compute_address" "internal_dev_vip_m" {
  name         = "${local.base_name}-m-static-dev-vip-ip"
  subnetwork   = data.google_compute_subnetwork.f5_ext_subnetwork.id
  address_type = "INTERNAL"
  address      = local.internal_dev_vip_m
}

resource "google_compute_address" "internal_uat_vip_m" {
  name         = "${local.base_name}-m-static-uat-vip-ip"
  subnetwork   = data.google_compute_subnetwork.f5_ext_subnetwork.id
  address_type = "INTERNAL"
  address      = local.internal_uat_vip_m
}

resource "google_compute_address" "internal_cert_vip_m" {
  name         = "${local.base_name}-m-static-cert-vip-ip"
  subnetwork   = data.google_compute_subnetwork.f5_ext_subnetwork.id
  address_type = "INTERNAL"
  address      = local.internal_cert_vip_m
}

resource "google_compute_address" "internal_prod_vip_m" {
  name         = "${local.base_name}-m-static-prod-vip-ip"
  subnetwork   = data.google_compute_subnetwork.f5_ext_subnetwork.id
  address_type = "INTERNAL"
  address      = local.internal_prod_vip_m
}

###############################  F5 Frontend LB #######################

resource "google_compute_forwarding_rule" "f5_dev_frontend" {
  name                  = "${local.base_name}-tcp-int-dev-vip"
  backend_service       = google_compute_region_backend_service.default.id
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL"
  ports                 = ["443"]
  allow_global_access   = false
  network               = data.google_compute_network.f5_ext_vpc.id
  subnetwork            = data.google_compute_subnetwork.f5_ext_subnetwork.id
  ip_address            = google_compute_address.internal_dev_vip.id
}

resource "google_compute_forwarding_rule" "f5_uat_frontend" {
  name                  = "${local.base_name}-tcp-int-uat-vip"
  backend_service       = google_compute_region_backend_service.default.id
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL"
  ports                 = ["443"]
  allow_global_access   = false
  network               = data.google_compute_network.f5_ext_vpc.id
  subnetwork            = data.google_compute_subnetwork.f5_ext_subnetwork.id
  ip_address            = google_compute_address.internal_uat_vip.id
}

resource "google_compute_forwarding_rule" "f5_cert_frontend" {
  name                  = "${local.base_name}-tcp-int-cert-vip"
  backend_service       = google_compute_region_backend_service.default.id
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL"
  ports                 = ["443"]
  allow_global_access   = false
  network               = data.google_compute_network.f5_ext_vpc.id
  subnetwork            = data.google_compute_subnetwork.f5_ext_subnetwork.id
  ip_address            = google_compute_address.internal_cert_vip.id
}

resource "google_compute_forwarding_rule" "f5_prod_frontend" {
  name                  = "${local.base_name}-tcp-int-prod-vip"
  backend_service       = google_compute_region_backend_service.default.id
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL"
  ports                 = ["443"]
  allow_global_access   = false
  network               = data.google_compute_network.f5_ext_vpc.id
  subnetwork            = data.google_compute_subnetwork.f5_ext_subnetwork.id
  ip_address            = google_compute_address.internal_prod_vip.id
}


############################################# F5 LB Merchant ########################

resource "google_compute_forwarding_rule" "f5_dev_frontend_m" {
  name                  = "${local.base_name}-m-tcp-int-dev-vip"
  backend_service       = google_compute_region_backend_service.default.id
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL"
  ports                 = ["443"]
  allow_global_access   = false
  network               = data.google_compute_network.f5_ext_vpc.id
  subnetwork            = data.google_compute_subnetwork.f5_ext_subnetwork.id
  ip_address            = google_compute_address.internal_dev_vip_m.id
}

resource "google_compute_forwarding_rule" "f5_uat_frontend_m" {
  name                  = "${local.base_name}-m-tcp-int-uat-vip"
  backend_service       = google_compute_region_backend_service.default.id
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL"
  ports                 = ["443"]
  allow_global_access   = false
  network               = data.google_compute_network.f5_ext_vpc.id
  subnetwork            = data.google_compute_subnetwork.f5_ext_subnetwork.id
  ip_address            = google_compute_address.internal_uat_vip_m.id
}

resource "google_compute_forwarding_rule" "f5_cert_frontend_m" {
  name                  = "${local.base_name}-m-tcp-int-cert-vip"
  backend_service       = google_compute_region_backend_service.default.id
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL"
  ports                 = ["443"]
  allow_global_access   = false
  network               = data.google_compute_network.f5_ext_vpc.id
  subnetwork            = data.google_compute_subnetwork.f5_ext_subnetwork.id
  ip_address            = google_compute_address.internal_cert_vip_m.id
}

resource "google_compute_forwarding_rule" "f5_prod_frontend_m" {
  name = "${local.base_name}-m-tcp-int-prod-vip"
  backend_service       = google_compute_region_backend_service.default.id
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL"
  ports               = ["443"]
  allow_global_access = false
  network    = data.google_compute_network.f5_ext_vpc.id
  subnetwork = data.google_compute_subnetwork.f5_ext_subnetwork.id
  ip_address = google_compute_address.internal_prod_vip_m.id
}

provider "google" {
  alias   = "impersonate"
  project = data.terraform_remote_state.lz.outputs.restricted_shared_vpc_project_id
  region  = var.region

  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/userinfo.email",
  ]
}

provider "google" {
  alias   = "secret-project"
  project = local.org_secrets_project
}

data "google_service_account_access_token" "default" {
  provider               = google.impersonate
  target_service_account = data.terraform_remote_state.bootstrap.outputs.terraform_service_account
  scopes                 = ["userinfo-email", "cloud-platform"]
  lifetime               = "1200s"
}

/******************************************
  Provider credential configuration
 *****************************************/
provider "google" {
  access_token    = data.google_service_account_access_token.default.access_token
  request_timeout = "60s"
  project         = data.terraform_remote_state.lz.outputs.restricted_shared_vpc_project_id
  region          = var.region

}

provider "google-beta" {
  access_token    = data.google_service_account_access_token.default.access_token
  request_timeout = "60s"
}

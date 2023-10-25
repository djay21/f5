data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config = {
    bucket = "abc-bucket"
    prefix = "0-bootstrap/"
  }
}

data "terraform_remote_state" "lz" {
  backend = "gcs"
  config = {
    bucket = "abc-bucket"
    prefix = "lz/"
  }
}

data "terraform_remote_state" "org" {
  backend = "gcs"
  config = {
    bucket = "abc-bucket"
    prefix = "1-org/"
  }
}

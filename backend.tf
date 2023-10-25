terraform {
  backend "gcs" {
    bucket = "abc-bucket"
    prefix = "f5/"
  }
}

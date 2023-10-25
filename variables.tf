variable "env" {}

variable "disk_size_gb" {}

variable "disk_encryption_key" {
  description = "The id of the encryption key that is stored in Google Cloud KMS to use to encrypt all the disks on this instance"
  type        = string
  default     = ""
}

variable "f5_ext_vpc" {}

variable "f5_int_vpc" {}

variable "f5_mgmt_vpc" {}

variable "f5_password" {
  description = "The admin password of the F5 Bigip that will be deployed"
  default     = ""
}

variable "f5_roles" {
  type    = list(any)
  default = null
}

variable "f5_username" {}

variable "image" {
  type        = string
  default     = "projects/f5-7626-networks-public/global/images/f5-bigip-16-1-2-2-0-0-28-payg-best-plus-25mbps-220505080809"
  description = "The self-link URI for a BIG-IP image to use as a base for the VM cluster.This can be an official F5 image from GCP Marketplace, or a customised image."
}

variable "labels" {
  description = "An optional map of key:value labels to add to the instance"
  type        = map(string)
  default     = {}
}

variable "machine_type" {}

variable "max_instance" {}

variable "min_instance" {}

variable "network_tags" {
  type        = list(string)
  default     = []
  description = "The network tags which will be added to the BIG-IP VMs"
}

variable "prefix" {
  description = "Prefix for resources created by this module"
  type        = string
  default     = "f5-sec"
}

variable "region" {
  type        = string
  description = "The compute region which will host the BIG-IP VMs"
}

variable "f5_ssh_publickey" {
  description = "Path to the public key to be used for ssh access to the VM.  Only used with non-Windows vms and can be left as-is even if using Windows vms. If specifying a path to a certification on a Windows machine to provision a linux vm use the / in the path versus backslash. e.g. c:/home/id_rsa.pub"
  default     = "./id_rsa.pub"
}



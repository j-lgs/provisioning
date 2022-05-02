variable "environment" {
  description = "Choice of test|prod"
  type = string
  default = "prod"
}

variable "proxmox_nodes" {
  description = "a List of all proxmox nodes"
  type = map(object({templates=string, containers=string, ip=string, root_password=string}))
  default = {}
}


variable "registry_vmid" {
  description = "Proxmox VMID for registry container"
  type = number
  default = 100
}

variable "registry_hostname" {
  description = "Hostname for the pull through image cache container."
  type = string
  default = "registry"
}

variable "registry_template" {
  description = "LXC template for the pull through image cache container."
  type = string
  default = "ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
}


variable "registry_size" {
  description = "size of the registry's rootfs."
  type = string
  default = "64G"
}

variable "registry_cidr" {
  description = "IP and CIDR for the registry container."
  type = string
}

variable "registry_cores" {
  description = "Amount of cores to give to the registry container."
  type = number
  default = 2
}

variable "gateway" {
  description = "IP address of local network's gateway."
  type = string
}


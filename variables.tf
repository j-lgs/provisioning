variable "pm_api_url" {
  description = "Url for connecting to the Proxmox API. in the form of https://$PROXMOX_IP:8006/api2/json"
  type = string
}

variable "environment" {
  type = string
}

variable "worker_vmid_base" {
}

variable "worker_nodes" {}

variable "control_vmid_base" {}
variable "control_nodes" {}

variable "proxmox_nodes" {}

variable "gateway" {}

variable "nfs_cidr" {}
variable "nfs_mounts" {}
variable "nfs_vmid" {}
variable "nfs_hostname" {}
variable "nfs_node" {}

variable "registry_cidr" {}
variable "registry_size" {}
variable "registry_vmid" {}
variable "registry_hostname" {}

variable "hastate" {}
variable "peers" {}
variable "nameserver" {}
variable "apiproxy_ip" {}
variable "wireguard_cidr" {}
variable "talos_cluster_name" {}
variable "ingress_ip" {}
variable "cluster_name" {}
variable "endpoints" {}

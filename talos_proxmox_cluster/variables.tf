variable "proxmox_nodes" {
  description = "a List of objects representing Proxmox nodes and specific configuration."
  type = map(object({isos=string, vm_images=string, data_images=string, ip=string, root_password=string}))
  default = {}
}

variable "environment" {
  description = "Choice of test|prod"
  type = string
  default = "prod"
}

variable "talos_iso" {
  description = "The location of the talos iso in the target Proxmox \"datacenter\"."
  type = string
  default = "talos-amd64.iso"
}

variable "worker_vmid_base" {
  description = "Base proxmox vmid used in the instantiation of worker VMs."
  type = number
  default = 300
}

variable "control_vmid_base" {
  description = "Base proxmox vmid used in the instantiation of controlplane VMs."
  type = number
  default = 200
}

variable "worker_nodes" {
  description = "Map of worker nodes."
  type = map(object({i=number, node=string, cores=number, memory=number, bootsize=string, datasize=string, ip=string, pcid=string, mdev=string}))
}

variable "control_nodes" {
  description = "Map of controlplane nodes."
  type = map(object({i=number, node=string, cores=number, memory=number, bootsize=string, ip=string, wg_ip=string}))
}

variable "cluster_name" {
  description = "Name of the kubernetes cluster"
  type = string
  default = "kubes"
}

variable "mac_prefix" {
  description = "MAC address prefix for VMs"
  type = list(number)
  default = [232, 10, 208]
}

variable "registry_ip" {
  description = "IP address of container registry cache."
  type = string
}

variable "gateway" {
  description = "IP address of local network's gateway."
  type = string
}

variable "is_sensitive" {
  description = "Dummy variable to suppress command output of generate patches."
  type = string
  sensitive = true
  default = ""
}


variable "hastate" {}
variable "peers" {}
variable "nameserver" {}
variable "apiproxy_ip" {}
variable "wireguard_cidr" {}
variable "talos_cluster_name" {}
variable "ingress_ip" {}
variable "endpoints" {}

variable "pm_api_url" {
  description = "Url for connecting to the Proxmox API."
  type = string
  default = "https://proxmox.lan:8006/api2/json"
}

variable "talos_iso" {
  description = "The location of the talos iso in the target Proxmox \"datacenter\"."
  type = string
  default = "local-zfs:iso/talos-1.0-amd64.iso"
}

variable "boot_storage" {
  description = "Proxmox storage location for VM boot disks."
  type = string
  default = "local-zfs"
}

variable "data_storage" {
  description = "Proxmox storage location for worker VM data disks."
  type = string
  default = "local-zfs"
}

variable "target_node" {
  description = "Proxmox node that the VMs will be deployed to."
  type = string
  default = "node"
}

variable "control_vmid_base" {
  description = "Base proxmox vmid used in the instantiation of controlplane VMs."
  type = number
  default = 200
}

variable "control_nodes" {
  description = "Map of controlplane nodes."
  type = map
  default = {
    "cluster-control-1"={idx=0, mac="replace me", cores=2, memory=2048, bootsize="64G"}
  }
}

variable "worker_vmid_base" {
  description = "Base proxmox vmid used in the instantiation of worker VMs."
  type = number
  default = 100
}

variable "worker_nodes" {
  description = "Map of worker nodes."
  type = map
  default = {
    "cluster-worker-1"={idx=0, mac="replace me", cores=2, memory=2048, bootsize="64G", datasize="64G"}
  }
}

variable "registry_hostname" {
  description = "Hostname for the pull through image cache container."
  type = string
  default = "registry"
}

variable "registry_template" {
  description = "LXC template for the pull through image cache container."
  type = string
}

variable "registry_password" {
  description = "Password for the pull through image cache container."
  type = string
  sensitive = true
}

variable "container_boot_storage" {
  description = "Storage location for containers."
  type = string
  default = "local-zfs"
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

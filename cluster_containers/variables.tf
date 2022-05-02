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

variable "nfs_template" {
  description = "LXC template for the nfs server container."
  type = string
  default = "ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
}

variable "nfs_cores" {
  description = "Amount of cores to give to the NFS server container."
  type = number
  default = 2
}

variable "nfs_size" {
  description = "Size for the NFS server's rootfs."
  type = string
  default = "4G"
}

variable "nfs_node" {
  description = "Proxmox node that contains the ZFS storage that the nfs container will share."
  type = string
}

variable "nfs_hostname" {
  description = "hostname for nfs container"
  type = string
  default = "nfs"
}

variable "nfs_vmid" {
  description = "unique vmid for nfs container"
  type = number
}

variable "nfs_cidr" {
  description = "ip address and subnet for the nfs container's main network interface"
  type = string
}

variable "nfs_mounts" {
  description = "Array of objects depicting NFS mounts. Consists of host filesystem paths and backing store size."
  type = list(object({path=string, size=string}))
}

variable "gateway" {
  description = "IP address of local network's gateway."
  type = string
}


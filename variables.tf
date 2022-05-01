variable "pm_api_url" {
  description = "Url for connecting to the Proxmox API."
  type = string
  default = "https://proxmox.lan:8006/api2/json"
}

variable "pcie_id" {
  description = "Map of worker vm names to pcie IDs and MDEVs for gpu passthrough worker VMs."
}

variable "connections" {
  description = "Map of proxmox hosts to ip addresses and passwords for root ssh authentication."
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

variable "mac_prefix" {
  description = "MAC address prefix for VMs"
}

variable "data_storage" {
  description = "Proxmox storage location for worker VM data disks."
  type = string
  default = "local-zfs"
}

variable "ct_target_node" {
  description = "Proxmox node that the Ubtuntu LXC container will be deployed to."
  type = string
  default = "pve"
}

variable "target_node_ip" {
  description = "Should match the ip that one of the control_nodes will have once running. Used for bootstrapping the cluster."
  type = string
  default = ""
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
  default = 300
}

variable "worker_nodes" {
  description = "Map of worker nodes."
  type = map
  default = {
    "cluster-worker-1"={idx=0, mac="replace me", cores=2, memory=2048, bootsize="64G", datasize="64G"}
  }
}

variable "nfs_hostname" {
  description = "Hostname for the NFS server that shares ZFS datasets to containers."
  type = string
  default = "nfs"
}

variable "nfs_node" {
  description = "Proxmox node the NFS server is hosted"
  type = string
  default = "pve"
}

variable "nfs_template" {
  description = "Proxmox container template that the NFS server will run on."
  type = string
}

variable "nfs_root_storage" {
  description = "Proxmox storage location for the NFS container's rootfs"
  type = string
}

variable "nfs_rootsize" {
  description = "size of the NFS container's rootfs"
  type = string
  default = "4G"
}

variable "nfs_ip_cidr" {
  description = "The IP address for the NFS Container"
  type = string
}

variable "nfs_mountpoints" {
  description = "a list of NFS Mountpoints"
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

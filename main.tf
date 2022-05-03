terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "2.9.7"
    }
    macaddress = {
      source = "ivoronin/macaddress"
      version = "0.3.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

provider "kubectl" {
  load_config_file = true
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "proxmox" {
  pm_api_url = var.pm_api_url
}

module "cluster_containers" {
  source = "./cluster_containers"

  proxmox_nodes = var.proxmox_nodes
  
  registry_hostname = var.registry_hostname
  registry_vmid = var.registry_vmid
  registry_size = var.registry_size
  registry_cidr = var.registry_cidr

  nfs_node      = var.nfs_node
  nfs_hostname  = var.nfs_hostname
  nfs_vmid      = var.nfs_vmid
  nfs_mounts    = var.nfs_mounts
  nfs_cidr      = var.nfs_cidr

  gateway = var.gateway
  environment = var.environment
}

module "talos_proxmox_cluster" {
  source = "./talos_proxmox_cluster"

  proxmox_nodes = var.proxmox_nodes

  control_vmid_base = var.control_vmid_base
  control_nodes = var.control_nodes

  worker_vmid_base = var.worker_vmid_base
  worker_nodes = var.worker_nodes

  registry_ip = module.cluster_containers.registry_ip

  environment = var.environment

  cluster_name = var.cluster_name
  endpoints = var.endpoints

  gateway     = var.gateway
  nameserver  = var.nameserver
  apiproxy_ip = var.apiproxy_ip
  wireguard_cidr = var.wireguard_cidr
  talos_cluster_name = var.talos_cluster_name
  ingress_ip = var.ingress_ip

  peers   = var.peers
  hastate = var.hastate
}

module "mayastor_storage" {
  source = "./storage"

  etcd_count = 1

  depends_on = [
    module.talos_proxmox_cluster
  ]
}


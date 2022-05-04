terraform {
  required_providers {
    talos = {
      source  = "localhost/jlgs/talos"
      version = ">= 0.0.0"
    }
    //proxmox = {
    //  source = "Telmate/proxmox"
    //  version = "2.9.7"
   // }
  }
}

provider "talos" {
  talos_environment = "prod"
  talos_node_dhcp_cidr = "10.0.0.0/24"
}
/*
provider "proxmox" {
  pm_api_url = "https://10.0.1.10:8006/api2/json"
}

resource "proxmox_vm_qemu" "control_node" {
  name = "eientei-control-1"
  desc = "Test control node"

  vmid = 9000

  target_node = "hakugyokuro"
  iso         = "rust0-proxmox:iso/talos-amd64.iso"

  bios = "ovmf"

  tablet = false
  agent  = 0

  memory = 2048
  cores  = 2

  tags = "kubernetes"

  disk {
    type     = "virtio"
    storage  = "flash0"
    size     = "4Gi"
    backup   = 1
    iothread = 1
  }


  network {
    bridge  = "vmbr0"
    model   = "virtio"
    macaddr = "e8:0a:d0:42:42:42"
  }
}
*/

resource "talos_configuration" "example" {
  cluster_name = "eientei"
  //registry_ip = "10.0.2.8"
  gateway     = "10.0.0.1"
  nameserver  = "10.0.0.1"
  talos_image = "ghcr.io/siderolabs/installer:v1.0.2"
  kubernetes_endpoint = "https://10.0.1.31:6443"
  kubernetes_version = "1.23.6"
  //apiproxy_ip = "10.0.1.30"

  //controlplane {
  //  name = "eientei-control-1"
  //  ip = "10.0.1.31"
  //}

  //worker {
  //  name = "eientei-worker-1"
  //  ip   = "10.0.1.50"
  //  pcid="0000:00:02.0"
  //  datasize="512G"
 // }
}

/*
resource "talos_control_node" "example" {
  for_each = {
    eientei-control-1: {ip="10.0.1.31", macaddr="e8:0a:d0:42:42:42"}
  }

  name = each.key
  macaddr = each.value.macaddr
  ip = each.value.ip

  ca_crt = talos_configuration.example.ca_crt
  
  depends_on = [
    proxmox_vm_qemu.control_node, // For timeout reasons
  ]
}

*/

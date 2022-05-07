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
    talos = {
      source  = "j-lgs/talos"
      version = "0.0.9"
    }
  }
}

resource "macaddress" "control_nodes" {
  for_each = var.control_nodes
  prefix = var.mac_prefix
}

resource "macaddress" "worker_nodes" {
  for_each = var.worker_nodes
  prefix = var.mac_prefix
}

resource "proxmox_vm_qemu" "worker_nodes" {
  connection {
    type = "ssh"
    user = "root"
    password = var.proxmox_nodes[self.target_node].root_password
    host = var.proxmox_nodes[self.target_node].ip
  }

  provisioner "remote-exec" {
    inline = [
      "if [ ${each.value.pcid} = '' ]; then exit; fi",
      "echo waiting for host ${each.key} for at most 180s",
      "sleep 15",
      "nc -z -w 180s ${each.value.ip} 50000",
      "sleep 15",
      "if [ ${each.value.mdev} != '' ]; then qm set ${self.vmid} -hostpci0 ${each.value.pcid},mdev=${each.value.mdev},pcie=1; fi",
      "if [ ${each.value.mdev} = '' ]; then qm set ${self.vmid} -hostpci0 ${each.value.pcid},pcie=1; fi",
      "qm set ${self.vmid} -machine q35",
      "qm stop ${self.vmid}",
      "sleep 10",
      "qm start ${self.vmid}"
    ]
  }

  for_each = var.worker_nodes
  name = each.key
  desc = "Worker node for the kubernetes cluster. Running on Talos. Node ${each.value.i+1}"
  
  target_node = each.value.node
  iso         = join("", [var.proxmox_nodes[each.value.node].isos, ":iso/", var.talos_iso])

  vmid = var.worker_vmid_base+each.value.i
  
  tablet = false
  agent  = 0
  bios   = "ovmf"
  memory = each.value.memory
  cores  = each.value.cores

  tags = "kubernetes"

  disk {
    type     = "virtio"
    storage  = var.proxmox_nodes[each.value.node].vm_images
    size     = each.value.bootsize
    backup   = 1
    iothread = 1
  }

  disk {
    type     = "virtio"
    storage  = var.proxmox_nodes[each.value.node].data_images
    size     = each.value.datasize
    backup   = 1
    iothread = 1
  }

  network {
    bridge  = "vmbr0"
    model   = "virtio"
    macaddr = macaddress.worker_nodes[each.key].address
  }
}

resource "proxmox_vm_qemu" "control_nodes" {
  for_each = var.control_nodes
  name = each.key
  desc = "Control plane node for the kubernetes cluster. Running on Talos. Node ${each.value.i+1}"

  vmid = var.control_vmid_base+each.value.i

  target_node = each.value.node
  iso         = join("", [var.proxmox_nodes[each.value.node].isos, ":iso/", var.talos_iso])

  bios = "ovmf"

  tablet = false
  agent  = 0

  memory = each.value.memory
  cores  = each.value.cores

  tags = "kubernetes"

  disk {
    type     = "virtio"
    storage  = var.proxmox_nodes[each.value.node].vm_images
    size     = each.value.bootsize
    backup   = 1
    iothread = 1
  }

  network {
    bridge  = "vmbr0"
    model   = "virtio"
    macaddr = macaddress.control_nodes[each.key].address
  }
}

resource "random_password" "vip_pass" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_shuffle" "controlplanes" {
  input        = keys(var.control_nodes)
}

locals {
  priorities = [
    {state: "MASTER", priority: 200},
    {state: "BACKUP", priority: 50},
    {state: "BACKUP", priority: 25}
  ]
  prioritymap = zipmap(keys(var.control_nodes), local.priorities)
  bootstrap_node_key = random_shuffle.controlplanes.result[0]
  bootstrap_node = var.control_nodes[random_shuffle.controlplanes.result[0]]
}
/*
resource "talos_worker_node" "eientei" {
  for_each = var.worker_nodes

  install_disk = "/dev/vda"
  talos_image = "ghcr.io/siderolabs/installer:v1.0.2"
  
  name = each.key
  macaddr = proxmox_vm_qemu.worker_nodes[each.key].network[0].macaddr
  dhcp_network_cidr = "10.0.0.0/24"
  ip = each.value.ip
  gateway = "10.0.0.1"
  nameservers = [
    "10.0.0.1"
  ]

  gpu = "Cometlake"
  privileged = false
  mayastor = true

  registry_ip = var.registry_ip

  base_config = talos_configuration.example.base_config
}
*/

//kubernetes_endpoint = join("", ["https://", local.bootstrap_node.ip, ":6443"])

resource "talos_configuration" "eientei" {
  target_version = "v1.0"
  cluster_name = "eientei"
  endpoints = ["10.0.1.31", "10.0.1.32", "10.0.1.33"]
  
  kubernetes_endpoint = "https://10.0.1.30:6443"
  kubernetes_version = "1.23.6"
}

resource "talos_control_node" "eientei" {
  for_each = var.control_nodes

  install_disk = "/dev/vda"
  talos_image = "ghcr.io/siderolabs/installer:v1.0.2"

  
  name = each.key
  macaddr = proxmox_vm_qemu.control_nodes[each.key].network[0].macaddr
  dhcp_network_cidr = "10.0.0.0/24"
  ip = each.value.ip
  gateway = "10.0.0.1"
  nameservers = [
    "10.0.0.1"
  ]
  peers = [for _, n in setsubtract([for _, n in var.control_nodes : n.ip], [each.value.ip]) : split("/", n)[0]]
  bootstrap = local.bootstrap_node_key == each.key

  wg_address = each.value.wg_ip
  wg_allowed_ips = "10.123.0.1/24"
  wg_endpoint = "209.202.254.14:8172"

  ingress_ip = "10.0.1.25"

  api_proxy_ip = "10.0.1.30"

  router_id = "11"
  state    = local.prioritymap[each.key].state
  priority = local.prioritymap[each.key].priority
  vip_pass = random_password.vip_pass.result

  registry_ip = var.registry_ip

  base_config = talos_configuration.eientei.base_config
}

# Create a local talosconfig
resource "local_file" "talosconfig" {
  content = talos_configuration.eientei.talosconfig
  filename = "talosconfig"
}

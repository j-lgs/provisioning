terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "2.9.7"
    }
  }
}

provider "proxmox" {
  pm_api_url = var.pm_api_url
}

resource "proxmox_lxc" "registry_cache" {
  target_node  = var.target_node
  hostname     = var.registry_hostname
  ostemplate   = var.registry_template
  password     = var.registry_password
  unprivileged = true

  rootfs {
    storage = var.container_boot_storage
    size    = var.registry_size
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = var.registry_cidr

    ip6    = "auto"
  }

  features {
    nesting = true
    keyctl  = true
  }

  cores = var.registry_cores
}

resource "local_file" "registry_cache" {
  content = <<-EOT
    [registry]
    localhost ansible_user=ansible ansible_password=ansible ansible_port=${docker_container.testing_registry.ports[0].external}
  EOT
  filename = "inventory"

  provisioner "local-exec" {
    command = "ansible-playbook --inventory inventory ../provision-registry.yml"
  }
}

resource "proxmox_vm_qemu" "control-nodes" {
  for_each = var.control_nodes
  name = each.key
  desc = "Control plane node for the kubernetes cluster. Running on Talos. Node ${each.value.idx+1}"

  vmid = var.control_vmid_base+each.value.idx

  target_node = var.target_node
  iso         = var.talos_iso

  tablet = false
  agent  = 0

  memory = each.value.memory
  cores  = each.value.cores

  tags = "kubernetes"

  disk {
    type = "virtio"
    storage  = var.boot_storage
    size     = each.value.bootsize
    backup   = 1
    iothread = 1
  }

  network {
    bridge  = "vmbr0"
    model   = "virtio"
    macaddr = each.value.mac
  }
}

resource "proxmox_vm_qemu" "worker-nodes" {
  for_each = var.worker_nodes
  name = each.key
  desc = "Worker node for the kubernetes cluster. Running on Talos. Node ${each.value.idx+1}"

  vmid = var.worker_vmid_base+each.value.idx

  target_node = var.target_node
  iso         = var.talos_iso

  tablet = false
  agent  = 0

  memory = each.value.memory
  cores  = each.value.cores

  tags = "kubernetes"

  disk {
    type     = "virtio"
    storage  = var.boot_storage
    size     = each.value.bootsize
    backup   = 1
    iothread = 1
  }

  disk {
    type     = "virtio"
    storage  = var.data_storage
    size     = each.value.datasize
    backup   = 1
    iothread = 1
  }

  network {
    bridge  = "vmbr0"
    model   = "virtio"
    macaddr = each.value.mac
  }
}

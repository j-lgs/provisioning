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

  provisioner "local-exec" {
    command = <<EOT
    cat <<EOF
    [registry]
    ${proxmox_lxc.registry_cache.network[0].ip} ansible_user=ansible ansible_password=ansible
    EOF > .gen/inventory
    ansible-playbook --inventory .gen/inventory ../provision-registry.yml
    EOT
  }
}

# Generate json patches that will be applied to the nodes after application
resource "null_resource" "generate_patches" {
  provisioner "local-exec" {
    command = <<EOT
    ansible-playbook generate-talos-patches.yaml --extra-vars @vars/vault.yaml --vault-password-file ~/vault_pass.txt
    EOT
  }
}

resource "null_resource" "bootstrap_cluster" {
  provisioner "local-exec" {
    command = <<EOT
    talosctl bootstrap -n var.control_nodes[0].ip
    EOT
  }

  depends_on = [
    proxmox_vm_qemu.control_nodes,
    proxmox_vm_qemu.worker_nodes,
  ]
}

resource "proxmox_vm_qemu" "control_nodes" {
  provisioner "local-exec" {
    command = <<EOT
    # Apply base config and stage
    talosctl apply --insecure -n ${each.value.ip} -f .gen/controlplane.yaml
    sleep 120
    talosctl apply -n ${each.value.ip} -f @.gen/${each.key}.json
    EOT
  }

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

  depends_on = [
    proxmox_lxc.registry_cache,
    null_resource.generate_patches
  ]
}

resource "proxmox_vm_qemu" "worker_nodes" {
  provisioner "local-exec" {
    command = <<EOT
    # Apply base config and stage
    talosctl apply --insecure -n ${each.value.ip} -f .gen/worker.yaml
    sleep 120
    talosctl apply -n ${each.value.ip} -f @.gen/${each.key}.json
    EOT
  }

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

  depends_on = [
    proxmox_lxc.registry_cache,
    null_resource.generate_patches
  ]
}

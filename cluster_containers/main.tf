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

resource "random_shuffle" "registry_node" {
  input        = keys(var.proxmox_nodes)
  result_count = 1
}

resource "random_password" "registry_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "proxmox_lxc" "registry_cache" {
  target_node  = random_shuffle.registry_node.result[0]
  hostname     = var.registry_hostname
  ostemplate   = "${var.proxmox_nodes[random_shuffle.registry_node.result[0]].templates}:vztmpl/${var.registry_template}"
  password     = random_password.registry_password.result
  unprivileged = true
  ostype       = "ubuntu"
  
  vmid = var.registry_vmid

  rootfs {
    storage = var.proxmox_nodes[random_shuffle.registry_node.result[0]].containers
    size    = var.registry_size
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    gw     = var.gateway
    ip     = var.registry_cidr
    ip6    = "auto"
  }

  features {
    fuse    = false
    keyctl  = true
    mknod   = false
    nesting = true
  }

  cores = var.registry_cores

  start  = true
  onboot = true

  // TODO: Move pubkeys to secrets. Referencing a file in the homedir breaks testing github action
  ssh_public_keys = <<-EOT
    ${file("~/.ssh/id_rsa.pub")}
  EOT

  // Unfortunately stuck with provisioners because the provider doesn't support preprovisioning.
  // And the proxmox api doesn't support cloud-init for containers.
  // TODO: Find a better solution for provisioning proxmox LXC containers.
  provisioner "local-exec" {
    command = <<EOT
    mkdir -p .gen/${var.environment}

    # Create the registry
    echo "[registry]
    ${split("/", proxmox_lxc.registry_cache.network[0].ip)[0]} ansible_user=root ansible_password=${random_password.registry_password.result}
    [patch_generator]
    localhost registry_ip=${split("/", proxmox_lxc.registry_cache.network[0].ip)[0]}" > .gen/${var.environment}/inventory

    # Wait for connection and machine initialisation.
    until ssh root@${split("/", proxmox_lxc.registry_cache.network[0].ip)[0]} true >/dev/null 2>&1; do echo "."; sleep 5; done
    sleep 15

    # Run the playbook
    ansible-playbook --inventory .gen/${var.environment}/inventory cluster_containers/provision_registry.yaml
    EOT
  }
}

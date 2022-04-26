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

resource "random_password" "registry_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "proxmox_lxc" "registry_cache" {
  target_node  = var.target_node
  hostname     = var.registry_hostname
  ostemplate   = var.registry_template
  password     = random_password.registry_password.result
  unprivileged = true
  ostype       = "ubuntu"

  vmid = 100

  rootfs {
    storage = var.container_boot_storage
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
    nesting = true
    keyctl  = true
  }

  cores = var.registry_cores

  start  = true
  onboot = true

  ssh_public_keys = <<-EOT
    ${file("~/.ssh/id_rsa.pub")}
  EOT

  provisioner "local-exec" {
    command = <<EOT
    mkdir -p .gen
    echo "[registry]
    ${split("/", proxmox_lxc.registry_cache.network[0].ip)[0]} ansible_user=root ansible_password=${random_password.registry_password.result}
    [patch_generator]
    localhost registry_ip=${split("/", proxmox_lxc.registry_cache.network[0].ip)[0]}" > .gen/inventory
    until ssh root@${split("/", proxmox_lxc.registry_cache.network[0].ip)[0]} true >/dev/null 2>&1; do echo "."; sleep 5; done
    ansible-playbook --inventory .gen/inventory provision-registry.yml
    EOT
  }
}

# Generate json patches that will be applied to the nodes after application
resource "null_resource" "generate_patches" {
  // Changes to templates or playbook require reprovisioning
  triggers = {
    hashes = <<EOT
${filesha256("../talos/generate-talos-patches.yaml")}
${filesha256("../talos/vars/vault.yaml")}
${filesha256("../talos/vars/main.yaml")}
${filesha256("../talos/vars/main.default.yaml")}
${filesha256("../talos/vars/vault.default.yaml")}
${filesha256("../talos/templates/check_apiserver.sh.j2")}
${filesha256("../talos/templates/control.json.j2")}
${filesha256("../talos/templates/worker.json.j2")}
${filesha256("../talos/templates/haproxy.cfg.j2")}
${filesha256("../talos/templates/keepalived.conf.j2")}
EOT
  }

  provisioner "local-exec" {
    command = <<EOT
    ansible-playbook ../talos/generate-talos-patches.yaml --extra-vars @../talos/vars/vault.yaml --vault-password-file ~/vault_pass.txt
    EOT
    environment = {
      DUMMY = var.is_sensitive
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = <<EOT
    cd ../talos/.gen
    rm *.sh *.privatekey *.yaml talosconfig *.conf *.cfg *.json || true
    EOT
  }
}

resource "null_resource" "bootstrap_cluster" {
  provisioner "local-exec" {
    command = <<EOT
    until talosctl disks -n ${var.target_node_ip} >/dev/null 2>&1; do echo "waiting for host ${var.target_node_ip}"; sleep 15; done
    # Probably wait a bit or rerun the command
    talosctl bootstrap -n ${var.target_node_ip}
    talosctl kubeconfig -m -f
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
    # Wait for host to be up
    echo "waiting for host ${each.key} to boot"
    nc -z -w 180 ${each.value.ip} 50000
    # Apply base config and stage
    talosctl apply --insecure -n ${each.value.ip} -f ../talos/.gen/controlplane.yaml
    echo "Base config applied"
    # Wait for host to be up
    until talosctl disks -n ${each.value.ip} >/dev/null 2>&1; do echo "waiting for host ${each.key}"; sleep 15; done
    # Apply patches
    talosctl patch machineconfig -n ${each.value.ip} --patch-file ../talos/.gen/${each.key}.json
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
    # Wait for host to be up
    echo "waiting for host ${each.key} to boot"
    nc -z -w 180 ${each.value.ip} 50000
    # Apply base config and stage
    talosctl apply --insecure -n ${each.value.ip} -f ../talos/.gen/worker.yaml
    echo "Base config applied"
    # Wait for host to be up
    echo "waiting for host ${each.key}"
    until talosctl disks -n ${each.value.ip} >/dev/null 2>&1; do echo "waiting for host ${each.key}"; sleep 45; done
    # Apply patches
    talosctl patch machineconfig -n ${each.value.ip} --patch-file ../talos/.gen/${each.key}.json
    EOT
  }

  //provisioner "remote-exec" {
  //  # Change machine type
  //  # Add pci passthrough
  //  # Reboot
  //}

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

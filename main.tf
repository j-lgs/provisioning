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

provider "proxmox" {
  pm_api_url = var.pm_api_url
}

resource "random_password" "registry_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "nfs_server" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "proxmox_lxc" "registry_cache" {
  target_node  = var.ct_target_node
  hostname     = var.registry_hostname
  ostemplate   = var.registry_template
  password     = random_password.registry_password.result
  unprivileged = true
  ostype       = "ubuntu"

  vmid = var.registry_vmid

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
    fuse    = false
    keyctl  = true
    mknod   = false
    nesting = true
  }

  cores = var.registry_cores

  start  = true
  onboot = true

  ssh_public_keys = <<-EOT
    ${file("~/.ssh/id_rsa.pub")}
  EOT

  provisioner "local-exec" {
    command = <<EOT
    mkdir -p .gen/${var.environment}
    echo "[registry]
    ${split("/", proxmox_lxc.registry_cache.network[0].ip)[0]} ansible_user=root ansible_password=${random_password.registry_password.result}
    [patch_generator]
    localhost registry_ip=${split("/", proxmox_lxc.registry_cache.network[0].ip)[0]}" > .gen/${var.environment}/inventory
    until ssh root@${split("/", proxmox_lxc.registry_cache.network[0].ip)[0]} true >/dev/null 2>&1; do echo "."; sleep 5; done
    sleep 15
    ansible-playbook --inventory .gen/${var.environment}/inventory provision-registry.yml
    EOT
  }
}

resource "proxmox_lxc" "nfs_server" {
  target_node  = var.nfs_node
  hostname     = var.nfs_hostname
  ostemplate   = var.nfs_template
  password     = random_password.nfs_server.result
  unprivileged = false
  ostype       = "ubuntu"

  vmid = 101

  rootfs {
    storage = var.nfs_root_storage
    size    = var.nfs_rootsize
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    gw     = var.gateway
    ip     = var.nfs_ip_cidr
    ip6    = "auto"
  }

  features {
    fuse    = false
    keyctl  = false
    mknod   = false
    mount   = "nfs"
    nesting = true
  }

  dynamic "mountpoint" {
    for_each = var.nfs_mountpoints
    content {
      key = tostring(mountpoint.key)
      slot = mountpoint.key
      storage = mountpoint.value["path"]
      volume  = mountpoint.value["path"]
      mp      = mountpoint.value["path"]
      size    = mountpoint.value["size"]
    }
  }

  cores = 2

  start  = true
  onboot = true

  ssh_public_keys = <<-EOT
    ${file("~/.ssh/id_rsa.pub")}
  EOT

  provisioner "local-exec" {
    command = <<EOT
    mkdir -p .gen/${var.environment}
    echo "[nfs]
    ${split("/", proxmox_lxc.nfs_server.network[0].ip)[0]} ansible_user=root ansible_password=${random_password.nfs_server.result}
    [patch_generator]
    localhost registry_ip=${split("/", proxmox_lxc.nfs_server.network[0].ip)[0]}" > .gen/${var.environment}/nfs_inventory
    until ssh root@${split("/", proxmox_lxc.nfs_server.network[0].ip)[0]} true >/dev/null 2>&1; do echo "."; sleep 5; done
    sleep 15
    ansible-playbook --inventory .gen/${var.environment}/nfs_inventory provision_nfs.yml
    EOT
  }
}

# Generate json patches that will be applied to the nodes after application
resource "null_resource" "generate_patches" {
  // Changes to templates or playbook require reprovisioning
  triggers = {
    environment = var.environment
    hashes = <<EOT
${filesha256("talos/generate-talos-patches.yaml")}
${filesha256("talos/vars/vault.yaml")}
${filesha256(join("", ["talos/vars/", var.environment ,"/vars.yaml"]))}
${filesha256("talos/vars/main.default.yaml")}
${filesha256("talos/vars/vault.default.yaml")}
${filesha256("talos/templates/check_apiserver.sh.j2")}
${filesha256("talos/templates/control.json.j2")}
${filesha256("talos/templates/worker.json.j2")}
${filesha256("talos/templates/haproxy.cfg.j2")}
${filesha256("talos/templates/keepalived.conf.j2")}
EOT
  }

  provisioner "local-exec" {
    command = <<EOT
    ansible-playbook talos/generate-talos-patches.yaml --extra-vars @talos/vars/vault.yaml --vault-password-file ~/vault_pass.txt --extra-vars "node_name_base=${var.cluster_name}" --extra-vars="@talos/vars/${var.environment}/vars.yaml" --extra-vars "project=${var.environment}"
    EOT
    environment = {
      DUMMY = var.is_sensitive
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = <<EOT
    cd talos/.gen/${self.triggers.environment}
    # Destroy all temporary files but don't destroy the talosconfig, base cluster config, or wireguard keys
    rm *.sh *.conf *.cfg *.json || true
    EOT
  }
}

resource "null_resource" "bootstrap_cluster" {
  triggers = {
    environment = var.environment
  }

  provisioner "local-exec" {
    command = <<EOT
    until talosctl disks -n ${var.target_node_ip} >/dev/null 2>&1; do echo "waiting for host ${var.target_node_ip}"; sleep 15; done
    # Probably wait a bit or rerun the command
    talosctl bootstrap -n ${var.target_node_ip}
    sleep 15
    talosctl bootstrap -n ${var.target_node_ip}
    talosctl kubeconfig -m -f
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = <<EOT
    cd talos/.gen/${self.triggers.environment}
    # IF this resource is being destroyed the cluster probably is too. Delete privatekeys and talosconfigs.
    rm *.privatekey talosconfig *.yaml || true
    EOT
  }

  depends_on = [
    proxmox_vm_qemu.control_nodes,
  ]
}


provider "kubectl" {
  load_config_file = true
}


provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

module "mayastor_storage" {
  source = "./storage"

  etcd_count = 1
  depends_on = [
    null_resource.bootstrap_cluster
  ]
}

resource "macaddress" "control_nodes" {
  for_each = var.control_nodes
  prefix = var.mac_prefix
}

resource "proxmox_vm_qemu" "control_nodes" {
  provisioner "local-exec" {
    command = <<EOT
    echo "Getting IP"
    # Get IP for mac address
    until [ $(nmap -sP 10.0.0.0/24 >/dev/null && arp -an | grep "${macaddress.control_nodes[each.key].address}" \
      | awk -F'[()]' '{print $2}') != "" ]; do
      echo "waiting for host ${each.key} to be connected to the network"; sleep 5;
    done
    ip=$(arp -an | grep "${macaddress.control_nodes[each.key].address}" | awk -F'[()]' '{print $2}')
    echo "Got IP $ip for host ${each.key}"
    # Wait for host to be up
    echo "waiting for host ${each.key} to boot"
    nc -z -w 180 $ip 50000
    # Apply base config and stage
    talosctl apply --insecure -n "$ip" -f talos/.gen/${var.environment}/controlplane.yaml
    echo "Base config applied"
    # Wait for host to be up
    until talosctl disks -n "$ip" -e "$ip" >/dev/null 2>&1; do echo "waiting for host ${each.key}"; sleep 15; done
    # Apply patches
    talosctl patch machineconfig -n "$ip" -e "$ip" --patch-file talos/.gen/${var.environment}/${each.key}.json
    EOT
  }

  for_each = var.control_nodes
  name = each.key
  desc = "Control plane node for the kubernetes cluster. Running on Talos. Node ${each.value.idx+1}"

  vmid = var.control_vmid_base+each.value.idx

  target_node = each.value.node
  iso         = join("", [each.value.isoloc, ":iso/", var.talos_iso])

  bios = "ovmf"

  tablet = false
  agent  = 0

  memory = each.value.memory
  cores  = each.value.cores

  tags = "kubernetes"

  disk {
    type = "virtio"
    storage  = each.value.bootloc
    size     = each.value.bootsize
    backup   = 1
    iothread = 1
  }

  network {
    bridge  = "vmbr0"
    model   = "virtio"
    macaddr = macaddress.control_nodes[each.key].address
  }

  depends_on = [
    proxmox_lxc.registry_cache,
    null_resource.generate_patches
  ]
}

resource "macaddress" "worker_nodes" {
  for_each = var.worker_nodes
  prefix = var.mac_prefix
}

resource "proxmox_vm_qemu" "igpu_worker_nodes" {
  provisioner "local-exec" {
    command = <<EOT
    until [ $(nmap -sP 10.0.0.0/24 >/dev/null && arp -an | grep "${macaddress.worker_nodes[each.key].address}" \
      | awk -F'[()]' '{print $2}') != "" ]; do
      echo "waiting for host ${each.key} to be connected to the network"; sleep 5;
    done
    ip=$(arp -an | grep "${macaddress.worker_nodes[each.key].address}" | awk -F'[()]' '{print $2}')
    # Wait for host to be up
    echo "waiting for host ${each.key} to boot"
    nc -z -w 180s $ip 50000
    sleep 5
    # Apply base config and stage
    talosctl apply --insecure -n $ip -f talos/.gen/${var.environment}/worker.yaml
    echo "Base config applied"
    # Wait for host to be up
    echo "waiting for host ${each.key}"
    until talosctl disks -n "$ip" -e "$ip" >/dev/null 2>&1; do echo "waiting for host ${each.key}"; sleep 15; done
    # Apply patches
    talosctl patch machineconfig -n "$ip" -e "$ip" --patch-file talos/.gen/${var.environment}/${each.key}.json
    EOT
  }

  connection {
    type = "ssh"
    user = "root"
    password = var.connections[self.target_node].password
    host = var.connections[self.target_node].ip
  }

  provisioner "remote-exec" {
    inline = [
      "echo waiting for host ${each.key} for at most 180s",
      "sleep 15",
      "nc -z -w 180s ${each.value.ip} 50000",
      "sleep 15",
      "qm set ${self.vmid} -hostpci0 ${var.pcie_id[each.key].id},mdev=${var.pcie_id[each.key].mdev},pcie=1",
      "qm set ${self.vmid} -machine q35",
      "qm reboot ${self.vmid}"
    ]
  }

  for_each = var.worker_nodes
  name = each.key
  desc = "Worker node for the kubernetes cluster. Running on Talos. Node ${each.value.idx+1}"

  vmid = var.worker_vmid_base+each.value.idx

  target_node = each.value.node
  iso         = join("", [each.value.isoloc, ":iso/", var.talos_iso])

  tablet = false
  agent  = 0
  bios   = "ovmf"

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
    macaddr = macaddress.worker_nodes[each.key].address
  }

  depends_on = [
    proxmox_lxc.registry_cache,
    null_resource.generate_patches
  ]
}

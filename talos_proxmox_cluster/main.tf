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

  # Generate the patches. Treat output as sensitive because it includes wireguard private keys
  provisioner "local-exec" {
    command = <<EOT
    ansible-playbook talos/generate-talos-patches.yaml --extra-vars @talos/vars/vault.yaml --vault-password-file ~/vault_pass.txt --extra-vars="@talos/vars/${var.environment}/vars.yaml" --extra-vars "node_name_base=${var.cluster_name} project=${var.environment} registry_host=${var.registry_ip}"
    EOT
    environment = {
      DUMMY = var.is_sensitive
    }
  }

  # Destroy all temporary files but don't destroy the talosconfig, base cluster config, or wireguard keys
  provisioner "local-exec" {
    when = destroy
    command = <<EOT
    cd talos/.gen/${self.triggers.environment}
    
    rm *.sh *.conf *.cfg *.json || true
    EOT
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

  depends_on = [
    null_resource.generate_patches
  ]
}

resource "proxmox_vm_qemu" "worker_nodes" {
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
      "qm reboot ${self.vmid}"
    ]
  }

  for_each = var.worker_nodes
  name = each.key
  desc = "Worker node for the kubernetes cluster. Running on Talos. Node ${each.value.i+1}"

  vmid = var.worker_vmid_base+each.value.i

  target_node = each.value.node
  iso         = join("", [var.proxmox_nodes[each.value.node].isos, ":iso/", var.talos_iso])

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

  depends_on = [
    null_resource.generate_patches
  ]
}

resource "random_shuffle" "controlplane" {
  input        = keys(var.control_nodes)
  result_count = 1
}

locals {
  bootstrap_ip = var.control_nodes[random_shuffle.controlplane.result[0]].ip
}

resource "null_resource" "bootstrap_cluster" {
  triggers = {
    environment = var.environment
  }

  provisioner "local-exec" {
    command = <<EOT
    until talosctl disks -n ${local.bootstrap_ip} >/dev/null 2>&1; do echo "waiting for host ${local.bootstrap_ip}"; sleep 15; done
    # Probably wait a bit or rerun the command
    talosctl bootstrap -n ${local.bootstrap_ip}
    sleep 15
    talosctl bootstrap -n ${local.bootstrap_ip}
    talosctl kubeconfig -m -f
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = <<EOT
    cd talos/.gen/${self.triggers.environment}
    # If this resource is being destroyed the cluster probably is too. Delete privatekeys and talosconfigs.
    rm *.privatekey talosconfig *.yaml || true
    EOT
  }

  depends_on = [
    proxmox_vm_qemu.control_nodes,
  ]
}

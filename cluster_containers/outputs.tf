output "registry_ip" {
  value = split("/", proxmox_lxc.registry_cache.network[0].ip)[0]
}

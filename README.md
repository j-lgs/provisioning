![CI](https://github.com/j-lgs/provisioning/workflows/CI/badge.svg)

## About
Scripts, configurations and playbooks for provisioning my homelab's local and remote servers.

### Talos
This lab utilises [Talos](https://github.com/siderolabs/talos) as the base operating system for the Kuebernetes worker and controlplane virtual machines. This repo includes an ansible playbook for creating an example setup with a highly available kubernetes controlplane and a wireguard connection to a VPS. This setup removes the need for port forwarding on my home network.

### Terraform
Terraform is used to provision the actual servers on a Proxmox host. Example variables are provided inside the repository.

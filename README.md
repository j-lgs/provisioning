![Tests](https://github.com/j-lgs/provisioning/workflows/Tests/badge.svg)
![Tests](https://github.com/j-lgs/provisioning/workflows/Container%20CI/badge.svg)

## About
Scripts, configurations and playbooks for provisioning my homelab's local and remote servers.

### Talos
This lab utilises [Talos](https://github.com/siderolabs/talos) as the base operating system for the Kuebernetes worker and controlplane virtual machines. This repo includes an ansible playbook for creating an example setup with a highly available kubernetes controlplane and a wireguard connection to a VPS. This setup removes the need for port forwarding on my home network.

When running the playbook on the development environment run a variation of the following command. The vault.yaml file will redefine variables in the vars/vault.default.yaml var file.

```
ansible-playbook playbook.yaml --extra-vars @vars/vault.yaml --vault-password-file ~/vault_pass.txt
```

### Terraform
Terraform is used to provision the actual servers on a Proxmox host. Example variables are provided inside the repository.


Requires installation of ansible, docker, talosctl for the creation of the testing cluster.

```
terraform plan  -var-file="testing.tfvars"
terraform apply -var-file="testing.tfvars"
# Wait for cluster to be up and running
terraform plan  -var-file="testing.tfvars"
terraform apply -var-file="testing.tfvars"
```

```
terraform destroy -var-file="testing.tfvars"
```

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.16.0"
    }
  }
}

provider "docker" {
  # Using docker socket because my development environment is run inside a toolbox container.
  host = "tcp://localhost:2376"
}

# Workaround for the fact that the "docker_image" resource dosent recreate on Dockerfile changes.
resource "random_pet" "dockerfiles" {
  keepers = {
    id = "${filesha256("image/Dockerfile")}${filesha256("image/root/usr/sbin/container-init")}"
  }
}

resource "docker_image" "testing_registry" {
  name = "testing_registry"
  build {
    path = "image"
    tag = ["testing_registry:latest"]
  }

  # Recreate when Dockerfile or container init script change
  depends_on = [
    random_pet.dockerfiles
  ]
}

resource "docker_container" "testing_registry" {
  image = "${docker_image.testing_registry.latest}"
  name = "testing_registry"
  must_run = true

  privileged = true
  rm = true

  publish_all_ports = true
  ports {
    internal = "22"
    external = "2222"
  }

  provisioner "local-exec" {
    command = <<EOT
    echo "[registry]
    ${docker_container.testing_registry.ip_address} ansible_user=ansible ansible_password=ansible  ansible_become_password=ansible" > .gen/inventory
    ansible-playbook --inventory .gen/inventory ../provision-registry.yml
    EOT
  }

  depends_on = [
    docker_container.testing_registry
  ]
}

resource "null_resource" "testing_cluster" {
  provisioner "local-exec" {
    command = <<EOT
       talosctl cluster create \
        --with-debug --skip-kubeconfig \
        --registry-mirror docker.io=http://${docker_container.testing_registry.ip_address}:5000 \
        --registry-mirror k8s.gcr.io=http://${docker_container.testing_registry.ip_address}:5001 \
        --registry-mirror quay.io=http://${docker_container.testing_registry.ip_address}:5002 \
        --registry-mirror gcr.io=http://${docker_container.testing_registry.ip_address}:5003 \
        --registry-mirror ghcr.io=http://${docker_container.testing_registry.ip_address}:5004 \
        --workers ${length(var.worker_nodes)} \
        --masters ${length(var.control_nodes)} \
        --provisioner docker \
        --name "talos-default" \
        --talosconfig ".gen/talosconfig" \
        --wait-timeout 15m0s
        > .gen/cluster-info.txt
      talosctl --nodes 10.5.0.2 --talosconfig .gen/talosconfig kubeconfig .gen/kubeconfig  -f
      EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "talosctl --talosconfig .gen/talosconfig cluster destroy"
  }

  depends_on = [
    docker_container.testing_registry
  ]
}

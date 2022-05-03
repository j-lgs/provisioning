locals {
  mayastor_yamls = [
    "https://raw.githubusercontent.com/openebs/mayastor-control-plane/${var.mayastor_version}/deploy/operator-rbac.yaml",
    "https://raw.githubusercontent.com/openebs/mayastor-control-plane/${var.mayastor_version}/deploy/mayastorpoolcrd.yaml",
    "https://raw.githubusercontent.com/openebs/mayastor/${var.mayastor_version}/deploy/csi-daemonset.yaml",
    "https://raw.githubusercontent.com/openebs/mayastor-control-plane/${var.mayastor_version}/deploy/core-agents-deployment.yaml",
    "https://raw.githubusercontent.com/openebs/mayastor-control-plane/${var.mayastor_version}/deploy/rest-deployment.yaml",
    "https://raw.githubusercontent.com/openebs/mayastor-control-plane/${var.mayastor_version}/deploy/rest-service.yaml",
    "https://raw.githubusercontent.com/openebs/mayastor-control-plane/${var.mayastor_version}/deploy/csi-deployment.yaml",
    "https://raw.githubusercontent.com/openebs/mayastor-control-plane/${var.mayastor_version}/deploy/msp-deployment.yaml",
    "https://raw.githubusercontent.com/openebs/mayastor/${var.mayastor_version}/deploy/mayastor-daemonset.yaml",
    "https://raw.githubusercontent.com/openebs/mayastor/${var.mayastor_version}/deploy/storage-class.yaml",
    "https://raw.githubusercontent.com/openebs/mayastor/${var.mayastor_version}/deploy/nats-deployment.yaml"
  ]

  etcd_persist_size = "2Gi"
  localpv_class_name = "local-storage"
}

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

// Mayastor namespace
resource "kubectl_manifest" "mayastor_namespace" {
  yaml_body = <<TOC
apiVersion: v1
kind: Namespace
metadata:
  name: mayastor
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
TOC
}

resource "kubectl_manifest" "mayastor_etcd_create_dirs" {
  yaml_body = <<TOC
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: create-etcd-dirs
  namespace: mayastor
  labels:
    k8s-app: create-etcd-dirs
spec:
  selector:
    matchLabels:
      name: create-etcd-dirs
  template:
    metadata:
      labels:
        name: create-etcd-dirs
    spec:
      initContainers:
      - name: create-etcd-dirs
        image: busybox
        command: ["/bin/sh"]
        args:
        - -c
        - >-
          for i in $(seq 0 ${var.etcd_count}); do \
            mkdir -p /var/local/mayastor/etcd/pod-"$i"; \
          done
        volumeMounts:
        - mountPath: /var/local/mayastor
          name: writable
        resources:
          limits:
            cpu: 50m
            memory: 50Mi
          requests:
            cpu: 50m
            memory: 50Mi
      containers:
      - name: pause
        image: gcr.io/google_containers/pause
        resources:
          limits:
            cpu: 50m
            memory: 50Mi
          requests:
            cpu: 50m
            memory: 50Mi
      volumes:
      - name: writable
        hostPath:
          path: /var/local/mayastor
          type: DirectoryOrCreate
TOC
}

resource "kubectl_manifest" "mayastor_etcd_localpv" {
  force_new = true
  count = var.etcd_count
  yaml_body = <<TOC
apiVersion: v1
kind: PersistentVolume
metadata:
  namespace: mayastor
  name: data-etcd-${count.index}
  labels:
    app: etcd
    statefulset.kubernetes.io/pod-name: etcd-${count.index}
spec:
  storageClassName: ${local.localpv_class_name}
  # You must also delete the hostpath on the node
  persistentVolumeReclaimPolicy: Retain
  capacity:
    storage: "${local.etcd_persist_size}"
  accessModes:
  - ReadWriteOnce
  local:
    path: "/var/local/mayastor/etcd/pod-${count.index}"
  # By default the DaemonSet creates the requisite directories on every node.
  # This way it doesn't matter which node the pod is scheduled on. In the future
  # It would be ideal to restrict this dir creation and PV placement to nodes with
  # a "mayastor-etcd" role.

  # TODO: Automatically generate nodeAffinity from worker node list
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - eientei-worker-1 
TOC
}

resource "helm_release" "etcd" {
  name       = "etcd"
  namespace  = "mayastor"

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "etcd"
  version    = "${var.etcd_version}"

  set {
    name  = "persistence.size"
    value = "${local.etcd_persist_size}"
  }

  set {
    name  = "persistence.storageClass"
    value = "${local.localpv_class_name}"
  }

  set {
    name  = "volumePermissions.enabled"
    value = "true"
  }

  set {
    name = "persistence.existingClaim"
    value = "app=etcd"
  }

  set {
    name = "auth.rbac.create"
    value = "false"
  }

  depends_on = [
    kubectl_manifest.mayastor_etcd_localpv,
    kubectl_manifest.mayastor_etcd_create_dirs
  ]
}

// Mayastor yamls pulled from Github
data "http" "mayastor_yamls" {
  for_each = toset(local.mayastor_yamls)
  url = each.value

  request_headers = {
    Accept = "application/yaml"
  }
}

data "kubectl_file_documents" "mayastor_yamls" {
  for_each = data.http.mayastor_yamls
  content  = tostring(each.value.body)
}

locals {
  // For each kubectl_file_documents instance we have, get the manifests and make a new array.
  // Expand that array and pass it to the merge function to get a map of kubernetes resource names
  // to resource yaml descriptions
  yamllist = merge([for m in data.kubectl_file_documents.mayastor_yamls: m.manifests]...)
}

// this needs to be commented out on first run of terraform apply, as previous manifests are not known at runtime.
// before release i need to figure out how to target those dynamic resources first.
resource "kubectl_manifest" "mayastor_yamls" {
  for_each = merge([for m in data.kubectl_file_documents.mayastor_yamls: m.manifests]...)
  yaml_body = "${each.value}"
  depends_on = [
    helm_release.etcd
  ]
}

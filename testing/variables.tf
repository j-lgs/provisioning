variable "control_nodes" {
  description = "Map of controlplane nodes."
  type = map
  default = {
    "cluster-control-1"={idx=0, mac="replace me", cores=2, memory=2048, bootsize="64G"}
    "cluster-control-2"={idx=0, mac="replace me", cores=2, memory=2048, bootsize="64G"}
    "cluster-control-3"={idx=0, mac="replace me", cores=2, memory=2048, bootsize="64G"}
  }
}

variable "worker_nodes" {
  description = "Map of worker nodes."
  type = map
  default = {
    "cluster-worker-1"={idx=0, mac="replace me", cores=2, memory=2048, bootsize="64G", datasize="64G"}
  }
}

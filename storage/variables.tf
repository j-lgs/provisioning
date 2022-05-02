variable "mayastor_version" {
  description = "Github tag that determines the version of mayastor we deploy."
  type        = string
  default     = "v1.0.1"
}

variable "etcd_version" {
  description = "Version of the Bitnami Etcd Helm chart to deploy."
  type        = string
  default     = "8.1.0"
}

variable "etcd_count" {
  description = "The amount of Etcd replicas to deploy."
  type        = number
  default     = 1
}

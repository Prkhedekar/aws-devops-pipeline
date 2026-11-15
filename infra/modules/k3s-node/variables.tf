variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "instance_type" {
  type        = string
  default     = "t3.small"
  description = "t3.small (2 GB) runs k3s + app + Postgres. Use t3.medium once you add Prometheus/Grafana."
}

variable "root_volume_gb" {
  type    = number
  default = 20
}

variable "allowed_cidr" {
  type        = string
  description = "Your public IP in CIDR form (x.x.x.x/32). Only this IP can reach SSH and the Kubernetes API."

  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0)) && var.allowed_cidr != "0.0.0.0/0"
    error_message = "allowed_cidr must be a valid CIDR and must not be 0.0.0.0/0."
  }
}

variable "ssh_public_key" {
  type        = string
  description = "Contents of your SSH public key"
}

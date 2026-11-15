variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "allowed_cidr" {
  type        = string
  description = "Your public IP as x.x.x.x/32 (find it with: curl ifconfig.me)"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

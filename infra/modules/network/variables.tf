variable "name" {
  type        = string
  description = "Name prefix for all network resources"
}

variable "cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR block"
}

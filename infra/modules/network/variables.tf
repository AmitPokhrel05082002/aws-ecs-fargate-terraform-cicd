variable "name" {
  description = "Name prefix for network resources."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block, /16 recommended."
  type        = string
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "Use 2 or 3 AZs (the load balancer and RDS need at least 2)."
  }
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway for all AZs (cheaper, for non-production)."
  type        = bool
  default     = false
}

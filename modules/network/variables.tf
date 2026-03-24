variable "environment" {
  description = "Environment name (dev, uat, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "Environment must be dev, uat, or prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_cidrs) > 0 && length(var.public_subnet_cidrs) <= 3
    error_message = "Must have 1-3 public subnets."
  }
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_cidrs) > 0 && length(var.private_subnet_cidrs) <= 3
    error_message = "Must have 1-3 private subnets."
  }
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "boundary_release" {
  default     = "0.8.1"
  description = "The version of Boundary to install"
  type        = string
}

variable "cidr_block" {
  default     = "10.0.0.0/16"
  description = "The IPv4 network range for the VPC, in CIDR notation. For example, 10.0.0.0/16."
  type        = string
}

variable "controller_desired_capacity" {
  default     = 1
  description = "The capacity the controller Auto Scaling group attempts to maintain"
  type        = number
}

variable "controller_instance_type" {
  default     = "t2.micro"
  description = "Specifies the instance type of the controller EC2 instance"
  type        = string
}

variable "controller_max_size" {
  default     = 1
  description = "The maximum size of the controller group"
  type        = number
}

variable "controller_min_size" {
  default     = 1
  description = "The minimum size of the controller group"
  type        = number
}

variable "key_name" {
  default     = "/Users/mtolley/.ssh/id_rsa.pub"
  description = "The name of the key pair"
  type        = string
}

variable "private_subnets" {
  default     = []
  description = "List of private subnets"
  type        = list(string)
}

variable "public_subnets" {
  default     = []
  description = "List of public subnets"
  type        = list(string)
}

variable "tags" {
  default     = {}
  description = "One or more tags"
  type        = map(string)
}

variable "vpc_id" {
  default     = ""
  description = "The ID of the VPC"
  type        = string
}

variable "worker_desired_capacity" {
  default     = 1
  description = "The capacity the worker Auto Scaling group attempts to maintain"
  type        = number
}

variable "worker_instance_type" {
  default     = "t2.micro"
  description = "Specifies the instance type of the worker EC2 instance"
  type        = string
}

variable "worker_max_size" {
  default     = 1
  description = "The maximum size of the worker group"
  type        = number
}

variable "worker_min_size" {
  default     = 1
  description = "The minimum size of the worker group"
  type        = number
}

variable "kms_key_description" {
  default = "boundary_s3_kms"
  type    = string
}

variable "kms_key_alias" {
  default = "boundary_kms_key"
  type    = string
}
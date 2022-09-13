variable "boundary_release" {
  default     = "0.8.1"
  description = "The version of Boundary to install"
  type        = string
}

variable "bucket_name" {
  description = <<EOF
The name of the bucket to upload the contents of the
cloud-init-output.log file
EOF

  type = string
}

variable "desired_capacity" {
  default = 1

  description = <<EOF
The desired capacity is the initial capacity of the Auto Scaling group
at the time of its creation and the capacity it attempts to maintain.
EOF

  type = number
}

variable "image_id" {
  description = <<EOF
The ID of the Amazon Machine Image (AMI) that was assigned during registration
EOF

  type = string
}

variable "instance_type" {
  default     = "t2.micro"
  description = "Specifies the instance type of the EC2 instance"
  type        = string
}

variable "key_name" {
  default     = "/Users/mtolley/.ssh/id_rsa.pub"
  description = "The name of the key pair"
  type        = string
}

variable "max_size" {
  default     = 1
  description = "The maximum size of the group"
  type        = number
}

variable "min_size" {
  default     = 1
  description = "The minimum size of the group"
  type        = number
}

variable "private_subnets" {
  description = "List of private subnets"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnets"
  type        = list(string)
}

variable "tags" {
  default = {}

  description = <<EOF
One or more tags. You can tag your Auto Scaling group and propagate the tags to
the Amazon EC2 instances it launches.
EOF

  type = map(string)
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "aws_public_key" {
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDf8OOfOxkzLIyeBrxbNAFd9yd5gp9z1zDj1Ee3WR173emkodHRsaLn99JGHqFbBRsTRe7yMuPyo+ZIV/U5RM/kDmtU8fpqYLllwRdgkOcw9uC9erpWQ6o6moSjas0Dl98PbMZrM9Ttn73Zmfyu3PzR83sCFKENvugrS6MyP+pmOVoKZhbrIwfCie1h2i5rlbmrCY/0A7iGL23AMlR+KKmc5A3YYaZ1q/uX65Y6XDUP7N8AGoYnkFLUw/E+l+gX6J96y1ouWi4DCmfhrUiGz/7n6muUaDNPandMFtwYp1rIfAIS7N+pAqMnm7NF6NSyipcTkHQD/mnf87n0+GqW6xCp mtolley@BRI-MA-KP999JKX26"
  description = "Public key for SSH"
  type        = string

}

variable "kms_key_alias" {
  type    = string
  default = "boundary_S3_kms"
}

#variable "controller_name" {
#  default     = "GCSE-PRD-AWS-EU.W1-BNDRY-Ctrl-"
#  description = "Naming convention for AS group"
#  type        = string

#}

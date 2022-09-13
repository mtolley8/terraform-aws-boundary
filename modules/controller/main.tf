terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

locals {
  configuration = templatefile(
    "${path.module}/templates/configuration.hcl.tpl",
    {
      # Database URL for PostgreSQL
      database_url = format(
        "postgresql://%s:%s@%s/%s",
        module.postgresql.db_instance_username,
        module.postgresql.db_instance_password,
        module.postgresql.db_instance_endpoint,
        module.postgresql.db_instance_name
      )

      keys = [
        {
          key_id  = aws_kms_key.root.key_id
          purpose = "root"
        },
        {
          key_id  = aws_kms_key.auth.key_id
          purpose = "worker-auth"
        }
      ]
    }
  )
}

data "aws_instances" "controllers" {
  instance_state_names = ["running"]

  instance_tags = {
    "aws:autoscaling:groupName" = module.controllers.auto_scaling_group_name
  }
}

data "aws_s3_bucket" "boundary" {
  bucket = var.bucket_name
}

resource "aws_security_group" "alb" {
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }

  dynamic "ingress" {
    for_each = [80, 443]

    content {
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = ingress.value
      protocol    = "TCP"
      to_port     = ingress.value
    }
  }

  name = "Boundary Application Load Balancer"

  tags = merge(
    {
      Name = "Boundary Application Load Balancer"
    },
    var.tags
  )

  vpc_id = var.vpc_id
}

resource "aws_security_group" "controller" {
  name   = "Boundary controller"
  tags   = var.tags
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "ssh" {
  count = var.key_name != "" ? 1 : 0

  from_port                = 22
  protocol                 = "TCP"
  security_group_id        = aws_security_group.controller.id
  source_security_group_id = one(aws_security_group.bastion[*].id)
  to_port                  = 22
  type                     = "ingress"
}

resource "aws_security_group_rule" "ingress" {
  from_port                = 9200
  protocol                 = "TCP"
  security_group_id        = aws_security_group.controller.id
  source_security_group_id = aws_security_group.alb.id
  to_port                  = 9200
  type                     = "ingress"
}

resource "aws_security_group_rule" "egress" {
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.controller.id
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group" "postgresql" {
  ingress {
    from_port       = 5432
    protocol        = "TCP"
    security_groups = [aws_security_group.controller.id]
    to_port         = 5432
  }

  tags   = var.tags
  vpc_id = var.vpc_id
}

resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = var.aws_public_key
  }


module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.5"

  http_tcp_listeners = [
    {
      port     = 80
      protocol = "HTTP"
    }
  ]

  load_balancer_type = "application"
  name               = "GCSE-PRD-AWS-EUW1-BNDRY-ALB"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnets
  tags               = var.tags

  target_groups = [
    {
      name             = "boundary"
      backend_protocol = "HTTP"
      backend_port     = 9200
    }
  ]

  vpc_id = var.vpc_id
}

resource "random_password" "postgresql" {
  length  = 16
  special = false
}

module "postgresql" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 3.4"

  allocated_storage       = 5
  backup_retention_period = 0
  backup_window           = "03:00-06:00"
  engine                  = "postgres"
  engine_version          = "12.8"
  family                  = "postgres12"
  identifier              = "boundary"
  instance_class          = "db.t2.micro"
  maintenance_window      = "Mon:00:00-Mon:03:00"
  major_engine_version    = "12"
  name                    = "boundary"
  password                = random_password.postgresql.result
  port                    = 5432
  storage_encrypted       = false
  subnet_ids              = var.private_subnets
  tags                    = var.tags
  username                = "boundary"
  vpc_security_group_ids  = [aws_security_group.postgresql.id]
}

module "controllers" {
  source = "../boundary"
  # count = 0

  after_start = [
    "grep 'Initial auth information' /var/log/cloud-init-output.log && aws s3 cp /var/log/cloud-init-output.log s3://${var.bucket_name}/{{v1.local_hostname}}/cloud-init-output.log || true"
  ]

  # auto_scaling_group_name = "$(var.auto_scaling_group_name)${count.index + 1}"
  auto_scaling_group_name = "GCSE-PRD-AWS-EU.W1-BNDRY-Controller"

  # Initialize the DB before starting the service and install the AWS
  # CLI.
  before_start = [
    "curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip",
    "unzip awscliv2.zip",
    "./aws/install",
    "boundary database init -config /etc/boundary/configuration.hcl -log-format json"
  ]

  boundary_release     = var.boundary_release
  bucket_name          = var.bucket_name
  desired_capacity     = var.desired_capacity
  iam_instance_profile = aws_iam_instance_profile.controller.arn
  image_id             = var.image_id
  instance_type        = var.instance_type
  key_name             = var.key_name
  max_size             = var.max_size
  min_size             = var.min_size
  security_groups      = [aws_security_group.controller.id]
  tags                 = var.tags
  target_group_arns    = module.alb.target_group_arns
  vpc_zone_identifier  = var.private_subnets

  write_files = [
    {
      content     = local.configuration
      owner       = "root:root"
      path        = "/etc/boundary/configuration.hcl"
      permissions = "0644"
    }
  ]
}

# https://www.boundaryproject.io/docs/configuration/kms/awskms#authentication
#
# Allows the controllers to invoke the Decrypt, DescribeKey, and Encrypt
# routines for the worker-auth and root keys.
data "aws_iam_policy_document" "controller" {
  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt"
    ]

    effect = "Allow"

    resources = [aws_kms_key.auth.arn, aws_kms_key.root.arn]
  }

  statement {
    actions = [
      "s3:*"
    ]

    effect = "Allow"

    resources = [
      "${data.aws_s3_bucket.boundary.arn}/",
      "${data.aws_s3_bucket.boundary.arn}/*"
    ]
  }
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    effect = "Allow"

    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_policy" "controller" {
  name   = "BoundaryControllerServiceRolePolicy"
  policy = data.aws_iam_policy_document.controller.json
}

resource "aws_iam_role" "controller" {
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  name               = "ServiceRoleForBoundaryController"
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "controller" {
  policy_arn = aws_iam_policy.controller.arn
  role       = aws_iam_role.controller.name
}

resource "aws_iam_instance_profile" "controller" {
  role = aws_iam_role.controller.name
}

# The root key used by controllers
resource "aws_kms_key" "root" {
  deletion_window_in_days = 7
  key_usage               = "ENCRYPT_DECRYPT"
  tags                    = merge(var.tags, { Purpose = "root" })
}

# The worker-auth AWS KMS key used by controllers and workers
resource "aws_kms_key" "auth" {
  deletion_window_in_days = 7
  key_usage               = "ENCRYPT_DECRYPT"
  tags                    = merge(var.tags, { Purpose = "worker-auth" })
}

resource "aws_security_group" "bastion" {
  count = var.key_name != "" ? 1 : 0

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    protocol    = "TCP"
    to_port     = 22
  }

  name   = "Boundary Bastion"
  tags   = var.tags
  vpc_id = var.vpc_id
}

resource "aws_instance" "bastion" {
  count = var.key_name != "" ? 1 : 0

  ami                         = var.image_id
  associate_public_ip_address = true
  instance_type               = "t3.micro"
  key_name                    = var.key_name
  subnet_id                   = var.public_subnets[0]
  tags                        = merge(var.tags, { Name = "GCSE-PRD-AWS-EU.W1-BNDRY-Bastion" })
  vpc_security_group_ids      = [one(aws_security_group.bastion[*].id)]
}


#
# authentication setup
#

provider "boundary" {

    addr = "http://10.0.0.0:80"
    #addr = var.associate_public_ip_address

# Root KMS configuration block: this is the root key for Boundary
# Use a production KMS such as AWS KMS in production installs
kms "aead" {
  purpose = "root"
  aead_type = "aes-gcm"
  key = "sP1fnF5Xz85RrXyELHFeZg9Ad2qt4Z4bgNHVGtD6ung="
  key_id = "global_root"
}

# Worker authorization KMS
# Use a production KMS such as AWS KMS for production installs
# This key is the same key used in the worker configuration
kms "aead" {
  purpose = "worker-auth"
  aead_type = "aes-gcm"
  key = "8fZBjCUfN0TzjEGLQldGY4+iE9AkOvCfjh7+p0GtRBQ="
  key_id = "global_worker-auth"
}


recovery_kms_hcl = <<EOT
kms "aead" {
    purpose   = "recovery"
    aead_type = "aes-gcm"
    key       = "8fZBjCUfN0TzjEGLQleGY4+iE2AkOvCnjh7+p0GtRBQ="
    key_id    = "global_recovery"
}
EOT
}

#resource "boundary_auth_method_oidc" "provider" {
#  name                 = "Azure"
#  description          = "OIDC auth method for Azure"
#  scope_id             = "global"
#  issuer               = "https://sts.windows.net/4aed35c0-c2db-42c6-8c17-efca15bfabfb/"
#  client_id            = "5Ep7Q~Gs4Muqv8~a9StIe4sP4tgAGeZ7vmOO6"
#  client_secret        = "982e897f-7d00-4542-8a39-864c1747811c"
#  signing_algorithms   = ["RS256"]
#  state                = "active-public"
#  is_primary_for_scope = true
  #api_url_prefix       = data.aws_lb.test.dns_name
  #api_url_prefix       = "https://10.0.0.0:9200"
#}
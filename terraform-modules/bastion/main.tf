data "aws_region" "current" {}
data "aws_partition" "current" {}

data "aws_ami" "amazon_linux_2" {
  count = var.ami_id == "" ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2[0].id
}

resource "aws_security_group" "bastion" {
  name_prefix = "${var.name}-bastion-"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-bastion-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "bastion_ssh_ingress_cidr" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.bastion.id
  description       = "Allow SSH from allowed CIDR blocks"
}

resource "aws_security_group_rule" "bastion_ssh_ingress_sg" {
  count = length(var.allowed_security_groups)

  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_groups[count.index]
  security_group_id        = aws_security_group.bastion.id
  description              = "Allow SSH from allowed security groups"
}

resource "aws_security_group_rule" "bastion_egress" {
  count = length(var.egress_rules)

  type              = "egress"
  from_port         = var.egress_rules[count.index].from_port
  to_port           = var.egress_rules[count.index].to_port
  protocol          = var.egress_rules[count.index].protocol
  cidr_blocks       = var.egress_rules[count.index].cidr_blocks
  security_group_id = aws_security_group.bastion.id
  description       = var.egress_rules[count.index].description
}

resource "aws_iam_role" "bastion" {
  name_prefix = "${var.name}-bastion-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  count = var.enable_session_manager ? 1 : 0

  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.bastion.name
}

resource "aws_iam_role_policy" "bastion_logs" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name = "${var.name}-bastion-logs"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:*:log-group:/aws/bastion/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "bastion_eip" {
  count = var.enable_eip ? 1 : 0

  name = "${var.name}-bastion-eip"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:AssociateAddress",
          "ec2:DescribeAddresses"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name_prefix = "${var.name}-bastion-"
  role        = aws_iam_role.bastion.name

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "bastion" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name              = "/aws/bastion/${var.name}"
  retention_in_days = var.cloudwatch_logs_retention

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-bastion-logs"
    }
  )
}

resource "aws_launch_template" "bastion" {
  name_prefix   = "${var.name}-bastion-"
  image_id      = local.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    arn = aws_iam_instance_profile.bastion.arn
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.bastion.id]
    delete_on_termination       = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      encrypted             = var.root_volume_encrypted
      kms_key_id            = var.root_volume_encrypted && var.root_volume_kms_key_id != "" ? var.root_volume_kms_key_id : null
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  user_data = base64encode(templatefile("${path.module}/templates/userdata.sh.tpl", {
    region                 = data.aws_region.current.name
    enable_session_manager = var.enable_session_manager
    enable_cloudwatch_logs = var.enable_cloudwatch_logs
    cloudwatch_log_group   = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.bastion[0].name : ""
    enable_eip             = var.enable_eip
    custom_user_data       = var.user_data
  }))

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.tags,
      {
        Name = "${var.name}-bastion"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      var.tags,
      {
        Name = "${var.name}-bastion"
      }
    )
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "bastion" {
  name_prefix = "${var.name}-bastion-"

  launch_template {
    id      = aws_launch_template.bastion.id
    version = "$Latest"
  }

  vpc_zone_identifier = var.subnet_ids

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  health_check_type         = "EC2"
  health_check_grace_period = 300

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  tag {
    key                 = "Name"
    value               = "${var.name}-bastion"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eip" "bastion" {
  count = var.enable_eip ? var.desired_capacity : 0

  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-bastion-eip-${count.index + 1}"
    }
  )
}
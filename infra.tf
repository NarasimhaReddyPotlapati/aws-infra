resource "aws_vpc" "my_first_vpc" {
  cidr_block = var.cidr_block
  tags = {
    Name = var.my_vpc
  }
}

data "aws_availability_zones" "available" {
    state = "available"
}

resource "aws_subnet" "public_subnet" {
  count = length(var.public_cidr)
  vpc_id  = aws_vpc.my_first_vpc.id
  cidr_block = element(var.public_cidr, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "public subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  count = length(var.private_cidr)
  vpc_id  = aws_vpc.my_first_vpc.id
  cidr_block = element(var.private_cidr, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "private subnet"
  }
}

resource "aws_internet_gateway" "my_gateway" {
  vpc_id = aws_vpc.my_first_vpc.id
  tags = {
    Name = "gateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_first_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_gateway.id
  }
  tags = {
    Name = "route table"
  }
}

resource "aws_route_table_association" "public_route_table_association" {
  count = length(var.public_cidr)
  subnet_id = element(aws_subnet.public_subnet[*].id, count.index)
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_first_vpc.id
  tags = {
    Name = "route table"
  }
}

resource "aws_route_table_association" "private_route_table_association" {
  count = length(var.private_cidr)
  subnet_id = element(aws_subnet.private_subnet[*].id, count.index)
  route_table_id = aws_route_table.private_route_table.id
}

# resource "aws_security_group" "app_security_group" {
#   name = "app_security_group"
#   description = "Security group for EC2 instances hosting web applications."
#   vpc_id = aws_vpc.my_first_vpc.id

// ssh
#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#  // http
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#  // https
#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 4000
#     to_port     = 4000
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"    
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "app_security_group"
#   }
# }

# resource "aws_instance" "my_ec2_instance" {
#   ami           = var.aws-ami
#   instance_type = "t2.micro"
#     subnet_id = aws_subnet.public_subnet[0].id
#     security_groups = [aws_security_group.app_security_group.id]
#     associate_public_ip_address = "true"
#     iam_instance_profile = aws_iam_instance_profile.profile.name
#   root_block_device {
#     volume_size = 50
#     volume_type = "gp2"
#     delete_on_termination = true
#   }

#   user_data = <<EOF
# 		#! /bin/bash
#   echo DATABASE_HOST=${aws_db_instance.db_instance.address} >> /etc/environment
#   echo DATABASE_USERNAME=${aws_db_instance.db_instance.username} >> /etc/environment
#   echo DATABASE_PASSWORD=${aws_db_instance.db_instance.password} >> /etc/environment
#   echo DATABASE_NAME=${aws_db_instance.db_instance.db_name} >> /etc/environment
#   echo NODE_PORT="4000" >> /etc/environment
#   echo DATABASE_PORT=${var.db_port} >> /etc/environment
#   echo S3_BUCKET_NAME=${aws_s3_bucket.private_bucket.bucket} >> /etc/environment
#   sudo systemctl daemon-reload
#   sudo systemctl restart webapp
# 	EOF

#   tags = {
#     Name = "My EC2 Instance"
#   }
# }

# create security group for the database
resource "aws_security_group" "database_security_group" {
  name        = "database security group"
  description = "enable mysql/aurora access on port 3306"
  vpc_id      = aws_vpc.my_first_vpc.id

  ingress {
    description      = "mysql/aurora access"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    security_groups  = [aws_security_group.webapp_security_group.id]
  }

  tags   = {
    Name = "database security group"
  }
}

resource "aws_db_subnet_group" "private_subnet" {
  subnet_ids = aws_subnet.private_subnet[*].id
  name = "database"
}

resource "aws_kms_key" "b" {
  description             = "RDS key 1"
  deletion_window_in_days = 10
}

# create the rds instance
resource "aws_db_instance" "db_instance" {
  engine                  = "mysql"
  engine_version          = "8.0.31"
  multi_az                = "false"
  identifier              = "csye6225"
  username                = "csye6225"
  password                = "Chinna1060"
  instance_class          = "db.t3.micro"
  allocated_storage       = 10
  db_subnet_group_name    = aws_db_subnet_group.private_subnet.name
  vpc_security_group_ids  = [aws_security_group.database_security_group.id]
  db_name                 = "csye6225"
  skip_final_snapshot     = "true"
  storage_encrypted       = "true"
  kms_key_id              = aws_kms_key.b.arn
}

resource "aws_s3_bucket_lifecycle_configuration" "s3" {
  bucket = aws_s3_bucket.private_bucket.id

rule {
    id      = "transition-to-standard-ia"
    status  = "Enabled"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket" "private_bucket" {
  bucket = "private-bucket-${var.environment}-${random_id.random_bucket_suffix.hex}"
  acl    = "private"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "random_id" "random_bucket_suffix" {
  byte_length = 4
}



resource "aws_iam_policy" "webapp_s3_policy" {
  name        = "WebAppS3"
  description = "Allows EC2 instances to perform S3 actions"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.private_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.private_bucket.bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "ec2_csye6225_role" {
  name = "EC2-CSYE6225"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

data "aws_iam_policy" "CloudWatchAgentServerPolicy" {
  arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "EC2-CW" {
  role       = aws_iam_role.ec2_csye6225_role.name
  policy_arn = data.aws_iam_policy.CloudWatchAgentServerPolicy.arn
}

resource "aws_iam_role_policy_attachment" "webapp_s3_policy_attachment" {
  policy_arn = aws_iam_policy.webapp_s3_policy.arn
  role       = aws_iam_role.ec2_csye6225_role.name
}

resource "aws_cloudwatch_log_group" "csye" {
  name = "csye"
}

resource "aws_cloudwatch_log_stream" "foo" {
  name           = "webapp"
  log_group_name = aws_cloudwatch_log_group.csye.name
}

resource "aws_iam_instance_profile" "profile" {
  name = "profile"
  role = aws_iam_role.ec2_csye6225_role.name
}

resource "aws_route53_record" "example" {
  zone_id = "Z0151735I2QGMAPJV9OP"
  name    = "demo.narasimha.me"
  type    = "A"
  alias {
    name = aws_lb.webapp_lb.dns_name
    zone_id = aws_lb.webapp_lb.zone_id
    evaluate_target_health = "true"
  }
}



resource "aws_security_group" "webapp_security_group" {
  name_prefix = "webapp_security_group"

  vpc_id = aws_vpc.my_first_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    security_groups = [aws_security_group.load_balancer_security_group.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks  = ["0.0.0.0/0"]
  }
}



resource "aws_security_group" "load_balancer_security_group" {
  name = "load_balancer_security_group"
  description = "Security group for the load balancer"
  vpc_id = aws_vpc.my_first_vpc.id
  # ingress {
  #   from_port = 80
  #   to_port = 80
  #   protocol = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
  
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks  = ["0.0.0.0/0"]
  }
}

output "load_balancer_security_group_id" {
  value = aws_security_group.load_balancer_security_group.id
}

resource "aws_lb_target_group" "target_group" {
  name = "webapp-tg"
  port = 4000
  protocol = "HTTP"
  vpc_id = aws_vpc.my_first_vpc.id

  health_check {
    enabled = "true"
    interval = 10
    timeout = 5
    healthy_threshold = 2
    unhealthy_threshold = 2
    path = "/healthz"
    matcher = "200"
    port    = 4000
  }
}

resource "aws_lb" "webapp_lb" {
  name = "webapp-lb"
  internal = false
  load_balancer_type = "application"

  subnets = aws_subnet.public_subnet[*].id
  security_groups = [aws_security_group.load_balancer_security_group.id]

  tags = {
    Name = "webapp-lb"
  }
}

# Listener
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.webapp_lb.arn
  port = "443"
  protocol = "HTTPS"

  certificate_arn = "arn:aws:acm:us-east-1:158520471333:certificate/dca3bd6c-5fbf-44cb-91b7-55fb58d18c12"

  default_action {
    target_group_arn = aws_lb_target_group.target_group.arn
    type = "forward"
  }
}


locals {
  user_data_ec2 = <<EOF
 		#! /bin/bash
  echo DATABASE_HOST=${aws_db_instance.db_instance.address} >> /etc/environment
  echo DATABASE_USERNAME=${aws_db_instance.db_instance.username} >> /etc/environment
  echo DATABASE_PASSWORD=${aws_db_instance.db_instance.password} >> /etc/environment
  echo DATABASE_NAME=${aws_db_instance.db_instance.db_name} >> /etc/environment
  echo NODE_PORT="4000" >> /etc/environment
  echo DATABASE_PORT=${var.db_port} >> /etc/environment
  echo S3_BUCKET_NAME=${aws_s3_bucket.private_bucket.bucket} >> /etc/environment
  sudo systemctl daemon-reload
  sudo systemctl restart webapp
 	EOF
}

resource "aws_kms_key" "a" {
  description             = "EBS key 1"
  deletion_window_in_days = 10
}

resource "aws_kms_key_policy" "example" {
  key_id = aws_kms_key.a.id
  policy = jsonencode({
    Id = "key-consolepolicy-1"
    Statement = [
        {
            Sid = "Enable IAM User Permissions",
            Effect = "Allow",
            Principal = {
                AWS = "arn:aws:iam::158520471333:root"
            },
            Action = "kms:*",
            Resource = "*"
        },
        {
            Sid = "Allow use of the key",
            Effect = "Allow",
            Principal = {
                AWS: "arn:aws:iam::158520471333:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
            },
            Action = [
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:DescribeKey"
            ],
            Resource: "*"
        },
        {
            Sid = "Allow attachment of persistent resources",
            Effect = "Allow",
            Principal = {
                AWS: "arn:aws:iam::158520471333:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
            },
            Action =  [
                "kms:CreateGrant",
                "kms:ListGrants",
                "kms:RevokeGrant"
            ],
            Resource = "*",
            Condition = {
                Bool = {
                    "kms:GrantIsForAWSResource": "true"
                }
            }
        }
    ]
    Version = "2012-10-17"
  })
}

# Create a launch template
resource "aws_launch_template" "webapp_launch_template" {
  name = "webapp-launch-template"
  image_id = var.aws-ami
  instance_type = "t2.micro"
  key_name = "ssh"
  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.webapp_security_group.id]
  }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 50
      volume_type = "gp2"
      delete_on_termination = true
      encrypted = "true"
      kms_key_id = aws_kms_key.a.arn
    }
  }
  user_data = base64encode(local.user_data_ec2)

  iam_instance_profile {
    name = aws_iam_instance_profile.profile.name
  }
    tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "web-app-instance"
    }
  }
}


resource "aws_autoscaling_group" "webapp-autoscaling-group" {
  name = "webapp-autoscaling-group"
  min_size = 1
  max_size = 3
  desired_capacity = 1
  default_cooldown = 60
  vpc_zone_identifier = aws_subnet.public_subnet[*].id
  target_group_arns = [aws_lb_target_group.target_group.arn]
launch_template {
    id = aws_launch_template.webapp_launch_template.id
    version = "$Latest"
  }
  tag {
    key = "Name"
    value = "web-server"
    propagate_at_launch = true
  }
  tag {
    key = "AutoScalingGroup"
    value = "true"
    propagate_at_launch = true
  }
}


# AutoScaling Policies
resource "aws_autoscaling_policy" "scale_up_policy" {
  name = "scale_up_policy"
  policy_type = "SimpleScaling"
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = 1
  cooldown = 60
  autoscaling_group_name = aws_autoscaling_group.webapp-autoscaling-group.name
}

resource "aws_autoscaling_policy" "scale_down_policy" {
  name = "scale_down_policy"
  policy_type = "SimpleScaling"
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = -1
  cooldown = 60
  autoscaling_group_name = aws_autoscaling_group.webapp-autoscaling-group.name
}


# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_utilization_scale_up" {
  alarm_name          = "cpu-utilization-scale-up"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "This metric monitors EC2 CPU utilization and scales up when the threshold is exceeded"
  alarm_actions       = [aws_autoscaling_policy.scale_up_policy.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp-autoscaling-group.name
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_scale_down" {
  alarm_name          = "cpu-utilization-scale-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "3"
  alarm_description   = "This metric monitors EC2 CPU utilization and scales down when the threshold is below"
  alarm_actions       = [aws_autoscaling_policy.scale_down_policy.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp-autoscaling-group.name
  }
}


# Application Load Balancer

# Target Group Attachment
resource "aws_autoscaling_attachment" "webapp-autoscaling-group_attachment" {
autoscaling_group_name = aws_autoscaling_group.webapp-autoscaling-group.name
alb_target_group_arn = aws_lb_target_group.target_group.arn
}

output "load_balancer_dns_name" {
value = aws_lb.webapp_lb.dns_name
}
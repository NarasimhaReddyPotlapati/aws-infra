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

resource "aws_security_group" "app_security_group" {
  name = "app_security_group"
  description = "Security group for EC2 instances hosting web applications."
  vpc_id = aws_vpc.my_first_vpc.id

// ssh
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 // http
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 // https
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"    
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app_security_group"
  }
}

resource "aws_instance" "my_ec2_instance" {
  ami           = var.aws-ami
  instance_type = "t2.micro"
    subnet_id = aws_subnet.public_subnet[0].id
    security_groups = [aws_security_group.app_security_group.id]
    associate_public_ip_address = "true"
    iam_instance_profile = aws_iam_instance_profile.profile.name
  root_block_device {
    volume_size = 50
    volume_type = "gp2"
    delete_on_termination = true
  }

  user_data = <<EOF
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

  tags = {
    Name = "My EC2 Instance"
  }
}

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
    security_groups  = [aws_security_group.app_security_group.id]
  }

  tags   = {
    Name = "database security group"
  }
}

resource "aws_db_subnet_group" "private_subnet" {
  subnet_ids = aws_subnet.private_subnet[*].id
  name = "database"
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

resource "aws_iam_role_policy_attachment" "webapp_s3_policy_attachment" {
  policy_arn = aws_iam_policy.webapp_s3_policy.arn
  role       = aws_iam_role.ec2_csye6225_role.name
}

resource "aws_iam_instance_profile" "profile" {
  name = "profile"
  role = aws_iam_role.ec2_csye6225_role.name
}
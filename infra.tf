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

  root_block_device {
    volume_size = 50
    volume_type = "gp2"
    delete_on_termination = true
  }

  tags = {
    Name = "My EC2 Instance"
  }
}
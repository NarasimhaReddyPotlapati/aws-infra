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
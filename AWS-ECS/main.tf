data "aws_availability_zones" "available_zones" {
    state = "available"
}

resource "aws_vpc" "my_vpc" {
    cidr_block = "10.32.0.0/16"
    enable_dns_hostnames = true
    tags = {
      Name = "My VPC"
    }
}

resource "aws_subnet" "public" {
    count = 2
    cidr_block = cidrsubnet(aws_vpc.my_vpc.cidr_block, 8, 2 + count.index)
    availability_zone = data.aws_availability_zones.available_zones.names[count.index]
    vpc_id = aws_vpc.my_vpc.id
    map_public_ip_on_launch = true
    tags = {
      Name = "Public Subnet ap-south-1"
  }
}

resource "aws_subnet" "private" {
    count = 2
    cidr_block = cidrsubnet(aws_vpc.my_vpc.cidr_block, 8, count.index)
    availability_zone = data.aws_availability_zones.available_zones.names[count.index]
    vpc_id = aws_vpc.my_vpc.id
    tags = {
      Name = "Private Subnet ap-south-1"
  }
}

resource "aws_internet_gateway" "my_vpc_igw" {
    vpc_id = aws_vpc.my_vpc.id
    tags = {
      Name = "My VPC - Internet Gateway"
  }
}

resource "aws_route" "internet_access" {
    route_table_id = aws_vpc.my_vpc.main_route_table_id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_vpc_igw.id
}

resource "aws_eip" "gateway" { ## naming confusion
    count = 2
    vpc = true
    depends_on = [aws_internet_gateway.gateway]
}

resource "aws_nat_gateway" "gateway" {
  count         = 2
  subnet_id     = element(aws_subnet.public.*.id, count.index)
  allocation_id = element(aws_eip.gateway.*.id, count.index)
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.gateway.*.id, count.index)
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP Inbound Connections"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP Security Group"
  }
}
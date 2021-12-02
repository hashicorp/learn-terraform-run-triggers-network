provider "aws" {
  region  = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "example" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Project = var.project_tag
  }
}

resource "aws_subnet" "public" {
  count = var.public_subnet_count

  vpc_id     = aws_vpc.example.id
  cidr_block = var.subnet_cidr_blocks[count.index * 2]

  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available)]

  tags = {
    Project = var.project_tag
  }
}

resource "aws_subnet" "private" {
  count = var.private_subnet_count

  vpc_id     = aws_vpc.example.id
  cidr_block = var.subnet_cidr_blocks[(count.index * 2) + 1]

  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available)]

  tags = {
    Project = var.project_tag
  }
}

resource "aws_internet_gateway" "vpc" {
  vpc_id = aws_vpc.example.id

  tags = {
    Project = var.project_tag
  }
}

resource "aws_eip" "nat_gw" {
  vpc = true

  depends_on = [aws_internet_gateway.vpc]

  tags = {
    Project = var.project_tag
  }
}

resource "aws_nat_gateway" "public" {
  allocation_id = aws_eip.nat_gw.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.vpc]

  tags = {
    Project = var.project_tag
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc.id
  }

  tags = {
    Project = var.project_tag
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.public.id
  }

  tags = {
    Project = var.project_tag
  }
}

resource "aws_route_table_association" "public" {
  count = var.public_subnet_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id

}

resource "aws_route_table_association" "private" {
  count = var.private_subnet_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id

}

# Security group

resource "aws_security_group" "public" {
  description = "Allow inbound HTTP/HTTPS traffic"
  vpc_id      = aws_vpc.example.id

  ingress {
    description = "HTTP ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS ingress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP ingress"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project_tag
  }
}

resource "aws_security_group" "private" {
  description = "Allow inbound HTTP/HTTPS traffic from public subnet"
  vpc_id      = aws_vpc.example.id

  ingress {
    description = "HTTP ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"

    cidr_blocks = aws_subnet.public.*.cidr_block
  }

  ingress {
    description = "HTTPS ingress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = aws_subnet.public.*.cidr_block
  }

  ingress {
    description = "ICMP ingress"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = aws_subnet.public.*.cidr_block
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project_tag
  }
}

# Load balancer

resource "aws_lb" "vpc" {
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public.id]
  subnets            = aws_subnet.public.*.id

  tags = {
    Project = var.project_tag
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.vpc.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }

}

## HTTPS support requires an SSL certificate, which is out of scope for this
## example.
#
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.vpc.arn
#   port              = "443"
#   protocol          = "HTTPS"
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.https.arn
#   }
# }

resource "aws_lb_target_group" "http" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.example.id

  target_type = "instance"

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 1800
    enabled         = true
  }

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 10
    path                = "/index.html"
    port                = 80
  }

  tags = {
    Project = var.project_tag
  }
}

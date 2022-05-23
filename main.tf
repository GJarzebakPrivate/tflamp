data "aws_availability_zones" "availability_zones" {
  state = "available"
}

resource "aws_vpc" "myvpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
}

resource "aws_subnet" "myvpc_public_subnet" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.subnet_one_cidr
  availability_zone       = data.aws_availability_zones.availability_zones.names[0]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "myvpc_private_subnet_one" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = element(var.subnet_two_cidr, 0)
  availability_zone = data.aws_availability_zones.availability_zones.names[0]
}


resource "aws_subnet" "myvpc_private_subnet_two" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = element(var.subnet_two_cidr, 1)
  availability_zone = data.aws_availability_zones.availability_zones.names[1]
}


resource "aws_internet_gateway" "myvpc_internet_gateway" {
  vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "myvpc_public_subnet_route_table" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = var.route_table_cidr
    gateway_id = aws_internet_gateway.myvpc_internet_gateway.id
  }
}

resource "aws_route_table" "myvpc_private_subnet_route_table" {
  vpc_id = aws_vpc.myvpc.id
}


resource "aws_default_route_table" "myvpc_main_route_table" {
  default_route_table_id = aws_vpc.myvpc.default_route_table_id

}

resource "aws_route_table_association" "myvpc_public_subnet_route_table" {
  subnet_id      = aws_subnet.myvpc_public_subnet.id
  route_table_id = aws_route_table.myvpc_public_subnet_route_table.id
}

resource "aws_route_table_association" "myvpc_private_subnet_one_route_table_assosiation" {
  subnet_id      = aws_subnet.myvpc_private_subnet_one.id
  route_table_id = aws_route_table.myvpc_private_subnet_route_table.id
}

resource "aws_route_table_association" "myvpc_private_subnet_two_route_table_assosiation" {
  subnet_id      = aws_subnet.myvpc_private_subnet_two.id
  route_table_id = aws_route_table.myvpc_private_subnet_route_table.id
}


resource "aws_security_group" "web_security_group" {
  name        = "web_security_group"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

}

resource "aws_security_group_rule" "web_ingress" {
  count             = length(var.web_ports)
  type              = "ingress"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = element(var.web_ports, count.index)
  to_port           = element(var.web_ports, count.index)
  security_group_id = aws_security_group.web_security_group.id
}


resource "aws_security_group_rule" "web_egress" {
  count             = length(var.web_ports)
  type              = "egress"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = element(var.web_ports, count.index)
  to_port           = element(var.web_ports, count.index)
  security_group_id = aws_security_group.web_security_group.id
}


resource "aws_key_pair" "my_web_instance_key" {
  key_name   = "examplekey"
  public_key = file("./webinstance.pem")
}



resource "aws_instance" "my_web_instance" {
  ami                    = "ami-0d729d2846a86a9e7"
  instance_type          = "t2.micro"
  vpc_security_group_ids = aws_security_group.web_security_group.id
  subnet_id              = aws_subnet.myvpc_public_subnet.id
  key_name               = aws_key_pair.my_web_instance_key.key_name


  provisioner "file" {
    source      = "nginx.sh"
    destination = "/tmp/nginx.sh"
  }
  # Exicuting the nginx.sh file
  # Terraform does not reccomend this method becuase Terraform state file cannot track what the scrip is provissioning
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/nginx.sh",
      "sudo /tmp/nginx.sh"
    ]
  }
  # Setting up the ssh connection to install the nginx server
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file("${var.PRIVATE_KEY_PATH}")
  }
}


resource "aws_autoscaling_group" "my_web_instance_asg" {
  availability_zones = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  desired_capacity   = 2
  max_size           = 3
  min_size           = 1
  load_balancers     = aws_elb.webserverlb.id

  launch_template {
    id      = aws_launch_template.my_web_instance.id
    version = "$Latest"
  }
}


resource "aws_elb" "webserverlb" {
  name               = "webserverlb"
  availability_zones = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  security_groups    = aws_security_group.web_security_group.id


  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 443
    lb_protocol       = "https"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8000/"
    interval            = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400


}
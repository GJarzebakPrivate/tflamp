variable "region" { default = "eu-west-2" }

variable "vpc_cidr" { default = "10.0.0.0/16" }

variable "subnet_one_cidr" { default = "10.0.1.0/24" }

variable "subnet_two_cidr" { default = ["10.0.2.0/24", "10.0.3.0/24"] }

variable "route_table_cidr" { default = "0.0.0.0/0" }

variable "host" { default = "aws_instance.my_web_instance.public_dns" }

variable "web_ports" { default = ["22", "80", "443", "3306"] }

variable "db_ports" { default = ["22", "3306"] }

variable "images" {
  default = "ami-0d729d2846a86a9e7"

}
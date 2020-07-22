# VARIABLES

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "key_name" {}
variable "region" {
    default = "eu-central-1"
}
variable "network_address_space" {
    default = "10.0.0.0/16"
}
variable "subnet1_address_space" {
    default = "10.0.0.0/24"
}

# PROVIDERS

provider "aws" {
    access_key = var.aws_access_key
    secret_key = var.aws_secret_key
    region = var.region
}   

# DATA

data "aws_availability_zones" "available" {}

data "aws_ami" "ami-05ed630909bef2ec5" {
    most_recent = true
    owners = ["amazon"]


    filter {
        name = "name"
        values = ["amzn-ami-hvm*"]
    }
    
    filter {
        name = "root-device-type"
        values = ["ebs"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

# RESOURCES

# Networking

resource "aws_vpc" "vpc" {
    cidr_block = var.network_address_space
    enable_dns_hostnames = "true"
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "subnet1" {
    cidr_block = var.subnet1_address_space
    vpc_id = aws_vpc.vpc.id
    map_public_ip_on_launch ="true"
    availability_zone = data.aws_availability_zones.available.names[0]
}

# Routing

resource "aws_route_table" "rtb" {
    vpc_id = aws_vpc.vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
}

resource "aws_route_table_association" "rta-subnet" {
    subnet_id = aws_subnet.subnet1.id
    route_table_id = aws_route_table.rtb.id
}

# Security Groups

# Nginx security group

resource "aws_security_group" "web-sg" {
    name = "web_sg"
    vpc_id = aws_vpc.vpc.id


# RDP access from anywhere

    ingress {
        from_port = 3389
        to_port = 3389
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

# HTTP access from anywhere

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

# Outbound internet access

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# INSTANCES

resource "aws_instance" "web" {
    ami = "ami-05ed630909bef2ec5"
    instance_type = "t2.micro"
    subnet_id = aws_subnet.subnet1.id
    vpc_security_group_ids = [aws_security_group.web-sg.id]
    key_name = var.key_name

    connection {
        type = "rdp"
        host = self.public_ip
        user = "ec2-user"
        private_key = file(var.private_key_path)
    }
}

# OUTPUT

output "aws_instance_public_dns" {
    value = aws_instance.web.public_dns
}

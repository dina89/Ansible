provider "aws" {
    region = var.aws_region
}

data "aws_subnet_ids" "subnets" {
    vpc_id = aws_default_vpc.default.id
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "tls_private_key" "server_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "server_key" {
  key_name   = "server_key"
  public_key = "${tls_private_key.server_key.public_key_openssh}"
}

resource "aws_security_group" "ansible-sg" {
 name        = "ansible-sg"
 description = "security group for ansible servers"
 vpc_id      = aws_default_vpc.default.id
  egress {
   from_port   = 0
   to_port     = 0
   protocol    = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }

  dynamic "ingress" {
    iterator = port
    for_each = var.ingress_ports
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  ingress {
   from_port   = 8
   to_port     = 0
   protocol    = "icmp"
   cidr_blocks = ["0.0.0.0/0"]
 }
}

resource "aws_default_vpc" "default"{

}

resource "aws_instance" "server" {
  count = 1

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.ansible-sg.id]
  key_name               = aws_key_pair.ansible_key.key_name

  depends_on = [
     null_resource.hosts_nodes
  ]

  connection {
      type = "ssh"
      host = self.public_ip
      user = "ubuntu"
      private_key = tls_private_key.ansible_key.private_key_pem
  }

  provisioner "file" {
    source      = "ansible.pem"
    destination = "/tmp/ansible.pem"
  }

  provisioner "file" {
    source      = "docker_playbook.yml"
    destination = "docker_playbook.yml"
  }

  provisioner "file" {
    source      = "hosts"
    destination = "hosts"
  }

  provisioner "file" {
    source      = "docker-role"
    destination = "docker-role"
  }

  provisioner "remote-exec"{
      inline = [
          "sudo apt update",
          "sudo apt install software-properties-common -y",
          "sudo apt-add-repository --yes --update ppa:ansible/ansible",
          "sudo apt install ansible -y",
          "chmod 600 /tmp/ansible.pem",
          "ansible-playbook -i hosts docker_playbook.yml --private-key=/tmp/ansible.pem"
      ]
  }

  tags = {
    Name = "Server"
  }
}

resource "aws_instance" "nodes-ubuntu" {
  count =2 

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.ansible-sg.id]
  key_name               = aws_key_pair.ansible_key.key_name

  tags = {
    Name = "NodeUbuntu${count.index}"
  }
}

resource "aws_instance" "nodes-redhat" {
  count =1

  ami           = "ami-0c322300a1dd5dc79"
  instance_type = "t2.micro"

  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.ansible-sg.id]
  key_name               = aws_key_pair.ansible_key.key_name

  tags = {
    Name = "NodeRedHat${count.index}"
  }
}

data "template_file" "hosts_nodes" {
  template = "${file("${path.module}/docker-role/templates/hosts.cfg")}"
  depends_on = [
    aws_instance.nodes-ubuntu,
    aws_instance.nodes-redhat
  ]
  vars = {
    api_ubuntu = join("\n", aws_instance.nodes-ubuntu.*.public_ip)
    api_redhat = join("\n", aws_instance.nodes-redhat.*.public_ip)
  }
}

resource "null_resource" "hosts_nodes" {
  triggers = {
    template_rendered = data.template_file.hosts_nodes.rendered
  }
  provisioner "local-exec" {
    command = "Set-Content -Path 'hosts' -Value '${data.template_file.hosts_nodes.rendered}'"
    interpreter = ["PowerShell", "-Command"]
  }
}
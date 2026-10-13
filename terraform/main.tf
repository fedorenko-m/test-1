data "aws_ami" "ubuntu" {
    most_recent = true
    owners      = ["099720109477"] # Canonical

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    }
}

resource "aws_key_pair" "deploy" {
    key_name   = "hello-nginx-deploy"
    public_key = var.deploy_public_key
}

resource "aws_security_group" "web" {
    name        = "hello-nginx-web"
    description = "HTTP for everyone, SSH for the allowed CIDR"

    ingress {
        description = "HTTP"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "SSH"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = [var.ssh_allowed_cidr]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "web" {
    ami                    = data.aws_ami.ubuntu.id
    instance_type          = var.instance_type
    key_name               = aws_key_pair.deploy.key_name
    vpc_security_group_ids = [aws_security_group.web.id]

    user_data = templatefile("${path.module}/user_data.sh.tftpl", {
        deploy_public_key = var.deploy_public_key
    })

    tags = {
        Name = "hello-nginx-test"
    }
}

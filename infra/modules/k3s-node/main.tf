# A single EC2 instance running k3s (lightweight Kubernetes).
# Chosen over EKS to avoid the ~$73/month EKS control-plane fee - see README "Design decisions".

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "this" {
  key_name   = "${var.name}-key"
  public_key = var.ssh_public_key
}

resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "k3s node: SSH and Kubernetes API from admin IP only, HTTP/HTTPS from anywhere"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.this.id
  description       = "SSH from admin IP"
  cidr_ipv4         = var.allowed_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "k8s_api" {
  security_group_id = aws_security_group.this.id
  description       = "Kubernetes API from admin IP"
  cidr_ipv4         = var.allowed_cidr
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.this.id
  description       = "HTTP to the ingress controller"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.this.id
  description       = "HTTPS to the ingress controller"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Stable public IP: survives instance stop/start, and is baked into the k3s API certificate.
resource "aws_eip" "this" {
  domain = "vpc"
  tags   = { Name = "${var.name}-eip" }
}

resource "aws_instance" "this" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  key_name               = aws_key_pair.this.key_name

  user_data                   = templatefile("${path.module}/user_data.sh.tftpl", { public_ip = aws_eip.this.public_ip })
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required" # enforce IMDSv2
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_gb
    encrypted   = true
  }

  tags = { Name = var.name }
}

resource "aws_eip_association" "this" {
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this.id
}

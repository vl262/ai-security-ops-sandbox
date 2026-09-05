# Nejnovější Amazon Linux 2023 AMI (minimalizuje neopravené zranitelnosti
# na "čisté" instanci, i když je to honeypot a útoky čekáme na síťové
# úrovni, ne na aplikační).
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security group — jediné pravidlo dovnitř (SSH), nic víc.
# Tohle JE ta návnada — port 22 otevřený světu.
resource "aws_security_group" "honeypot" {
  name        = "vl-honeypot-sg"
  description = "Honeypot SG - pouze SSH ingress z internetu, zadna jina pravidla"
  vpc_id      = aws_vpc.honeypot.id

  ingress {
    description = "SSH - zamerne otevrene pro honeypot ucel"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ingress_cidr]
  }

  egress {
    description = "Allow all outbound - chceme videt vychozi komunikaci v GuardDuty"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "vl-honeypot-sg"
    Purpose = "honeypot"
    Owner   = var.owner_tag
  }
}

# EC2 instance — žádný key pair (key_name se neuvádí = žádný SSH klíč
# nainstalovaný, útočník se tedy nemůže přihlásit ani náhodou), žádná
# IAM role (iam_instance_profile se neuvádí = nulová AWS API oprávnění
# i v případě kompromitace).
resource "aws_instance" "honeypot" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids     = [aws_security_group.honeypot.id]
  associate_public_ip_address = true

  # Bez key_name — instance nemá nastavený žádný SSH přístupový klíč.
  # Bez iam_instance_profile — instance nemá žádná AWS API oprávnění.

  # OS-level auto-shutdown jako bezpečnostní pojistka navíc k Budgets
  # alertům. Pozor: shutdown = instance přejde do stavu "stopped",
  # NE "terminated" — EBS volume dál existuje a generuje malé náklady.
  # Pro úplné smazání použij `terraform destroy`.
  user_data = <<-EOF
    #!/bin/bash
    shutdown -h +${var.auto_shutdown_minutes}
  EOF

  tags = {
    Name    = "vl-honeypot"
    Purpose = "honeypot"
    Owner   = var.owner_tag
  }
}

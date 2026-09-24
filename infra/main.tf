provider "aws" {
  region = "us-east-1"
}

# Frontend: reachable from anywhere on the app port, SSH from anywhere too
resource "aws_security_group" "frontend" {
  name        = "sentinel-frontend"
  description = "Sentinel frontend - web + ssh"

  ingress {
    description = "Frontend app"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Backend: API port only reachable from the frontend SG, plus SSH
resource "aws_security_group" "backend" {
  name        = "sentinel-backend"
  description = "Sentinel backend API - only frontend can reach it, plus ssh"

  ingress {
    description = "Backend API from anywhere (browser calls it directly)"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS: only the backend can reach Postgres, nothing else
resource "aws_security_group" "rds" {
  name        = "sentinel-rds"
  description = "Sentinel RDS - only backend can reach it"

  ingress {
    description     = "Postgres from backend only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "sentinel" {
  identifier             = "sentinel-db"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "sentinel_db"
  username               = "sentinel"
  password               = var.db_password
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = {
    Name = "sentinel-db"
  }
}

output "rds_endpoint" {
  value = aws_db_instance.sentinel.endpoint
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# AWS Academy Learner Lab blocks creating IAM roles/instance profiles, so we
# reuse the one it already provides rather than create a new one.
data "aws_iam_instance_profile" "lab" {
  name = "LabInstanceProfile"
}

# The "further managed service" for this app: publishing here is triggered
# by real application logic (creating a Critical-severity vulnerability),
# not just a resource sitting unused.
resource "aws_sns_topic" "alerts" {
  name = "sentinel-alerts"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_instance" "backend" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  key_name                    = "vockey"
  vpc_security_group_ids      = [aws_security_group.backend.id]
  iam_instance_profile        = data.aws_iam_instance_profile.lab.name
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/backend-user-data.sh.tpl", {
    db_password   = var.db_password
    rds_endpoint  = aws_db_instance.sentinel.endpoint
    rds_host      = aws_db_instance.sentinel.address
    sns_topic_arn = aws_sns_topic.alerts.arn
  })

  tags = {
    Name = "sentinel-backend"
  }
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "backend_public_ip" {
  value = aws_instance.backend.public_ip
}

output "backend_public_dns" {
  value = aws_instance.backend.public_dns
}

resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = "vockey"
  vpc_security_group_ids = [aws_security_group.frontend.id]
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/frontend-user-data.sh.tpl", {
    backend_ip = aws_instance.backend.public_ip
  })

  tags = {
    Name = "sentinel-frontend"
  }
}

output "frontend_public_ip" {
  value = aws_instance.frontend.public_ip
}
# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "monitoring-level4-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "monitoring-level4-igw"
  }
}

# Subnet Pública
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "monitoring-level4-public-subnet"
  }
}

# Availability Zones disponíveis
data "aws_availability_zones" "available" {
  state = "available"
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "monitoring-level4-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group para EC2
resource "aws_security_group" "monitoring" {
  name        = "monitoring-level4-sg"
  description = "Security Group para stack de monitoramento Level 4"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_ips
    description = "SSH"
  }

  # Grafana
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Grafana"
  }

  # Zabbix Web
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Zabbix Web Interface"
  }

  # Prometheus
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Prometheus"
  }

  # Egress - permitir tudo
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "monitoring-level4-sg"
  }
}

# AMI Ubuntu 22.04
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance
resource "aws_instance" "monitoring" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.ec2_instance_type
  key_name      = var.ec2_key_name
  subnet_id     = aws_subnet.public.id
  
  # IAM Instance Profile para acessar Secrets Manager
  iam_instance_profile = aws_iam_instance_profile.monitoring.name
  
  vpc_security_group_ids = [aws_security_group.monitoring.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
    tags = {
      Name = "monitoring-level4-root"
    }
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Redirecionar output para log
              exec > >(tee /var/log/user-data.log)
              exec 2>&1
              
              echo "============================================"
              echo "Monitoring Level 4 - Setup com Secrets Manager"
              echo "============================================"
              
              # Atualizar sistema
              echo "[1/8] Atualizando sistema..."
              apt-get update
              DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
              
              # Instalar dependências
              echo "[2/8] Instalando dependências..."
              apt-get install -y \
                docker.io \
                docker-compose \
                awscli \
                jq \
                mysql-client \
                git \
                curl \
                wget \
                vim \
                htop
              
              systemctl enable docker
              systemctl start docker
              usermod -aG docker ubuntu
              
              # Criar diretório
              mkdir -p /home/ubuntu/monitoring
              chown ubuntu:ubuntu /home/ubuntu/monitoring
              
              echo "[3/8] Aguardando AWS Secrets Manager estar disponível..."
              sleep 10
              
              # Buscar secrets do Secrets Manager
              echo "[4/8] Buscando MySQL Root Password..."
              MYSQL_ROOT_PASS=$(aws secretsmanager get-secret-value \
                --secret-id monitoring/mysql-root-password \
                --region ${var.aws_region} \
                --query SecretString \
                --output text)
              
              echo "[5/8] Buscando MySQL User Credentials..."
              MYSQL_CREDS=$(aws secretsmanager get-secret-value \
                --secret-id monitoring/mysql-credentials \
                --region ${var.aws_region} \
                --query SecretString \
                --output text)
              
              MYSQL_USER=$(echo "$MYSQL_CREDS" | jq -r '.username')
              MYSQL_PASS=$(echo "$MYSQL_CREDS" | jq -r '.password')
              MYSQL_DB=$(echo "$MYSQL_CREDS" | jq -r '.database')
              
              echo "[6/8] Buscando Grafana Admin Credentials..."
              GRAFANA_CREDS=$(aws secretsmanager get-secret-value \
                --secret-id monitoring/grafana-credentials \
                --region ${var.aws_region} \
                --query SecretString \
                --output text)
              
              GRAFANA_USER=$(echo "$GRAFANA_CREDS" | jq -r '.username')
              GRAFANA_PASS=$(echo "$GRAFANA_CREDS" | jq -r '.password')
              
              echo "[7/8] Criando .env com secrets..."
              # Criar .env com secrets
              cat > /home/ubuntu/monitoring/.env << 'ENVEOF'
# ======================================
# MONITORING SECURITY LEVEL 4 - AWS SECRETS MANAGER
# ======================================
# Credenciais gerenciadas pelo AWS Secrets Manager
# Senhas geradas automaticamente (32 caracteres alfanuméricos)

# ======================================
# CONFIGURAÇÕES DO MYSQL
# ======================================
MYSQL_VERSION=8.3
MYSQL_DATABASE=MYSQL_DB_PLACEHOLDER
MYSQL_USER=MYSQL_USER_PLACEHOLDER
MYSQL_PASSWORD=MYSQL_PASS_PLACEHOLDER
MYSQL_ROOT_PASSWORD=MYSQL_ROOT_PASS_PLACEHOLDER

# ======================================
# CONFIGURAÇÕES DO ZABBIX
# ======================================
ZABBIX_VERSION=alpine-7.0.5
ZABBIX_SERVER_HOST=zabbix-server

# Configurações de Performance do Zabbix
ZBX_STARTPOLLERS=5
ZBX_STARTPINGERS=1
ZBX_STARTUNREACHABLE=1
ZBX_STARTSNMPPOLLERS=1
ZBX_STARTTRAPPERS=5
ZBX_STARTDBSYNCERS=4
ZBX_TIMEOUT=4
ZBX_VALUECACHESIZE=8M
ZBX_HISTORYCACHESIZE=16M
ZBX_HISTORYINDEXCACHESIZE=4M
ZBX_CACHESIZE=128M
ZBX_TRENDCACHESIZE=4M

# Configurações Web
PHP_TZ=America/Sao_Paulo

# ======================================
# CONFIGURAÇÕES DO GRAFANA
# ======================================
GRAFANA_VERSION=12.0.2-security-01-ubuntu
GRAFANA_ADMIN_USER=GRAFANA_USER_PLACEHOLDER
GRAFANA_ADMIN_PASSWORD=GRAFANA_PASS_PLACEHOLDER

# ======================================
# CONFIGURAÇÕES DO PROMETHEUS
# ======================================
PROMETHEUS_VERSION=latest

# ======================================
# CONFIGURAÇÕES DE TIMEZONE
# ======================================
TZ=America/Sao_Paulo
ENVEOF
              
              # Substituir placeholders com valores reais
              sed -i "s/MYSQL_DB_PLACEHOLDER/$MYSQL_DB/g" /home/ubuntu/monitoring/.env
              sed -i "s/MYSQL_USER_PLACEHOLDER/$MYSQL_USER/g" /home/ubuntu/monitoring/.env
              sed -i "s/MYSQL_PASS_PLACEHOLDER/$MYSQL_PASS/g" /home/ubuntu/monitoring/.env
              sed -i "s/MYSQL_ROOT_PASS_PLACEHOLDER/$MYSQL_ROOT_PASS/g" /home/ubuntu/monitoring/.env
              sed -i "s/GRAFANA_USER_PLACEHOLDER/$GRAFANA_USER/g" /home/ubuntu/monitoring/.env
              sed -i "s/GRAFANA_PASS_PLACEHOLDER/$GRAFANA_PASS/g" /home/ubuntu/monitoring/.env
              
              chown ubuntu:ubuntu /home/ubuntu/monitoring/.env
              chmod 600 /home/ubuntu/monitoring/.env
              
              echo "[8/8] Servidor configurado!"
              echo "✅ Servidor pronto! Aguardando deploy dos containers..." > /home/ubuntu/status.txt
              echo "✅ Secrets Manager configurado!" >> /home/ubuntu/status.txt
              echo "✅ .env criado com senhas seguras!" >> /home/ubuntu/status.txt
              
              echo "============================================"
              echo "Setup concluído com sucesso!"
              echo "============================================"
              EOF

  tags = {
    Name  = "monitoring-level4-server"
    Level = "4"
  }
  
  depends_on = [
    aws_secretsmanager_secret_version.mysql_root_password,
    aws_secretsmanager_secret_version.mysql_credentials,
    aws_secretsmanager_secret_version.grafana_credentials
  ]
}

# Elastic IP
resource "aws_eip" "monitoring" {
  instance = aws_instance.monitoring.id
  domain   = "vpc"

  tags = {
    Name = "monitoring-level4-eip"
  }
}

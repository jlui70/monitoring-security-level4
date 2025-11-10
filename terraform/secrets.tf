# =============================================================================
# AWS Secrets Manager - Credenciais seguras
# =============================================================================
# 
# IMPORTANTE: Senhas SEM caracteres especiais problemáticos
# Apenas: a-z, A-Z, 0-9, - (hífen), _ (underscore)
# =============================================================================


# -----------------------------------------------------------------------------
# Random Passwords - SEM caracteres especiais problemáticos
# -----------------------------------------------------------------------------

resource "random_password" "mysql_root_password" {
  length  = 32
  special = false  # Apenas letras e números (mais seguro para automação)
  
  lifecycle {
    ignore_changes = [
      length,
      special,
    ]
  }
}

resource "random_password" "mysql_user_password" {
  length  = 32
  special = false
}

resource "random_password" "grafana_admin_password" {
  length  = 24
  special = false
}

# -----------------------------------------------------------------------------
# Secrets Manager - MySQL Root Password
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "mysql_root_password" {
  name                    = "monitoring/mysql-root-password"
  description             = "MySQL root password for monitoring stack"
  kms_key_id              = aws_kms_key.secrets.id
  recovery_window_in_days = 0
  
  tags = {
    Name        = "monitoring-mysql-root-password"
    Application = "monitoring"
    Level       = "4"
  }
}

resource "aws_secretsmanager_secret_version" "mysql_root_password" {
  secret_id = aws_secretsmanager_secret.mysql_root_password.id
  secret_string = jsonencode({
    password = random_password.mysql_root_password.result
  })
}

# -----------------------------------------------------------------------------
# Secrets Manager - MySQL User Credentials (JSON)
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "mysql_credentials" {
  name                    = "monitoring/mysql-credentials"
  description             = "MySQL user credentials for Zabbix"
  kms_key_id              = aws_kms_key.secrets.id
  recovery_window_in_days = 0
  
  tags = {
    Name        = "monitoring-mysql-credentials"
    Application = "monitoring"
    Level       = "4"
  }
}

resource "aws_secretsmanager_secret_version" "mysql_credentials" {
  secret_id = aws_secretsmanager_secret.mysql_credentials.id
  secret_string = jsonencode({
    username = "zabbix"
    password = random_password.mysql_user_password.result
    database = "zabbix"
  })
}

# -----------------------------------------------------------------------------
# Secrets Manager - Grafana Admin Credentials (JSON)
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "grafana_credentials" {
  name                    = "monitoring/grafana-credentials"
  description             = "Grafana admin credentials"
  kms_key_id              = aws_kms_key.secrets.id
  recovery_window_in_days = 0
  
  tags = {
    Name        = "monitoring-grafana-credentials"
    Application = "monitoring"
    Level       = "4"
  }
}

resource "aws_secretsmanager_secret_version" "grafana_credentials" {
  secret_id = aws_secretsmanager_secret.grafana_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.grafana_admin_password.result
  })
}

# -----------------------------------------------------------------------------
# Random Password - Zabbix Admin
# -----------------------------------------------------------------------------

resource "random_password" "zabbix_admin_password" {
  length  = 24
  special = false
}

# -----------------------------------------------------------------------------
# Secrets Manager - Zabbix Admin Credentials
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "zabbix_admin_credentials" {
  name                    = "monitoring/zabbix-admin-credentials"
  description             = "Zabbix admin credentials for monitoring stack"
  kms_key_id              = aws_kms_key.secrets.id
  recovery_window_in_days = 0
  
  tags = {
    Name        = "monitoring-zabbix-admin-credentials"
    Application = "monitoring"
    Level       = "4"
  }
}

resource "aws_secretsmanager_secret_version" "zabbix_admin_credentials" {
  secret_id = aws_secretsmanager_secret.zabbix_admin_credentials.id
  secret_string = jsonencode({
    username = "Admin"
    password = random_password.zabbix_admin_password.result
  })
}

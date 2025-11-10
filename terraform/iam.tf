# =============================================================================
# IAM Role para EC2 acessar AWS Secrets Manager
# =============================================================================

# IAM Role que a instância EC2 assume
resource "aws_iam_role" "ec2_secrets_access" {
  name = "monitoring-ec2-secrets-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "monitoring-ec2-secrets-access"
    Application = "monitoring"
  }
}

# Policy que permite acessar os secrets
resource "aws_iam_role_policy" "secrets_manager_access" {
  name = "secrets-manager-access"
  role = aws_iam_role.ec2_secrets_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.mysql_root_password.arn,
          aws_secretsmanager_secret.mysql_credentials.arn,
          aws_secretsmanager_secret.grafana_credentials.arn,
          aws_secretsmanager_secret.zabbix_admin_credentials.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.secrets.arn
      }
    ]
  })
}

# Instance Profile para anexar a role à EC2
resource "aws_iam_instance_profile" "monitoring" {
  name = "monitoring-instance-profile"
  role = aws_iam_role.ec2_secrets_access.name

  tags = {
    Name        = "monitoring-instance-profile"
    Application = "monitoring"
  }
}

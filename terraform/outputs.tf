output "instance_id" {
  description = "ID da instância EC2"
  value       = aws_instance.monitoring.id
}

output "public_ip" {
  description = "IP público (Elastic IP)"
  value       = aws_eip.monitoring.public_ip
}

output "ssh_command" {
  description = "Comando SSH para acessar o servidor"
  value       = "ssh -i ~/ssh/${var.ec2_key_name}.pem ubuntu@${aws_eip.monitoring.public_ip}"
}

output "zabbix_url" {
  description = "URL do Zabbix Web"
  value       = "http://${aws_eip.monitoring.public_ip}:8080"
}

output "grafana_url" {
  description = "URL do Grafana"
  value       = "http://${aws_eip.monitoring.public_ip}:3000"
}

output "prometheus_url" {
  description = "URL do Prometheus"
  value       = "http://${aws_eip.monitoring.public_ip}:9090"
}

output "secrets_info" {
  description = "Informações dos secrets criados"
  value = {
    mysql_root_password_arn = aws_secretsmanager_secret.mysql_root_password.arn
    mysql_credentials_arn   = aws_secretsmanager_secret.mysql_credentials.arn
    grafana_credentials_arn = aws_secretsmanager_secret.grafana_credentials.arn
  }
  sensitive = true
}

output "kms_key_id" {
  description = "ID da chave KMS usada para criptografia"
  value       = aws_kms_key.secrets.id
  sensitive   = true
}

output "grafana_credentials" {
  description = "Credenciais do Grafana (CUIDADO: sensível!)"
  value = {
    username = "admin"
    password = random_password.grafana_admin_password.result
  }
  sensitive = true
}

output "mysql_credentials" {
  description = "Credenciais do MySQL (CUIDADO: sensível!)"
  value = {
    root_password = random_password.mysql_root_password.result
    user          = "zabbix"
    password      = random_password.mysql_user_password.result
    database      = "zabbix"
  }
  sensitive = true
}

output "next_steps" {
  description = "Próximos passos"
  value       = <<-EOT
  
  ====================================
  ✅ Infraestrutura criada com sucesso!
  ====================================
  
  🔐 LEVEL 4: AWS Secrets Manager
  
  Recursos criados:
  • VPC e Subnet
  • EC2 t3.medium com IAM Role
  • 3 Secrets no Secrets Manager
  • KMS Key para criptografia
  • Elastic IP
  
  Próximos passos:
  
  1. Aguardar ~2 minutos para o servidor inicializar
  
  2. Executar o script de deploy:
     cd /home/luiz7/monitoring-security-level4-aws-v2
     ./deploy.sh ${aws_eip.monitoring.public_ip}
  
  3. Acessar as interfaces:
     - Zabbix:     http://${aws_eip.monitoring.public_ip}:8080
     - Grafana:    http://${aws_eip.monitoring.public_ip}:3000
     - Prometheus: http://${aws_eip.monitoring.public_ip}:9090
  
  4. Ver credenciais:
     terraform output grafana_credentials
     terraform output mysql_credentials
  
  🔐 Segurança:
  • Senhas aleatórias 32 caracteres (apenas alfanuméricos)
  • Criptografadas com KMS
  • Auditadas via CloudTrail
  • Não aparecem em logs
  
  EOT
}

# =============================================================================
# Zabbix Credentials
# =============================================================================

output "zabbix_credentials" {
  description = "Zabbix admin credentials from AWS Secrets Manager"
  sensitive   = true
  value = {
    username    = "Admin"
    password    = random_password.zabbix_admin_password.result
    secret_arn  = aws_secretsmanager_secret.zabbix_admin_credentials.arn
    url         = "http://${aws_eip.monitoring.public_ip}:8080"
    note        = "Username is case-sensitive: 'Admin' (capital A)"
  }
}

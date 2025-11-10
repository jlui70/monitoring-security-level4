# =============================================================================
# KMS Key para criptografia dos Secrets
# =============================================================================

resource "aws_kms_key" "secrets" {
  description             = "KMS key for monitoring secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "monitoring-secrets-key"
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/monitoring-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

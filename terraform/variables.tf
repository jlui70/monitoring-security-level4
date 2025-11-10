variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "ec2_instance_type" {
  description = "EC2 Instance Type"
  type        = string
  default     = "t3.medium"
}

variable "ec2_key_name" {
  description = "Nome da chave SSH já existente na AWS"
  type        = string
}

variable "allowed_ssh_ips" {
  description = "IPs permitidos para SSH (0.0.0.0/0 = qualquer IP)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Quick Start Guide

Este guia passo a passo mostra como fazer o deploy do projeto do zero.

## 1️⃣ Preparação

### Clone o repositório
```bash
git clone https://github.com/YOUR_USERNAME/monitoring-security-level4-aws-v2.git
cd monitoring-security-level4-aws-v2
```

### Configure a AWS CLI
```bash
aws configure
# AWS Access Key ID: YOUR_KEY
# AWS Secret Access Key: YOUR_SECRET
# Default region: us-east-1
# Default output format: json
```

### Crie um Key Pair na AWS
1. Acesse EC2 Console → Key Pairs
2. Create Key Pair
3. Nome: `devops-key` (ou outro de sua escolha)
4. Type: RSA
5. Format: .pem
6. Download e salve em local seguro
7. Configure permissões: `chmod 400 ~/path/to/devops-key.pem`

## 2️⃣ Configuração

### Configure as variáveis do Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edite `terraform.tfvars`:
```hcl
aws_region         = "us-east-1"
ec2_instance_type  = "t3.medium"
ec2_key_name       = "devops-key"  # Nome do seu key pair
allowed_ssh_ips    = ["YOUR_IP/32"]  # Seu IP público
```

**Dica:** Para descobrir seu IP público:
```bash
curl ifconfig.me
```

## 3️⃣ Deploy da Infraestrutura

### Inicialize o Terraform
```bash
terraform init
```

### Visualize o plano
```bash
terraform plan
```

### Aplique as mudanças
```bash
terraform apply
```

Digite `yes` quando solicitado.

**Aguarde ~3 minutos.** Você verá:
```
Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

Outputs:

grafana_url = "http://54.123.45.67:3000"
public_ip = "54.123.45.67"
zabbix_url = "http://54.123.45.67:8080"
```

**Importante:** Anote o `public_ip`!

## 4️⃣ Deploy dos Containers

### Aguarde o servidor inicializar
```bash
sleep 120
```

### Execute o script de deploy
```bash
cd ..  # Volta para a raiz do projeto
./deploy.sh 54.123.45.67  # Use o IP do output anterior
```

**Aguarde ~8 minutos.** O script irá:
- ✅ Testar conexão SSH
- ✅ Copiar arquivos de configuração
- ✅ Iniciar containers Docker
- ✅ Configurar Zabbix
- ✅ Importar dashboards Grafana

## 5️⃣ Acesse as Aplicações

### Obtenha as credenciais
```bash
cd terraform
terraform output grafana_credentials
```

### Zabbix
```
URL: http://54.123.45.67:8080
User: Admin
Password: [veja no output terraform]
```

### Grafana
```
URL: http://54.123.45.67:3000
User: admin
Password: [veja no output terraform]
```

### Prometheus
```
URL: http://54.123.45.67:9090
No authentication required
```

## 6️⃣ Verificação

### Execute o smoke test
```bash
./smoke-test.sh 54.123.45.67
```

Deve mostrar:
- ✅ SSH Connection
- ✅ Zabbix Web
- ✅ Grafana
- ✅ Prometheus
- ✅ All services operational

## 7️⃣ Limpeza (Opcional)

### Destruir todos os recursos
```bash
cd terraform
terraform destroy
```

Digite `yes` quando solicitado.

**Importante:** Isso deletará:
- EC2 instance
- VPC e recursos de rede
- Secrets Manager secrets (recovery window de 7 dias)
- KMS Key
- Todos os dados

---

## 🆘 Troubleshooting

### Erro: "Connection timeout"
- Verifique se seu IP está em `allowed_ssh_ips`
- Verifique se a instância EC2 está rodando
- Verifique o Security Group no AWS Console

### Erro: "Permission denied (publickey)"
- Verifique se está usando a chave correta: `ssh -i ~/path/to/key.pem ubuntu@IP`
- Verifique permissões da chave: `chmod 400 ~/path/to/key.pem`

### Containers não iniciam
- SSH na instância: `ssh -i ~/path/to/key.pem ubuntu@IP`
- Verifique logs: `docker-compose logs`
- Verifique .env: `cat monitoring/.env`

### Precisa de ajuda?
Abra uma [Issue no GitHub](https://github.com/YOUR_USERNAME/monitoring-security-level4-aws-v2/issues)

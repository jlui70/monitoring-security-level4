# 🔐 Monitoring Security Level 4 - AWS Secrets Manager

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Terraform](https://img.shields.io/badge/Terraform-1.0+-623CE4?logo=terraform)
![AWS](https://img.shields.io/badge/AWS-Secrets_Manager-FF9900?logo=amazon-aws)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)
![Zabbix](https://img.shields.io/badge/Zabbix-7.0.5-CC0000?logo=zabbix)
![Grafana](https://img.shields.io/badge/Grafana-12.0.2-F46800?logo=grafana)
![Prometheus](https://img.shields.io/badge/Prometheus-2.48.1-E6522C?logo=prometheus)

**Cloud-native monitoring stack** com AWS Secrets Manager para gerenciamento seguro de credenciais na AWS Cloud, com KMS encryption, IAM roles, e auditoria via CloudTrail.

> 🎯 **Posição na Série:** Este é o **Level 4** de 5 na evolução de segurança  
> 📈 **Evolução:** Level 3 (HashiCorp Vault) → **Level 4 (AWS Secrets Manager)** → Level 5 (K8s + Vault)

---

## 📚 Índice

- [Evolução vs Level 3](#-evolução-vs-level-3)
- [Características](#-características)
- [Arquitetura](#️-arquitetura)
- [Pré-requisitos](#-pré-requisitos)
- [Deploy Completo](#-deploy-completo-3-passos)
- [Quick Start Guide](QUICKSTART.md) 👈 **Guia passo a passo detalhado**
- [Acessar Aplicações](#-acessar-aplicações)
- [Segurança](#-segurança)
- [Custos](#-custos)
- [Série Completa](#-série-monitoring-security)
- [Troubleshooting](#-troubleshooting)
- [Contribuindo](#-contribuindo)

---

## 🚀 Evolução vs Level 3

| Aspecto | Level 3 (Vault) | Level 4 (AWS Secrets) |
|---------|-----------------|----------------------|
| **Ambiente** | Local/On-Premise | AWS Cloud ☁️ |
| **Secrets Manager** | HashiCorp Vault | AWS Secrets Manager |
| **Criptografia** | AES-256 (Vault) | KMS (AWS-managed) |
| **Auditoria** | Vault Audit Logs | CloudTrail (AWS-native) |
| **Autenticação** | Vault Tokens | IAM Roles ✅ |
| **Acesso Secrets** | API Vault | AWS CLI/SDK |
| **Infraestrutura** | Docker Compose | Terraform + EC2 |
| **Escalabilidade** | Manual | Auto-scaling ready |
| **Integração Cloud** | Não | Nativa AWS ✅ |
| **Custo** | $0 (self-hosted) | ~$35/mês |
| **Complexidade** | Média | Média-Alta |
| **Rotação Automática** | Manual | Opcional (AWS-managed) |
| **Deploy** | Local | Remoto (AWS) |

### 💡 Por que evoluir do Level 3 para Level 4?

**Level 3 (Vault)** é excelente para:
- ✅ Ambientes on-premise
- ✅ Multi-cloud (vendor neutral)
- ✅ Controle total sobre infraestrutura
- ✅ Sem custos de secrets manager

**Level 4 (AWS Secrets)** é melhor quando:
- ✅ Já está na AWS Cloud
- ✅ Quer integração nativa com serviços AWS
- ✅ Precisa de IAM roles para autenticação
- ✅ CloudTrail é sua ferramenta de auditoria
- ✅ Quer secrets manager totalmente gerenciado
- ✅ Planeja usar outros serviços AWS (RDS, ECS, Lambda)

---

## 🎯 Características

### 🆕 Novidades do Level 4

- ✅ **AWS Cloud Deployment** - Infraestrutura completa na AWS
- ✅ **AWS Secrets Manager** - Gerenciamento centralizado de credenciais
- ✅ **KMS Encryption** - Criptografia nativa AWS para secrets
- ✅ **IAM Roles** - Autenticação sem credenciais hardcoded
- ✅ **CloudTrail Audit** - Auditoria automática de acessos
- ✅ **Terraform IaC** - Infraestrutura como código
- ✅ **EC2 Auto-configuration** - User data script configura tudo
- ✅ **Senhas aleatórias 32 chars** - Geradas automaticamente

### ✅ Herda do Level 3

- ✅ **Auditoria completa** - Logs de todos os acessos a secrets
- ✅ **Versionamento** - Histórico de alterações de senhas
- ✅ **Políticas de acesso** - Segregação por serviço
- ✅ **Criptografia forte** - Secrets criptografados em repouso

### ✅ Herda dos Levels 1 & 2

- ✅ **Stack Completa** - Zabbix 7.0.5 + Grafana 12.0.2 + Prometheus
- ✅ **Monitoramento Sistema** - CPU, RAM, Disk, Network
- ✅ **Monitoramento MySQL** - Performance e métricas avançadas
- ✅ **Dashboards Prontos** - 2 dashboards funcionais
- ✅ **MySQL Container** - Sem RDS (mais simples e confiável)

---

## 🏗️ Arquitetura

```
┌──────────────────────────────────────────┐
│      AWS Secrets Manager (KMS)           │
│  ┌────────────────────────────────────┐  │
│  │ monitoring/mysql-root-password     │  │
│  │ monitoring/mysql-credentials       │  │
│  │ monitoring/grafana-credentials     │  │
│  └────────────────────────────────────┘  │
└──────────────────┬───────────────────────┘
                   │ IAM Role
                   ▼
┌──────────────────────────────────────────┐
│          EC2 t3.medium (Ubuntu 22.04)    │
│                                          │
│  user_data:                              │
│   1. aws secretsmanager get-secret-value│
│   2. Cria .env com senhas                │
│   3. docker-compose up -d                │
│                                          │
│  Containers (IDÊNTICOS ao Level 1):      │
│   ├── MySQL 8.3 (local)      ✅          │
│   ├── Zabbix Server 7.0.5    ✅          │
│   ├── Zabbix Web             ✅          │
│   ├── Grafana 12.0.2         ✅          │
│   ├── Prometheus 2.48.1      ✅          │
│   └── Exporters              ✅          │
└──────────────────────────────────────────┘
```

## 📋 Pré-requisitos

1. **AWS CLI configurado**
   ```bash
   aws configure
   ```

2. **Terraform instalado** (>= 1.0)
   ```bash
   terraform --version
   ```

3. **Chave SSH na AWS**
   - Crie um key pair na AWS Console
   - Região: `us-east-1` (ou sua região preferida)
   - Baixe o arquivo .pem

4. **Permissões AWS necessárias**
   - EC2 (create, modify, delete)
   - VPC e Security Groups
   - IAM Roles e Policies
   - Secrets Manager
   - KMS Keys

## 🚀 Deploy Completo (3 passos)

### Passo 1: Configurar variáveis

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edite terraform.tfvars com suas configurações
```

### Passo 2: Criar infraestrutura + secrets

```bash
terraform init
terraform plan
terraform apply
```

**Tempo:** ~3 minutos

**Recursos criados:**
- 1x VPC + Subnet + Internet Gateway
- 1x Security Group
- 1x EC2 t3.medium com IAM Role
- 1x Elastic IP
- 3x Secrets Manager secrets
- 1x KMS Key
- 1x IAM Role + Instance Profile

**Output esperado:**
```
public_ip = "X.X.X.X"
zabbix_url = "http://X.X.X.X:8080"
grafana_url = "http://X.X.X.X:3000"

next_steps = "..."
```

### Passo 2: Aguardar servidor inicializar

```bash
sleep 120  # 2 minutos
```

O servidor está:
- Instalando Docker
- Instalando AWS CLI
- **Buscando secrets do Secrets Manager**
- **Criando .env com senhas seguras**

### Passo 3: Deploy dos containers

```bash
cd ..  # Volta para a raiz do projeto
./deploy.sh <IP_DO_OUTPUT>
```

**Tempo:** ~8 minutos

**O que acontece:**
1. ✅ Testa SSH
2. ✅ Aguarda servidor pronto
3. ✅ Copia docker-compose.yml
4. ✅ **NÃO copia .env** (já foi gerado com secrets)
5. ✅ Copia grafana/ e prometheus/
6. ✅ Copia scripts de configuração
7. ✅ Inicia containers
8. ✅ Aguarda Zabbix (6 min)
9. ✅ Configura templates
10. ✅ Importa dashboards
11. ✅ Exibe URLs

## 🌐 Acessar Aplicações

| Aplicação | URL | Credenciais |
|-----------|-----|-------------|
| **Zabbix** | `http://<IP>:8080` | Admin / [secrets] |
| **Grafana** | `http://<IP>:3000` | admin / [secrets] |
| **Prometheus** | `http://<IP>:9090` | - |

### 🔑 Ver Credenciais

```bash
cd terraform

# Grafana
terraform output grafana_credentials

# MySQL
terraform output mysql_credentials

# Todos os secrets
terraform output secrets_info
```

## 🔐 Segurança

### Senhas Geradas

```bash
# Exemplo de senhas geradas (32 chars alfanuméricos):
MySQL Root:  aB3cD5eF7gH9jK2mN4pQ6rS8tU0vW1xY
MySQL User:  zN8mP2qR5sT7vX0yA3bC6dE9fG1hJ4kL
Grafana:     mQ7nR0sT3uV6wX9yZ2aC5bD8eF1gH4jK

# SEM caracteres especiais problemáticos!
# Apenas: a-z, A-Z, 0-9
```

### Proteções

- ✅ **KMS Encryption**: Secrets criptografados em repouso
- ✅ **IAM Policies**: Acesso restrito via role
- ✅ **CloudTrail**: Todos os acessos auditados
- ✅ **Secrets Manager**: Gerenciamento centralizado
- ✅ **Versionamento**: Histórico de alterações
- ✅ **Recovery**: 7 dias para recuperar secrets deletados

## � Comandos Úteis

### SSH no servidor
```bash
export SSH_KEY=~/.ssh/your-key.pem  # Configure uma vez
ssh -i $SSH_KEY ubuntu@<IP>
```

### Re-executar deploy
```bash
./deploy.sh <IP>
```

### Ver .env gerado (com secrets do AWS)
```bash
ssh -i $SSH_KEY ubuntu@<IP> "cat /home/ubuntu/monitoring/.env"
```

### Verificar secrets no AWS Secrets Manager
```bash
ssh -i $SSH_KEY ubuntu@<IP>
aws secretsmanager list-secrets --region us-east-1
```

### Ver logs do user_data (inicialização EC2)
```bash
ssh -i $SSH_KEY ubuntu@<IP> "cat /var/log/user-data.log"
```

### Rotacionar senha manualmente
```bash
cd terraform
terraform taint random_password.mysql_root_password
terraform apply
# Depois: reiniciar containers no servidor
```

### Verificar containers
```bash
ssh -i $SSH_KEY ubuntu@<IP> "cd monitoring && docker-compose ps"
```

## 💰 Custos

| Recurso | Custo Mensal |
|---------|--------------|
| EC2 t3.medium | $30.00 |
| EBS 30GB | $2.40 |
| Secrets Manager (3) | $1.20 |
| KMS Key | $1.00 |
| **Total** | **~$34.60/mês** |

**Comparado com Level 1:** +$2.20/mês (+6.8%)  
**Benefício:** Segurança enterprise-grade

## 🧹 Destruir Infraestrutura

```bash
cd terraform
terraform destroy
```

**ATENÇÃO:**
- Secrets têm recovery window de 7 dias
- Para deletar imediatamente: `--force-delete-without-recovery`
- Dados serão perdidos permanentemente

## 📂 Estrutura do Projeto

```
monitoring-security-level4-aws-v2/
├── README.md                 # Este arquivo
├── CONTRIBUTING.md          # Guia de contribuição
├── LICENSE                  # Licença MIT
├── .gitignore              # Arquivos ignorados pelo git
│
├── deploy.sh               # Script principal de deploy
├── setup-server.sh         # Configuração do servidor
├── import-dashboards.sh    # Importa dashboards Grafana
├── smoke-test.sh          # Testes de validação
├── backup.sh              # Backup completo do projeto
├── restore.sh             # Restaura backup
│
├── docker-compose.yml     # Orquestração dos containers
│
├── grafana/               # Configurações Grafana
│   ├── dashboards/        # Dashboards JSON
│   └── provisioning/      # Auto-provisioning
│
├── prometheus/            # Configurações Prometheus
│   └── prometheus.yml
│
├── mysql-exporter/        # MySQL Exporter config
│   └── .my.cnf
│
└── terraform/             # Infraestrutura como Código
    ├── README.md          # Documentação Terraform
    ├── providers.tf       # Providers AWS
    ├── variables.tf       # Variáveis
    ├── terraform.tfvars.example  # Exemplo de configuração
    ├── main.tf            # EC2, VPC, Security Groups
    ├── iam.tf            # IAM Roles e Policies
    ├── secrets.tf        # AWS Secrets Manager
    ├── kms.tf            # KMS Encryption Keys
    └── outputs.tf        # Outputs (IPs, URLs, secrets)
```

---

## 🔗 Série Monitoring Security

Esta é uma série educacional de 5 níveis mostrando a evolução de segurança em monitoring stacks:

| Nível | Foco | Secrets Management | Ambiente | Status |
|-------|------|-------------------|----------|--------|
| **[Level 1](https://github.com/jlui70/monitoring-security-level1)** | Baseline | Hardcoded | Local | ✅ Completo |
| **[Level 2](https://github.com/jlui70/monitoring-security-level2)** | Env Management | .env files (dev/staging/prod) | Local | ✅ Completo |
| **[Level 3](https://github.com/jlui70/monitoring-security-level3)** | Vault Foundation | HashiCorp Vault | Local | ✅ Completo |
| **Level 4** | Cloud Secrets | AWS Secrets Manager | AWS Cloud | ⬅️ **VOCÊ ESTÁ AQUI** |
| **Level 5** | K8s + Vault | Vault + External Secrets | Kubernetes | 🔜 Em breve |

### 📈 Comparação de Segurança

| Feature | L1 | L2 | L3 | L4 | L5 |
|---------|----|----|----|----|-----|
| **Hardcoded Secrets** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Environment Separation** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Centralized Secrets** | ❌ | ❌ | ✅ | ✅ | ✅ |
| **Encryption at Rest** | ❌ | ❌ | ✅ | ✅ | ✅ |
| **Audit Logs** | ❌ | ❌ | ✅ | ✅ | ✅ |
| **Secret Versioning** | ❌ | ❌ | ✅ | ✅ | ✅ |
| **Cloud Integration** | ❌ | ❌ | ❌ | ✅ | ✅ |
| **Auto Rotation** | ❌ | ❌ | ❌ | ⚠️ | ✅ |
| **Dynamic Injection** | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Zero .env Files** | ❌ | ❌ | ❌ | ❌ | ✅ |

### � Quando usar cada Level?

**Level 1** - Aprendizado inicial, demos, não use em produção  
**Level 2** - Desenvolvimento local com múltiplos ambientes  
**Level 3** - On-premise, multi-cloud, controle total  
**Level 4** - AWS cloud, integração nativa com serviços AWS  
**Level 5** - Kubernetes, enterprise-grade, zero-trust architecture

---

## �🎓 Caso de Uso Educacional

Este projeto demonstra:

1. ✅ **Evolução de segurança**: Level 3 (Vault) → Level 4 (AWS)
2. ✅ **AWS Secrets Manager**: Gerenciamento de credenciais cloud-native
3. ✅ **IAM Best Practices**: Roles e policies sem credenciais hardcoded
4. ✅ **KMS Encryption**: Criptografia gerenciada pela AWS
5. ✅ **CloudTrail Integration**: Auditoria automática
6. ✅ **Terraform IaC**: Infraestrutura como código replicável
7. ✅ **Compatibilidade**: Senhas alfanuméricas (lição do Level 4 v1)

**Ideal para:**
- Cursos de DevSecOps e AWS Security
- Workshops de Terraform e IaC
- Demonstrações de compliance (CloudTrail + KMS)
- Portfolio profissional
- Preparação para certificações AWS

---

## 🔍 Troubleshooting

### Erro: "AccessDenied" ao buscar secrets

**Causa:** IAM Role sem permissões

**Solução:**
```bash
# Verificar role
aws iam get-role --role-name monitoring-ec2-secrets-access

# Verificar policy
aws iam get-role-policy --role-name monitoring-ec2-secrets-access --policy-name secrets-manager-access
```

### Containers não iniciam

**Verificar .env:**
```bash
ssh -i ~/ssh/devops-key.pem ubuntu@<IP>
cat /home/ubuntu/monitoring/.env
# Senhas devem estar preenchidas (não PLACEHOLDER)
```

### Zabbix em loop

**NÃO deve acontecer** (usando MySQL container, não RDS)

Se acontecer:
```bash
docker logs zabbix-server --tail 50
docker logs mysql-server --tail 50
```

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Veja [CONTRIBUTING.md](CONTRIBUTING.md) para detalhes.

### Como Contribuir

1. Fork o projeto
2. Crie uma branch (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## ⭐ Suporte

Se este projeto foi útil, considere dar uma ⭐ no GitHub!

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

## 👤 Autor

Criado para fins educacionais e demonstração de DevSecOps best practices.

## � Agradecimentos

- Comunidade Zabbix
- Grafana Labs
- Prometheus
- AWS Documentation

---

<div align="center">

**🔐 Enterprise-grade monitoring com AWS Secrets Manager**

[![Terraform](https://img.shields.io/badge/IaC-Terraform-623CE4?style=for-the-badge&logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/Cloud-AWS-FF9900?style=for-the-badge&logo=amazon-aws)](https://aws.amazon.com/)
[![Docker](https://img.shields.io/badge/Container-Docker-2496ED?style=for-the-badge&logo=docker)](https://www.docker.com/)

</div>

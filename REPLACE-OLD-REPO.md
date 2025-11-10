# Guia: Substituir Repositório Antigo Level 4

Este guia mostra como substituir completamente o conteúdo do repositório antigo pelo novo.

## Opção 1: Force Push (Recomendado - Substitui Tudo)

⚠️ **ATENÇÃO:** Isso irá **apagar TODO o histórico** do repositório antigo e substituir pelo novo.

### Passo 1: Fazer backup do repositório antigo (opcional)

```bash
# Clone o repo antigo em outro local (backup)
cd ~
git clone https://github.com/jlui70/monitoring-security-level4.git monitoring-security-level4-backup
```

### Passo 2: Inicializar git no novo projeto

```bash
cd /home/luiz7/monitoring-security-level4-aws-v2

# Inicializar git
git init

# Adicionar todos os arquivos
git add .

# Verificar o que será commitado
git status

# Commit inicial
git commit -m "feat: Complete rewrite - AWS Secrets Manager implementation

- Migrated from Level 1 AWS to proper Level 4
- Added AWS Secrets Manager integration
- Implemented Terraform IaC
- Added KMS encryption
- Integrated CloudTrail auditing
- Complete documentation overhaul
- Added backup/restore scripts
- Security policy and contributing guidelines
- Positioned correctly in 5-level series (Level 3 → Level 4 → Level 5)"
```

### Passo 3: Conectar ao repositório remoto

```bash
# Adicionar remote (repo existente)
git remote add origin https://github.com/jlui70/monitoring-security-level4.git

# Verificar
git remote -v
```

### Passo 4: Force push (SUBSTITUI TUDO)

```bash
# Renomear branch para main
git branch -M main

# Force push (CUIDADO: apaga histórico antigo!)
git push -u origin main --force
```

**Pronto!** O repositório antigo foi completamente substituído pelo novo.

---

## Opção 2: Manter Histórico (Adicionar como Nova Versão)

Se quiser MANTER o histórico antigo e adicionar o novo como evolução:

### Passo 1: Clonar o repositório antigo

```bash
cd ~
git clone https://github.com/jlui70/monitoring-security-level4.git
cd monitoring-security-level4
```

### Passo 2: Criar branch de backup

```bash
# Criar branch com versão antiga
git checkout -b v1-old-version
git push origin v1-old-version

# Voltar para main
git checkout main
```

### Passo 3: Remover tudo e adicionar novo conteúdo

```bash
# Remover tudo (menos .git)
find . -maxdepth 1 ! -name '.git' ! -name '.' ! -name '..' -exec rm -rf {} \;

# Copiar novo projeto
cp -r /home/luiz7/monitoring-security-level4-aws-v2/* .
cp -r /home/luiz7/monitoring-security-level4-aws-v2/.gitignore .

# Adicionar tudo
git add .
git commit -m "feat: Complete rewrite - AWS Secrets Manager implementation

BREAKING CHANGE: Complete project overhaul

Previous version preserved in branch: v1-old-version

Changes:
- Migrated from Level 1 AWS to proper Level 4
- Added AWS Secrets Manager integration
- Implemented Terraform IaC
- Added KMS encryption
- Integrated CloudTrail auditing
- Complete documentation overhaul
- Positioned correctly in 5-level series"

# Push
git push origin main
```

---

## Opção 3: Arquivar Antigo e Criar Novo (Mais Limpo)

### Passo 1: Arquivar repositório antigo

1. Acesse: https://github.com/jlui70/monitoring-security-level4
2. Settings → Scroll down → "Archive this repository"
3. Renomear para: `monitoring-security-level4-old`

### Passo 2: Criar novo repositório

1. Criar novo repo: https://github.com/new
2. Nome: `monitoring-security-level4`
3. NÃO inicializar com README

### Passo 3: Push do novo projeto

```bash
cd /home/luiz7/monitoring-security-level4-aws-v2

git init
git add .
git commit -m "Initial commit: AWS Secrets Manager Level 4"
git branch -M main
git remote add origin https://github.com/jlui70/monitoring-security-level4.git
git push -u origin main
```

---

## Recomendação

**Use Opção 1 (Force Push)** se:
- ✅ O repo antigo não tem contribuições de outras pessoas
- ✅ O histórico antigo não é importante
- ✅ Quer o repo mais limpo
- ✅ Este é um rewrite completo

**Use Opção 2** se:
- ✅ Quer preservar histórico para referência
- ✅ Pode haver issues/PRs antigos relevantes

**Use Opção 3** se:
- ✅ Quer manter o antigo disponível
- ✅ São projetos muito diferentes

---

## Depois do Push

### 1. Atualizar descrição do repositório

GitHub → Settings → About:
```
Cloud-native monitoring stack with AWS Secrets Manager - Part of 5-level security evolution series (Level 4)
```

### 2. Adicionar topics

```
aws, terraform, docker, zabbix, grafana, prometheus, 
secrets-manager, kms, monitoring, devops, devsecops, 
infrastructure-as-code, cloudtrail, iam
```

### 3. Atualizar README badges (se necessário)

Os links já estão corretos no README.md

### 4. Criar release (opcional)

```bash
git tag -a v2.0.0 -m "Version 2.0.0 - Complete AWS Secrets Manager implementation"
git push origin v2.0.0
```

No GitHub:
- Releases → Create new release
- Tag: v2.0.0
- Title: "v2.0.0 - Complete Rewrite with AWS Secrets Manager"
- Description:
```markdown
## 🎉 Major Release - Complete Rewrite

This is a complete rewrite of Level 4, now properly positioned in the 5-level security evolution series.

### 🆕 What's New
- ✅ AWS Secrets Manager integration
- ✅ Terraform Infrastructure as Code
- ✅ KMS encryption for secrets
- ✅ IAM roles and policies
- ✅ CloudTrail auditing
- ✅ Complete documentation
- ✅ Backup/restore scripts
- ✅ Security policy

### 📚 Series Position
Level 3 (HashiCorp Vault) → **Level 4 (AWS Secrets)** → Level 5 (K8s + Vault)

### 🔗 Related Projects
- [Level 1](https://github.com/jlui70/monitoring-security-level1) - Baseline
- [Level 2](https://github.com/jlui70/monitoring-security-level2) - Env Management
- [Level 3](https://github.com/jlui70/monitoring-security-level3) - Vault Foundation
- Level 5 - Coming soon

### 💰 Cost
~$35/month on AWS (t3.medium + secrets)

### 📖 Full Documentation
See [README.md](https://github.com/jlui70/monitoring-security-level4#readme) for complete setup guide.
```

### 5. Notificar seguidores (opcional)

Se tiver seguidores do repo antigo, considere criar uma Issue anunciando:
- Título: "🎉 Version 2.0 Released - Complete Rewrite"
- Explicar mudanças principais
- Link para documentação

---

## Checklist Final

Antes de fazer o push:

- [ ] Backup do projeto feito (`./backup.sh`)
- [ ] Todos os arquivos sensíveis no .gitignore
- [ ] README.md revisado e correto
- [ ] Links funcionando
- [ ] Sem credenciais hardcoded
- [ ] Scripts executáveis (`chmod +x *.sh`)
- [ ] Terraform .tfvars.example criado
- [ ] LICENSE presente
- [ ] CONTRIBUTING.md presente
- [ ] SECURITY.md presente

Depois do push:

- [ ] Descrição do repo atualizada
- [ ] Topics adicionados
- [ ] README renderizando corretamente
- [ ] Links entre repos da série funcionando
- [ ] Release criado (opcional)

---

## Comandos Rápidos

**Para Opção 1 (Force Push - Recomendado):**

```bash
cd /home/luiz7/monitoring-security-level4-aws-v2
git init
git add .
git commit -m "feat: Complete rewrite - AWS Secrets Manager implementation"
git branch -M main
git remote add origin https://github.com/jlui70/monitoring-security-level4.git
git push -u origin main --force
```

**Depois configurar no GitHub:**
- Description
- Topics
- About section

---

🎉 Pronto! Seu repositório Level 4 está atualizado e alinhado com a série!

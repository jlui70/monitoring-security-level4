#!/bin/bash
set -e

echo "============================================"
echo "Monitoring Level 4 - Setup com Secrets Manager"
echo "============================================"

# Atualizar sistema
echo "[1/10] Atualizando sistema..."
apt-get update
apt-get upgrade -y

# Instalar dependências
echo "[2/10] Instalando dependências..."
apt-get install -y docker.io jq mysql-client python3-bcrypt git curl unzip

# Instalar AWS CLI v2
echo "[2.1/10] Instalando AWS CLI v2..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install --update
rm -rf /tmp/aws /tmp/awscliv2.zip

# Instalar docker-compose
echo "[2.2/10] Instalando Docker Compose v2..."
curl -sL "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Configurar Docker
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Criar diretório
mkdir -p /home/ubuntu/monitoring
chown ubuntu:ubuntu /home/ubuntu/monitoring

# Aguardar AWS metadata service
echo "[3/10] Aguardando AWS Secrets Manager estar disponível..."
sleep 10

# Função para buscar secret com retry e detecção de formato
fetch_secret() {
    local secret_id="$1"
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        SECRET_VALUE=$(aws secretsmanager get-secret-value \
            --secret-id "$secret_id" \
            --region us-east-1 \
            --query SecretString \
            --output text 2>/dev/null)
        
        if [ $? -eq 0 ] && [ -n "$SECRET_VALUE" ]; then
            echo "$SECRET_VALUE"
            return 0
        fi
        
        retry=$((retry + 1))
        echo "⚠️  Retry $retry/$max_retries para $secret_id..." >&2
        sleep 5
    done
    
    echo "❌ Falha ao buscar $secret_id após $max_retries tentativas" >&2
    return 1
}

# Parse secret (detecta se é JSON ou string simples)
parse_secret() {
    local secret_value="$1"
    local field="$2"
    
    # Tenta parsear como JSON
    if echo "$secret_value" | jq -e . >/dev/null 2>&1; then
        # É JSON válido
        echo "$secret_value" | jq -r ".$field" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    else
        # String simples (trim whitespace)
        echo "$secret_value" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    fi
}

# Buscar secrets
echo "[4/10] Buscando MySQL Root Password..."
MYSQL_ROOT_SECRET=$(fetch_secret "monitoring/mysql-root-password")
MYSQL_ROOT_PASS=$(parse_secret "$MYSQL_ROOT_SECRET" "password")

if [ -z "$MYSQL_ROOT_PASS" ]; then
    echo "❌ Erro: MySQL root password vazio!"
    exit 1
fi

echo "[5/10] Buscando MySQL User Credentials..."
MYSQL_CREDS=$(fetch_secret "monitoring/mysql-credentials")
MYSQL_USER=$(parse_secret "$MYSQL_CREDS" "username")
MYSQL_PASS=$(parse_secret "$MYSQL_CREDS" "password")

if [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASS" ]; then
    echo "❌ Erro: MySQL user credentials incompletas!"
    exit 1
fi

echo "[6/10] Buscando Grafana Credentials..."
GRAFANA_CREDS=$(fetch_secret "monitoring/grafana-credentials")
GRAFANA_USER=$(parse_secret "$GRAFANA_CREDS" "username")
GRAFANA_PASS=$(parse_secret "$GRAFANA_CREDS" "password")

if [ -z "$GRAFANA_USER" ] || [ -z "$GRAFANA_PASS" ]; then
    echo "❌ Erro: Grafana credentials incompletas!"
    exit 1
fi

echo "[7/10] Buscando Zabbix Admin Credentials..."
ZABBIX_CREDS=$(fetch_secret "monitoring/zabbix-admin-credentials")
ZABBIX_USER=$(parse_secret "$ZABBIX_CREDS" "username")
ZABBIX_PASS=$(parse_secret "$ZABBIX_CREDS" "password")

if [ -z "$ZABBIX_USER" ] || [ -z "$ZABBIX_PASS" ]; then
    echo "❌ Erro: Zabbix credentials incompletas!"
    exit 1
fi

# Criar .env com TODAS as variáveis necessárias
echo "[8/10] Criando arquivo .env com TODAS as variáveis..."
cat > /home/ubuntu/monitoring/.env << ENVEOF
# MySQL
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASS}
MYSQL_DATABASE=zabbix
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASS}
MYSQL_VERSION=8.3

# Zabbix Server
DB_SERVER_HOST=mysql-server
MYSQL_DATABASE=zabbix
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASS}
ZBX_CACHESIZE=512M
ZBX_CACHEUPDATEFREQUENCY=60
ZBX_STARTPINGERS=10
ZBX_STARTPOLLERS=20
ZBX_STARTPOLLERSUNREACHABLE=5
ZBX_STARTTRAPPERS=10
ZBX_STARTDISCOVERERS=5
ZBX_STARTHTTPPOLLERS=5
ZBX_STARTDBSYNCERS=4
ZBX_STARTSNMPPOLLERS=5
ZBX_STARTUNREACHABLE=10
ZBX_HISTORYCACHESIZE=256M
ZBX_HISTORYINDEXCACHESIZE=128M
ZBX_TRENDCACHESIZE=128M
ZBX_VALUECACHESIZE=256M
ZBX_TIMEOUT=30

# Zabbix Web
ZBX_SERVER_HOST=zabbix-server
ZBX_SERVER_PORT=10051
DB_SERVER_HOST=mysql-server
MYSQL_DATABASE=zabbix
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASS}
PHP_TZ=America/Sao_Paulo

# Zabbix Agent
ZBX_HOSTNAME="Zabbix server"
ZBX_SERVER_HOST=zabbix-server

# Grafana
GF_SECURITY_ADMIN_USER=${GRAFANA_USER}
GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASS}
GF_INSTALL_PLUGINS=alexanderzobnin-zabbix-app

# Prometheus
PROMETHEUS_VERSION=latest

# Timezone
TZ=America/Sao_Paulo

# ZABBIX ADMIN (para scripts de configuração)
ZABBIX_ADMIN_PASSWORD=${ZABBIX_PASS}
ZABBIX_ADMIN_USER=${ZABBIX_USER}
ENVEOF

chmod 600 /home/ubuntu/monitoring/.env
chown ubuntu:ubuntu /home/ubuntu/monitoring/.env

echo "[9/10] Criando script de atualização de senha do Zabbix..."
cat > /home/ubuntu/monitoring/update-zabbix-password.sh << 'ZABBIXSCRIPT'
#!/bin/bash
set -e

echo "⏳ Aguardando Zabbix criar tabelas do banco..."
sleep 10

# Carregar variáveis do .env
source /home/ubuntu/monitoring/.env

echo "🔐 Gerando hash bcrypt para senha do Zabbix Admin..."
BCRYPT_HASH=$(python3 -c "import bcrypt; print(bcrypt.hashpw('${ZABBIX_ADMIN_PASSWORD}'.encode('utf-8'), bcrypt.gensalt(rounds=10)).decode('utf-8'))")

echo "📝 Atualizando senha do Admin no banco..."
docker exec mysql-server mysql -uroot -p${MYSQL_ROOT_PASSWORD} -D zabbix -e "
UPDATE users 
SET passwd = '${BCRYPT_HASH}', 
    attempt_failed = 0, 
    attempt_clock = 0 
WHERE username = 'Admin';
"

echo "✅ Senha do Zabbix Admin atualizada para senha do Secrets Manager!"
ZABBIXSCRIPT

chmod +x /home/ubuntu/monitoring/update-zabbix-password.sh
chown ubuntu:ubuntu /home/ubuntu/monitoring/update-zabbix-password.sh

echo "[10/10] Criando arquivo de status..."
echo "Setup completo em $(date)" > /home/ubuntu/status.txt

echo "✅ Setup completo! Aguardando deploy.sh..."

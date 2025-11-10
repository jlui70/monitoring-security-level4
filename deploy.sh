#!/bin/bash

# =============================================================================
# Deploy Script - Monitoring Stack Level 1 na AWS
# =============================================================================
# 
# Uso: ./deploy.sh <IP_DO_SERVIDOR>
# 
# Este script:
# 1. Copia todos os arquivos do Level 1 para o servidor AWS
# 2. Inicia os containers Docker
# 3. Aguarda a inicialização do Zabbix
# 4. Exibe URLs de acesso
# =============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar argumentos
if [ -z "$1" ]; then
    echo -e "${RED}❌ Erro: IP do servidor não fornecido${NC}"
    echo "Uso: $0 <IP_DO_SERVIDOR>"
    echo ""
    echo "Exemplo: $0 54.123.45.67"
    exit 1
fi

SERVER_IP=$1
SSH_KEY="${SSH_KEY:-$HOME/.ssh/devops-key.pem}"  # Usa variável de ambiente ou padrão
SSH_USER="ubuntu"
REMOTE_DIR="/home/ubuntu/monitoring"
PROJECT_DIR=$(dirname "$(readlink -f "$0")")  # Diretório deste script

echo "🔐 Monitoring Security Evolution - Level 4 AWS"
echo "======================================"
echo "  Deploy Monitoring Stack Level 4 AWS  "
echo "  ✅ AWS Secrets Manager Integration   "
echo "======================================"
echo ""
echo "Servidor: $SERVER_IP"
echo "Chave SSH: $SSH_KEY"
echo "Diretório remoto: $REMOTE_DIR"
echo ""

# Verificar se a chave SSH existe
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}❌ Erro: Chave SSH não encontrada em $SSH_KEY${NC}"
    echo "  Defina a variável SSH_KEY: export SSH_KEY=/path/to/your-key.pem"
    echo "  Ou coloque sua chave em: ~/.ssh/devops-key.pem"
    exit 1
fi

echo -e "${YELLOW}⏳ Aguardando servidor estar pronto (testando SSH)...${NC}"
max_attempts=30
attempt=0
while ! ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$SSH_USER@$SERVER_IP" "echo 'SSH OK'" &>/dev/null; do
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
        echo -e "${RED}❌ Erro: Não foi possível conectar ao servidor após $max_attempts tentativas${NC}"
        exit 1
    fi
    echo "Tentativa $attempt/$max_attempts..."
    sleep 10
done
echo -e "${GREEN}✅ SSH conectado com sucesso!${NC}"
echo ""

# Aguardar user_data terminar
echo -e "${YELLOW}⏳ Aguardando inicialização do servidor (Docker, etc)...${NC}"
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" "while [ ! -f /home/ubuntu/status.txt ]; do sleep 5; done; cat /home/ubuntu/status.txt"
echo ""

# Copiar arquivos
echo -e "${YELLOW}📦 Copiando arquivos do projeto...${NC}"

# docker-compose.yml
echo "  - docker-compose.yml"
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no "$PROJECT_DIR/docker-compose.yml" "$SSH_USER@$SERVER_IP:$REMOTE_DIR/"

# .env é gerado automaticamente no servidor pelo user_data com secrets do AWS Secrets Manager
echo "  - .env (gerado automaticamente no servidor com AWS Secrets Manager)"

# Diretórios grafana e prometheus
echo "  - grafana/"
scp -r -i "$SSH_KEY" "$PROJECT_DIR/grafana" "$SSH_USER@$SERVER_IP:$REMOTE_DIR/"

echo "  - prometheus/"
scp -r -i "$SSH_KEY" "$PROJECT_DIR/prometheus" "$SSH_USER@$SERVER_IP:$REMOTE_DIR/"

# mysql-exporter (se existir)
if [ -d "$PROJECT_DIR/mysql-exporter" ]; then
    echo "  - mysql-exporter/"
    scp -r -i "$SSH_KEY" "$PROJECT_DIR/mysql-exporter" "$SSH_USER@$SERVER_IP:$REMOTE_DIR/"
fi

# Scripts de configuração
if [ -f "$PROJECT_DIR/configure-zabbix.sh" ]; then
    echo "  - configure-zabbix.sh"
    scp -i "$SSH_KEY" "$PROJECT_DIR/configure-zabbix.sh" "$SSH_USER@$SERVER_IP:$REMOTE_DIR/"
fi

echo "  - import-dashboards.sh"
scp -i "$SSH_KEY" "$PROJECT_DIR/import-dashboards.sh" "$SSH_USER@$SERVER_IP:$REMOTE_DIR/"

# Tornar scripts executáveis
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" "chmod +x $REMOTE_DIR/*.sh"

echo -e "${GREEN}✅ Arquivos copiados!${NC}"
echo ""

# Iniciar containers
echo -e "${YELLOW}🚀 Iniciando containers Docker...${NC}"
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" << 'ENDSSH'
cd /home/ubuntu/monitoring
docker-compose down -v 2>/dev/null || true
docker-compose up -d
ENDSSH
echo -e "${GREEN}✅ Containers iniciados!${NC}"
echo ""

# Aguardar Zabbix
echo -e "${YELLOW}⏳ Aguardando Zabbix inicializar (pode levar até 6 minutos)...${NC}"
echo "Monitorando logs do Zabbix Server..."
echo ""

ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" << 'ENDSSH'
cd /home/ubuntu/monitoring

# Aguardar até 360 segundos (6 minutos)
timeout=360
elapsed=0

while [ $elapsed -lt $timeout ]; do
    # Verificar se o Zabbix está pronto
    if docker logs zabbix-server 2>&1 | grep -q "Zabbix Server started"; then
        echo ""
        echo "✅ Zabbix Server iniciado com sucesso!"
        exit 0
    fi
    
    # Mostrar status a cada 10 segundos
    if [ $((elapsed % 10)) -eq 0 ]; then
        echo "⏳ Aguardando Zabbix... ($elapsed/$timeout segundos)"
    fi
    
    sleep 5
    elapsed=$((elapsed + 5))
done

echo ""
echo "⚠️  Timeout atingido. Verifique os logs manualmente:"
echo "   docker logs zabbix-server"
exit 1
ENDSSH

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  ✅ Zabbix iniciado com sucesso!      ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    # Executar configuração do Zabbix
    echo -e "${YELLOW}⚙️  Configurando Zabbix (templates e DNS)...${NC}"
    ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" << 'ENDSSH'
cd /home/ubuntu/monitoring
./configure-zabbix.sh
ENDSSH
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Zabbix configurado!${NC}"
    else
        echo -e "${YELLOW}⚠️  Erro ao configurar Zabbix. Execute manualmente depois.${NC}"
    fi
    echo ""
    
    # Importar dashboards do Grafana
    echo -e "${YELLOW}📊 Importando dashboards no Grafana...${NC}"
    ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" << 'ENDSSH'
cd /home/ubuntu/monitoring
./import-dashboards.sh
ENDSSH
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Dashboards importados!${NC}"
    else
        echo -e "${YELLOW}⚠️  Erro ao importar dashboards. Execute manualmente depois.${NC}"
    fi
    echo ""
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  ✅ DEPLOY CONCLUÍDO COM SUCESSO!     ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "URLs de Acesso:"
    echo ""
    echo -e "  🔹 Zabbix Web:    ${YELLOW}http://$SERVER_IP:8080${NC}"
    echo "     Usuário: Admin"
    echo "     Senha: zabbix"
    echo ""
    echo -e "  🔹 Grafana:       ${YELLOW}http://$SERVER_IP:3000${NC}"
    echo "     Usuário: admin"
    echo "     Senha: admin"
    echo "     📊 Dashboards importados!"
    echo ""
    echo -e "  🔹 Prometheus:    ${YELLOW}http://$SERVER_IP:9090${NC}"
    echo ""
    echo "SSH:"
    echo -e "  ${YELLOW}ssh -i $SSH_KEY $SSH_USER@$SERVER_IP${NC}"
    echo ""
    echo "Verificar containers:"
    echo "  docker ps"
    echo ""
    echo "Verificar logs:"
    echo "  docker logs zabbix-server"
    echo "  docker logs grafana"
    echo "  docker logs prometheus"
    echo ""
else
    echo ""
    echo -e "${YELLOW}⚠️  Zabbix ainda está inicializando${NC}"
    echo "Aguarde mais alguns minutos e verifique:"
    echo ""
    echo "  ssh -i $SSH_KEY $SSH_USER@$SERVER_IP"
    echo "  docker logs -f zabbix-server"
    echo ""
fi

#!/bin/bash
set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🧪 SMOKE TEST - Deploy Completo Level 4 AWS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

LOG_FILE="smoke-test-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

TERRAFORM_DIR="terraform"
DEPLOY_SCRIPT="./deploy-improved.sh"
START_TIME=$(date +%s)
SSH_KEY="${SSH_KEY:-$HOME/.ssh/devops-key.pem}"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}✅ $1${NC}"
}

fail() {
    echo -e "${RED}❌ $1${NC}"
    echo "🔍 Logs salvos em: $LOG_FILE"
    exit 1
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# =============================================================================
# FASE 1: Terraform Destroy
# =============================================================================
echo "═══════════════════════════════════════════"
echo "FASE 1: Terraform Destroy"
echo "═══════════════════════════════════════════"

cd "$TERRAFORM_DIR"

echo "🗑️  Executando terraform destroy..."
if terraform destroy -auto-approve; then
    pass "Infraestrutura destruída"
else
    fail "Erro no terraform destroy"
fi

sleep 5

# =============================================================================
# FASE 2: Terraform Apply
# =============================================================================
echo ""
echo "═══════════════════════════════════════════"
echo "FASE 2: Terraform Apply"
echo "═══════════════════════════════════════════"

echo "🏗️  Executando terraform apply..."
if terraform apply -auto-approve; then
    pass "Infraestrutura criada (25 recursos)"
else
    fail "Erro no terraform apply"
fi

# Capturar outputs
INSTANCE_ID=$(terraform output -raw instance_id)
PUBLIC_IP=$(terraform output -raw public_ip)

echo "📋 Instance ID: $INSTANCE_ID"
echo "🌐 Public IP: $PUBLIC_IP"

# =============================================================================
# FASE 3: Aguardar EC2 Status Checks
# =============================================================================
echo ""
echo "═══════════════════════════════════════════"
echo "FASE 3: Aguardar EC2 Healthy"
echo "═══════════════════════════════════════════"

echo "⏳ Aguardando 60s para boot inicial..."
sleep 60

MAX_WAIT=300
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATUS=$(aws ec2 describe-instance-status \
        --instance-ids "$INSTANCE_ID" \
        --region us-east-1 \
        --query 'InstanceStatuses[0].[SystemStatus.Status,InstanceStatus.Status]' \
        --output text 2>/dev/null || echo "initializing initializing")
    
    SYSTEM_STATUS=$(echo $STATUS | awk '{print $1}')
    INSTANCE_STATUS=$(echo $STATUS | awk '{print $2}')
    
    if [ "$SYSTEM_STATUS" = "ok" ] && [ "$INSTANCE_STATUS" = "ok" ]; then
        pass "EC2 status checks OK ($ELAPSED segundos)"
        break
    fi
    
    echo "⏳ Status: system=$SYSTEM_STATUS instance=$INSTANCE_STATUS (${ELAPSED}s)"
    sleep 15
    ELAPSED=$((ELAPSED + 15))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    fail "Timeout aguardando EC2 healthy (${MAX_WAIT}s)"
fi

# =============================================================================
# FASE 4: Deploy (setup + containers + configuração)
# =============================================================================
echo ""
echo "═══════════════════════════════════════════"
echo "FASE 4: Deploy Automático"
echo "═══════════════════════════════════════════"

cd ..

echo "🚀 Executando deploy-improved.sh $PUBLIC_IP..."
if $DEPLOY_SCRIPT "$PUBLIC_IP"; then
    pass "Deploy executado"
else
    fail "Erro no deploy-improved.sh"
fi

# =============================================================================
# FASE 5: Verificações
# =============================================================================
echo ""
echo "═══════════════════════════════════════════"
echo "FASE 5: Verificações de Saúde"
echo "═══════════════════════════════════════════"

# 5.1: Containers rodando
echo "🐳 Verificando containers..."
CONTAINERS=$(ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "docker ps --format '{{.Names}}' | wc -l" 2>/dev/null || echo "0")

if [ "$CONTAINERS" -eq 8 ]; then
    pass "8 containers rodando"
else
    fail "Esperado 8 containers, encontrado: $CONTAINERS"
fi

# 5.2: Tabelas Zabbix
echo "📊 Verificando tabelas Zabbix..."
TABLES=$(ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "docker exec mysql-server mysql -uroot -p\$(grep MYSQL_ROOT_PASSWORD /home/ubuntu/monitoring/.env | cut -d= -f2) -D zabbix -e 'SHOW TABLES;' 2>/dev/null | wc -l" || echo "0")

if [ "$TABLES" -eq 208 ]; then
    pass "208 tabelas Zabbix criadas"
else
    fail "Esperado 208 tabelas, encontrado: $TABLES"
fi

# 5.3: Grafana API
echo "📈 Testando Grafana API..."
GRAFANA_HEALTH=$(curl -s http://$PUBLIC_IP:3000/api/health | jq -r '.database' 2>/dev/null || echo "error")

if [ "$GRAFANA_HEALTH" = "ok" ]; then
    pass "Grafana API respondendo"
else
    fail "Grafana API não respondeu corretamente: $GRAFANA_HEALTH"
fi

# 5.4: Zabbix API
echo "🔍 Testando Zabbix API..."
ZABBIX_VERSION=$(curl -s -X POST http://$PUBLIC_IP:8080/api_jsonrpc.php \
    -H "Content-Type: application/json-rpc" \
    -d '{"jsonrpc":"2.0","method":"apiinfo.version","params":{},"id":1}' \
    | jq -r '.result' 2>/dev/null || echo "error")

if [[ "$ZABBIX_VERSION" =~ ^7\.[0-9]+\.[0-9]+$ ]]; then
    pass "Zabbix API respondendo (version $ZABBIX_VERSION)"
else
    fail "Zabbix API não respondeu: $ZABBIX_VERSION"
fi

# 5.5: Login Zabbix com senha do Secrets Manager
echo "🔐 Testando login Zabbix com senha do Secrets Manager..."
ZABBIX_PASS=$(ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "grep ZABBIX_ADMIN_PASSWORD /home/ubuntu/monitoring/.env | cut -d= -f2" 2>/dev/null)

ZABBIX_AUTH=$(curl -s -X POST http://$PUBLIC_IP:8080/api_jsonrpc.php \
    -H "Content-Type: application/json-rpc" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"user.login\",\"params\":{\"username\":\"Admin\",\"password\":\"$ZABBIX_PASS\"},\"id\":1}" \
    | jq -r '.result' 2>/dev/null || echo "null")

if [ "$ZABBIX_AUTH" != "null" ] && [ -n "$ZABBIX_AUTH" ]; then
    pass "Login Zabbix com senha do Secrets Manager OK"
else
    fail "Falha no login Zabbix com senha do Secrets Manager"
fi

# 5.6: Dashboards Grafana
echo "📊 Verificando dashboards Grafana..."
GRAFANA_USER=$(ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "grep GF_SECURITY_ADMIN_USER /home/ubuntu/monitoring/.env | cut -d= -f2" 2>/dev/null)
GRAFANA_PASS=$(ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "grep GF_SECURITY_ADMIN_PASSWORD /home/ubuntu/monitoring/.env | cut -d= -f2" 2>/dev/null)

DASHBOARDS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" http://$PUBLIC_IP:3000/api/search?type=dash-db \
    | jq '. | length' 2>/dev/null || echo "0")

if [ "$DASHBOARDS" -ge 2 ]; then
    pass "$DASHBOARDS dashboards Grafana importados"
else
    warn "Esperado >= 2 dashboards, encontrado: $DASHBOARDS"
fi

# =============================================================================
# RESUMO FINAL
# =============================================================================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ SMOKE TEST PASSOU!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⏱️  Tempo total: ${DURATION}s (~$((DURATION / 60))min)"
echo "🌐 Grafana: http://$PUBLIC_IP:3000"
echo "🔍 Zabbix: http://$PUBLIC_IP:8080"
echo "📋 Logs: $LOG_FILE"
echo ""
pass "Deploy 100% automatizado funcional!"

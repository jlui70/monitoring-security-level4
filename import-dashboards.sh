#!/bin/bash
source .env

echo "📊 Importando dashboards iniciais para o Grafana..."

# Aguardar Grafana estar disponível
echo "⏳ Aguardando Grafana estar disponível..."
until curl -s http://localhost:3000/api/health >/dev/null 2>&1; do
    echo "   Aguardando Grafana..."
    sleep 5
done

echo "✅ Grafana disponível!"

# Usar credenciais do .env
GRAFANA_USER="${GF_SECURITY_ADMIN_USER}"
GRAFANA_PASS="${GF_SECURITY_ADMIN_PASSWORD}"

# Configurar datasources se necessário
echo "🔗 Configurando datasources..."

# Verificar se Prometheus já existe
PROMETHEUS_EXISTS=$(curl -s -u ${GRAFANA_USER}:${GRAFANA_PASS} http://localhost:3000/api/datasources/name/Prometheus 2>/dev/null | grep -o '"name":"Prometheus"' || echo "")
if [ -z "$PROMETHEUS_EXISTS" ]; then
    echo "📈 Adicionando datasource Prometheus..."
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -u ${GRAFANA_USER}:${GRAFANA_PASS} \
        http://localhost:3000/api/datasources \
        -d '{
            "name": "Prometheus",
            "type": "prometheus",
            "url": "http://prometheus:9090",
            "access": "proxy",
            "isDefault": true
        }' >/dev/null
    echo "✅ Prometheus adicionado!"
else
    echo "✅ Prometheus já existe"
fi

# Verificar se Zabbix já existe
ZABBIX_EXISTS=$(curl -s -u ${GRAFANA_USER}:${GRAFANA_PASS} http://localhost:3000/api/datasources/name/Zabbix 2>/dev/null | grep -o '"name":"Zabbix"' || echo "")
if [ -z "$ZABBIX_EXISTS" ]; then
    echo "🎯 Adicionando datasource Zabbix..."
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -u ${GRAFANA_USER}:${GRAFANA_PASS} \
        http://localhost:3000/api/datasources \
        -d '{
            "name": "Zabbix",
            "type": "alexanderzobnin-zabbix-datasource",
            "url": "http://zabbix-web:8080/api_jsonrpc.php",
            "access": "proxy",
            "basicAuth": false,
            "jsonData": {
                "username": "'"${ZABBIX_ADMIN_USER}"'",
                "trends": true,
                "trendsFrom": "7d",
                "trendsRange": "4d"
            },
            "secureJsonData": {
                "password": "'"${ZABBIX_ADMIN_PASSWORD}"'"
            }
        }' >/dev/null
    echo "✅ Zabbix adicionado!"
else
    echo "✅ Zabbix já existe"
fi

echo "📋 Importando dashboards..."

DASHBOARD_DIR="./grafana/dashboards"

for dashboard_file in "$DASHBOARD_DIR"/*.json; do
    if [ -f "$dashboard_file" ]; then
        dashboard_name=$(basename "$dashboard_file" .json)
        echo "📊 Importando dashboard: $dashboard_name"
        
        # Descobrir UID do datasource Zabbix
        ZABBIX_UID=$(curl -s -u ${GRAFANA_USER}:${GRAFANA_PASS} "http://localhost:3000/api/datasources" | jq -r '.[] | select(.type=="alexanderzobnin-zabbix-datasource") | .uid')
        
        # Descobrir UID do datasource Prometheus
        PROMETHEUS_UID=$(curl -s -u ${GRAFANA_USER}:${GRAFANA_PASS} "http://localhost:3000/api/datasources" | jq -r '.[] | select(.type=="prometheus") | .uid')
        
        if [ -z "$ZABBIX_UID" ]; then
            echo "⚠️  Não foi possível descobrir UID do datasource Zabbix"
            dashboard_content=$(cat "$dashboard_file")
        else
            echo "   ✅ UID Zabbix: $ZABBIX_UID | Prometheus: $PROMETHEUS_UID"
            # Substituir UIDs hardcoded pelos UIDs reais e remover id/uid do dashboard
            dashboard_content=$(cat "$dashboard_file" | \
                jq --arg zabbix_uid "$ZABBIX_UID" --arg prom_uid "$PROMETHEUS_UID" \
                'del(.id, .uid) | 
                walk(if type == "object" and has("uid") and (.type == "alexanderzobnin-zabbix-datasource") then .uid = $zabbix_uid 
                     elif type == "object" and has("uid") and (.type == "prometheus") then .uid = $prom_uid
                     else . end)')
        fi
        
        # Criar arquivo temporário para evitar "Argument list too long"
        temp_file="/tmp/dashboard_${dashboard_name}_$$.json"
        echo "$dashboard_content" | jq -c '{dashboard: ., overwrite: true}' > "$temp_file"
        
        # Importar dashboard usando arquivo temporário
        IMPORT_RESULT=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -u ${GRAFANA_USER}:${GRAFANA_PASS} \
            http://localhost:3000/api/dashboards/db \
            -d @"$temp_file")
        
        # Limpar arquivo temporário
        rm -f "$temp_file"
        
        if echo "$IMPORT_RESULT" | grep -q '"status":"success"'; then
            echo "   ✅ Dashboard $dashboard_name importado!"
        else
            echo "   ⚠️  Erro ao importar $dashboard_name"
            echo "   Detalhes: $(echo $IMPORT_RESULT | jq -r '.message // .error // "Erro desconhecido"')"
        fi
    fi
done

echo ""
echo "🎉 Configuração completa!"
echo "📊 Dashboards importados e totalmente editáveis!"
echo "🔗 Acesse: http://localhost:3000 (${GRAFANA_USER}/${GRAFANA_PASS})"
echo ""
echo "💡 Agora você pode:"
echo "   • Editar dashboards livremente"
echo "   • Salvar modificações permanentemente"
echo "   • Criar novos dashboards"
echo "   • Duplicar e personalizar existentes"

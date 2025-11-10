#!/bin/bash

#############################################
# Restore Script for Monitoring Security Level 4 AWS
# Restores a backup created by backup.sh
#############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if backup file is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: No backup file specified${NC}"
    echo ""
    echo "Usage: $0 <backup-file.tar.gz>"
    echo ""
    echo "Available backups in ~/backups:"
    ls -lht ~/backups/monitoring-security-level4-aws-v2_backup_*.tar.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"
RESTORE_DIR="${2:-$(pwd)}"

echo -e "${GREEN}=== Monitoring Security Level 4 AWS - Restore Script ===${NC}"
echo "Backup file: ${BACKUP_FILE}"
echo "Restore to: ${RESTORE_DIR}"
echo ""

# Verify backup file exists
if [ ! -f "${BACKUP_FILE}" ]; then
    echo -e "${RED}Error: Backup file not found: ${BACKUP_FILE}${NC}"
    exit 1
fi

# Verify checksum if available
CHECKSUM_FILE="${BACKUP_FILE}.sha256"
if [ -f "${CHECKSUM_FILE}" ]; then
    echo -e "${YELLOW}Verifying backup integrity...${NC}"
    if sha256sum -c "${CHECKSUM_FILE}"; then
        echo -e "${GREEN}Checksum verified successfully${NC}"
    else
        echo -e "${RED}Checksum verification failed!${NC}"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    echo -e "${YELLOW}Warning: No checksum file found. Skipping verification.${NC}"
fi

# Extract backup
echo -e "${YELLOW}Extracting backup...${NC}"
TEMP_DIR=$(mktemp -d)
tar xzf "${BACKUP_FILE}" -C "${TEMP_DIR}"

# Find extracted directory
EXTRACTED_DIR=$(find "${TEMP_DIR}" -mindepth 1 -maxdepth 1 -type d)

if [ -z "${EXTRACTED_DIR}" ]; then
    echo -e "${RED}Error: Could not find extracted directory${NC}"
    rm -rf "${TEMP_DIR}"
    exit 1
fi

# Show backup info
if [ -f "${EXTRACTED_DIR}/BACKUP_INFO.txt" ]; then
    echo ""
    echo -e "${GREEN}Backup Information:${NC}"
    cat "${EXTRACTED_DIR}/BACKUP_INFO.txt"
    echo ""
fi

# Confirm restore
read -p "Proceed with restore? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    rm -rf "${TEMP_DIR}"
    exit 0
fi

# Copy files
echo -e "${YELLOW}Restoring project files...${NC}"
mkdir -p "${RESTORE_DIR}"
rsync -av "${EXTRACTED_DIR}/" "${RESTORE_DIR}/"

# Restore Docker volumes if they exist
if [ -d "${EXTRACTED_DIR}/docker-volumes" ]; then
    echo -e "${YELLOW}Docker volume backups found.${NC}"
    read -p "Restore Docker volumes? This will overwrite existing data! (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "${RESTORE_DIR}"
        
        # Restore Grafana data
        if [ -f "${EXTRACTED_DIR}/docker-volumes/grafana-data.tar.gz" ]; then
            echo "  - Restoring Grafana data..."
            docker volume create monitoring-security-level4-aws-v2_grafana-data 2>/dev/null || true
            docker run --rm \
                -v monitoring-security-level4-aws-v2_grafana-data:/data \
                -v "${EXTRACTED_DIR}/docker-volumes":/backup \
                alpine sh -c "cd /data && tar xzf /backup/grafana-data.tar.gz"
        fi
        
        # Restore Prometheus data
        if [ -f "${EXTRACTED_DIR}/docker-volumes/prometheus-data.tar.gz" ]; then
            echo "  - Restoring Prometheus data..."
            docker volume create monitoring-security-level4-aws-v2_prometheus-data 2>/dev/null || true
            docker run --rm \
                -v monitoring-security-level4-aws-v2_prometheus-data:/data \
                -v "${EXTRACTED_DIR}/docker-volumes":/backup \
                alpine sh -c "cd /data && tar xzf /backup/prometheus-data.tar.gz"
        fi
        
        # Restore Zabbix database
        if [ -f "${EXTRACTED_DIR}/docker-volumes/zabbix-db.sql" ]; then
            echo "  - Zabbix database backup found."
            echo "    To restore, start Docker containers and run:"
            echo "    docker-compose exec -T zabbix-mysql mysql -u zabbix -pzabbix_password zabbix < ${RESTORE_DIR}/docker-volumes/zabbix-db.sql"
        fi
    fi
fi

# Cleanup
rm -rf "${TEMP_DIR}"

echo ""
echo -e "${GREEN}=== Restore Completed Successfully ===${NC}"
echo "Project restored to: ${RESTORE_DIR}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review terraform/terraform.tfvars and update with your AWS settings"
echo "2. Run: cd ${RESTORE_DIR}/terraform && terraform init && terraform apply"
echo "3. Run: cd ${RESTORE_DIR} && docker-compose up -d"
echo "4. Verify all services are running properly"
echo ""
echo -e "${GREEN}Done!${NC}"

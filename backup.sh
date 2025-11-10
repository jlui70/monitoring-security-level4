#!/bin/bash

#############################################
# Backup Script for Monitoring Security Level 4 AWS
# Creates a timestamped backup of the entire project
#############################################

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
PROJECT_NAME="monitoring-security-level4-aws-v2"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="${PROJECT_NAME}_backup_${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Monitoring Security Level 4 AWS - Backup Script ===${NC}"
echo "Timestamp: ${TIMESTAMP}"
echo "Backup location: ${BACKUP_PATH}"
echo ""

# Create backup directory
echo -e "${YELLOW}Creating backup directory...${NC}"
mkdir -p "${BACKUP_PATH}"

# Get current directory
CURRENT_DIR=$(pwd)

# Backup project files
echo -e "${YELLOW}Backing up project files...${NC}"
rsync -av \
    --exclude 'node_modules' \
    --exclude '.git' \
    --exclude '*.log' \
    --exclude 'tmp' \
    --exclude '.terraform' \
    "${CURRENT_DIR}/" "${BACKUP_PATH}/"

# Backup Docker volumes (if running)
echo -e "${YELLOW}Checking for running Docker containers...${NC}"
if docker-compose ps | grep -q "Up"; then
    echo -e "${YELLOW}Backing up Docker volumes...${NC}"
    
    # Create volumes backup directory
    mkdir -p "${BACKUP_PATH}/docker-volumes"
    
    # Backup Grafana data
    if docker volume ls | grep -q "grafana-data"; then
        echo "  - Backing up Grafana data..."
        docker run --rm \
            -v monitoring-security-level4-aws-v2_grafana-data:/data \
            -v "${BACKUP_PATH}/docker-volumes":/backup \
            alpine tar czf /backup/grafana-data.tar.gz -C /data .
    fi
    
    # Backup Prometheus data
    if docker volume ls | grep -q "prometheus-data"; then
        echo "  - Backing up Prometheus data..."
        docker run --rm \
            -v monitoring-security-level4-aws-v2_prometheus-data:/data \
            -v "${BACKUP_PATH}/docker-volumes":/backup \
            alpine tar czf /backup/prometheus-data.tar.gz -C /data .
    fi
    
    # Backup Zabbix database
    if docker-compose ps | grep -q "zabbix-mysql"; then
        echo "  - Backing up Zabbix database..."
        docker-compose exec -T zabbix-mysql mysqldump -u zabbix -pzabbix_password zabbix \
            > "${BACKUP_PATH}/docker-volumes/zabbix-db.sql" 2>/dev/null || \
            echo "    Warning: Could not backup Zabbix database (may not be accessible)"
    fi
else
    echo "  No running containers found. Skipping Docker volumes backup."
fi

# Backup Terraform state from S3 (if configured)
echo -e "${YELLOW}Checking for Terraform remote state...${NC}"
if [ -f "${CURRENT_DIR}/terraform/terraform.tfstate" ]; then
    echo "  Local Terraform state found and backed up."
fi

# Create backup metadata
echo -e "${YELLOW}Creating backup metadata...${NC}"
cat > "${BACKUP_PATH}/BACKUP_INFO.txt" << EOF
Backup Information
==================
Project: ${PROJECT_NAME}
Backup Date: $(date)
Timestamp: ${TIMESTAMP}
Hostname: $(hostname)
User: $(whoami)
Source Directory: ${CURRENT_DIR}

Files Included:
- All project configuration files
- Terraform state and configuration
- Docker Compose configuration
- Grafana dashboards and provisioning
- Prometheus configuration
- Setup and deployment scripts
$(if docker-compose ps | grep -q "Up"; then echo "- Docker volumes (Grafana, Prometheus, Zabbix DB)"; fi)

Restore Instructions:
1. Extract backup to desired location
2. Review and update terraform.tfvars with your settings
3. Run terraform apply in terraform/ directory
4. If Docker volumes were backed up, restore them before running docker-compose up
5. Run setup and deployment scripts as needed

EOF

# Compress backup
echo -e "${YELLOW}Compressing backup...${NC}"
cd "${BACKUP_DIR}"
tar czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
BACKUP_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)

# Remove uncompressed backup
rm -rf "${BACKUP_NAME}"

# Calculate checksums
echo -e "${YELLOW}Calculating checksums...${NC}"
sha256sum "${BACKUP_NAME}.tar.gz" > "${BACKUP_NAME}.tar.gz.sha256"

echo ""
echo -e "${GREEN}=== Backup Completed Successfully ===${NC}"
echo "Backup file: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo "Size: ${BACKUP_SIZE}"
echo "Checksum: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz.sha256"
echo ""
echo -e "${YELLOW}To restore this backup:${NC}"
echo "1. tar xzf ${BACKUP_NAME}.tar.gz"
echo "2. cd ${BACKUP_NAME}"
echo "3. Review BACKUP_INFO.txt for restore instructions"
echo ""

# List recent backups
echo -e "${YELLOW}Recent backups in ${BACKUP_DIR}:${NC}"
ls -lht "${BACKUP_DIR}"/${PROJECT_NAME}_backup_*.tar.gz 2>/dev/null | head -5 || echo "No previous backups found"

echo ""
echo -e "${GREEN}Done!${NC}"

#!/bin/bash
# Database backup script for Macula Realm
# Creates timestamped PostgreSQL dumps

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REALM_DIR="${SCRIPT_DIR}/.."
BACKUP_DIR="${REALM_DIR}/backups"
DATE=$(date +%Y%m%d_%H%M%S)

if [ -f "${REALM_DIR}/.env" ]; then
    source "${REALM_DIR}/.env"
fi

POSTGRES_USER="${POSTGRES_USER:-macula_realm}"
POSTGRES_DB="${POSTGRES_DB:-macula_realm_prod}"

mkdir -p "${BACKUP_DIR}"

echo "Backing up PostgreSQL database..."
echo "  Database: ${POSTGRES_DB}"

docker compose -f "${REALM_DIR}/docker-compose.yml" exec -T postgres \
    pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" | \
    gzip > "${BACKUP_DIR}/macula_realm_${DATE}.sql.gz"

echo "Backup saved to: ${BACKUP_DIR}/macula_realm_${DATE}.sql.gz"

echo "Cleaning up old backups (keeping last 7 days)..."
find "${BACKUP_DIR}" -name "*.sql.gz" -mtime +7 -delete 2>/dev/null || true

echo "Current backups:"
ls -lh "${BACKUP_DIR}"/*.sql.gz 2>/dev/null || echo "  No backups found"

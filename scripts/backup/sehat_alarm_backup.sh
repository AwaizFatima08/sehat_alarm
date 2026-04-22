#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/mnt/storage/projects/sehat_alarm"
BACKUP_DIR="/mnt/storage/backups/sehat_alarm"
TAG="${1:-manual}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
ARCHIVE="${BACKUP_DIR}/sehat_alarm_${TIMESTAMP}_${TAG}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "Creating backup: $ARCHIVE"

tar -czf "$ARCHIVE" \
  --exclude='build' \
  --exclude='.dart_tool' \
  --exclude='.git' \
  --exclude='node_modules' \
  -C "$PROJECT_DIR" .

echo "Backup completed successfully: $ARCHIVE"

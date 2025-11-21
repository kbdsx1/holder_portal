#!/bin/bash

# Database Restore Script
# Usage: ./restore-db.sh "<NEW_CONNECTION_STRING>"

if [ -z "$1" ]; then
  echo "❌ Error: Connection string required"
  echo ""
  echo "Usage: ./restore-db.sh \"<NEW_CONNECTION_STRING>\""
  echo ""
  echo "Example:"
  echo "  ./restore-db.sh \"postgresql://user:pass@host/db?sslmode=require\""
  exit 1
fi

# Find the most recent backup file
BACKUP_FILE=$(ls -t cannasolz-db-backup-*.sql 2>/dev/null | head -n 1)

if [ -z "$BACKUP_FILE" ]; then
  echo "❌ Error: No backup file found"
  echo "   Expected file pattern: cannasolz-db-backup-*.sql"
  exit 1
fi

echo "=== Restoring Database ==="
echo "Backup file: $BACKUP_FILE"
echo "Target: $1"
echo ""
echo "⚠️  This will DROP and recreate all tables in the target database!"
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "❌ Restore cancelled"
  exit 1
fi

echo ""
echo "Restoring..."
psql "$1" -f "$BACKUP_FILE"

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Database restored successfully!"
  echo ""
  echo "=== Verification ==="
  echo "You can verify by running:"
  echo "  psql \"$1\" -c \"\\dt\""
else
  echo ""
  echo "❌ Restore failed!"
  exit 1
fi

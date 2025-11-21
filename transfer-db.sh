#!/bin/bash

# Database Transfer Script
# This script creates a complete backup and provides instructions for restoring

SOURCE_DB="postgresql://neondb_owner:npg_j91fPEHqwDOl@ep-sparkling-art-adye29md-pooler.c-2.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"
BACKUP_FILE="cannasolz-db-backup-$(date +%Y%m%d-%H%M%S).sql"

echo "=== Creating Database Backup ==="
echo "Source: $SOURCE_DB"
echo "Backup file: $BACKUP_FILE"
echo ""

# Create full backup (schema + data + functions + triggers)
pg_dump "$SOURCE_DB" \
  --verbose \
  --clean \
  --if-exists \
  --no-owner \
  --no-acl \
  --format=plain \
  --file="$BACKUP_FILE"

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Backup created successfully: $BACKUP_FILE"
  echo ""
  echo "File size: $(du -h "$BACKUP_FILE" | cut -f1)"
  echo ""
  echo "=== Next Steps ==="
  echo "1. Create a new database in your cannasolz Neon account"
  echo "2. Get the connection string for the new database"
  echo "3. Run: psql \"<NEW_CONNECTION_STRING>\" -f $BACKUP_FILE"
  echo ""
  echo "Or restore using:"
  echo "  psql \"<NEW_CONNECTION_STRING>\" < $BACKUP_FILE"
else
  echo "❌ Backup failed!"
  exit 1
fi

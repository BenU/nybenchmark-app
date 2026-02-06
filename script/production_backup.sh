#!/bin/bash
# script/production_backup.sh
# -----------------------------------------------------------------------------
# Backs up the production Postgres database from the Docker container
# and uploads it to DigitalOcean Spaces.
#
# Usage: Add to crontab on the host machine.
# -----------------------------------------------------------------------------

set -e

# Configuration
CONTAINER_NAME="nybenchmark_app-db"
DB_USER="nybenchmark_app"
DB_NAME="nybenchmark_app_production"
BUCKET="s3://nybenchmark-production/db-backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H%M")
FILENAME="backup_${TIMESTAMP}.sql.gz"
TEMP_FILE="/tmp/${FILENAME}"

# 1. Dump and Compress
echo "[$(date)] Starting backup for ${DB_NAME}..."
docker exec $CONTAINER_NAME pg_dump -U $DB_USER $DB_NAME | gzip > $TEMP_FILE

# 2. Upload to DigitalOcean Spaces (via AWS CLI)
echo "[$(date)] Uploading to ${BUCKET}..."
/snap/bin/aws s3 cp $TEMP_FILE $BUCKET/${FILENAME} --endpoint-url https://nyc3.digitaloceanspaces.com

# 3. Cleanup local temp file
rm $TEMP_FILE

# 4. Delete backups older than 30 days
CUTOFF=$(date -d '-30 days' +%Y-%m-%d)
echo "[$(date)] Removing backups older than ${CUTOFF}..."
/snap/bin/aws s3 ls $BUCKET/ --endpoint-url https://nyc3.digitaloceanspaces.com \
  | while read -r DATE TIME SIZE FILE; do
      if [[ "$DATE" < "$CUTOFF" ]] && [[ -n "$FILE" ]]; then
        echo "[$(date)] Deleting $FILE"
        /snap/bin/aws s3 rm "$BUCKET/$FILE" --endpoint-url https://nyc3.digitaloceanspaces.com
      fi
    done

echo "[$(date)] Backup complete: ${FILENAME}"
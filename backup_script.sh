#!/bin/bash

# === Configuration ===
declare -a SOURCES=(
"/mnt/user/Software"
"/mnt/user/Media"
"/mnt/user/backups"
)

DEST=/tmp/backups
EMAIL_TO="test@example.com"
EMAIL_SUBJECT="Backup Report - $(date +%Y-%m-%d)"

SUCCESS=1

# === Log Setup ===
LOG_DIR="/tmp/backup_logs"
mkdir -p "$LOG_DIR"

# Rotate logs: keep only the 7 most recent
MAX_LOGS=7
find "$LOG_DIR" -type f -name "backup_log_*.log" | sort | head -n -"$MAX_LOGS" | xargs -r rm

# Create new log file
LOG_FILE="$LOG_DIR/backup_log_$(date +%Y-%m-%d_%H%M%S).log"

# Verify writable
if ! touch "$LOG_FILE"; then
    echo "❌ Failed to create log file at $LOG_FILE"
    exit 1
fi




# === Start Log ===
echo -e "Backup started at $(date) \n" >> "$LOG_FILE"

#check if directories exists
if [ ! -d "$DEST" ]; then
    echo "Destination directory $DEST does not exist." | tee -a "$LOG_FILE"
    SUCCESS=0
fi
for name in "${!SOURCES[@]}"; do
    SRC="${SOURCES[$name]}"
    if [ ! -d "$SRC" ]; then
        echo "Source directory $SRC does not exist." | tee -a "$LOG_FILE"
        SUCCESS=0
    fi
done


# === Loop through backup sources ===
if [ $SUCCESS -eq 1 ]; then
    for name in "${!SOURCES[@]}"; do
        SRC="${SOURCES[$name]}"
        echo "Starting backup for ($SRC)" | tee -a "$LOG_FILE"
        
        start_time=$(date +%s)

        rsync_output=$(rsync -av --stats "$SRC" "$DEST"  2>&1)
        # Extract desired stats and append to log
        {
            echo "$rsync_output" | grep -E "Number of files transferred|Total file size|Total transferred file size|Number of files:" 
        } >> "$LOG_FILE"
      
        

        end_time=$(date +%s)
        duration=$((end_time - start_time))
        if [ $? -eq 0 ]; then
            echo -e "Finished backup for $SRC in $duration seconds.\n" | tee -a "$LOG_FILE"
        else
            echo -e "Backup failed for $SRC.\n" | tee -a "$LOG_FILE"
            SUCCESS=0
        fi
    done
fi

# === Finalize Log ===
echo "Backup completed at $(date)" >> "$LOG_FILE"

if [ $SUCCESS -eq 0 ]; then
   EMAIL_SUBJECT="Backup Failure - $(date +%Y-%m-%d)"
   echo "Backup Failure"
   else
   echo "backup script complete"
fi

# === Email the Log ===
if command -v /usr/local/emhttp/webGui/scripts/notify >/dev/null 2>&1; then
    # Use Unraid's notify script
    /usr/local/emhttp/webGui/scripts/notify -i normal -s "$EMAIL_SUBJECT" -d "$(tail -n 20 "$LOG_FILE")"
elif command -v mail >/dev/null 2>&1; then
    #use mail command
    cat "$LOG_FILE" | mail -s "$EMAIL_SUBJECT" "$EMAIL_TO"
else
    echo "mail commands not found; skipping email step." | tee -a "$LOG_FILE"
fi

# Optional: Clean up log if not needed
# rm "$LOG_FILE"
#/usr/local/emhttp/webGui/scripts/notify -i normal -s "Cache Drive Backup Completed" -d " Cache Drive Backup completed at `date`"
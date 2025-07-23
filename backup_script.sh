#!/bin/bash

# === Configuration ===
declare -a SOURCES
SOURCES["Documents"]="/home/andy/Documents"
SOURCES["Pictures"]="/home/andy/Pictures"
SOURCES["Projects"]="/home/andy/Projects"

DEST="/tmp/backup_drive"
EMAIL_TO="your@email.com"
EMAIL_SUBJECT="Backup Report - $(date +%Y-%m-%d)"
LOG_FILE="/tmp/backup_log_$(date +%Y-%m-%d_%H%M%S).log"

SUCCESS=1

# Try creating the log file
if ! touch "$LOG_FILE"; then
    echo "❌ Failed to create log file at $LOG_FILE"
    exit 1
fi

# === Start Log ===
echo "Backup started at $(date)" >> "$LOG_FILE"
echo "----------------------------------------" >> "$LOG_FILE"

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
        echo "Starting backup for $name ($SRC)" | tee -a "$LOG_FILE"
        
        start_time=$(date +%s)

        rsync -av --stats --delete "$SRC/" "$DEST" | sed '0,/^$/d' >> "$LOG_FILE" 2>&1

        end_time=$(date +%s)
        duration=$((end_time - start_time))
        if [ $? -eq 0 ]; then
            echo "Finished backup for $name in $duration seconds." | tee -a "$LOG_FILE"
        else
            echo "Backup failed for $name." | tee -a "$LOG_FILE"
            SUCCESS=0
        fi
        echo "----------------------------------------" >> "$LOG_FILE"
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
    /usr/local/emhttp/webGui/scripts/notify -i normal -s "$EMAIL_SUBJECT" -d "Backup completed at $(date)" -l "$LOG_FILE"
elif command -v mail >/dev/null 2>&1; then
    #use mail command
    cat "$LOG_FILE" | mail -s "$EMAIL_SUBJECT" "$EMAIL_TO"
else
    echo "mail commands not found; skipping email step." | tee -a "$LOG_FILE"
fi

# Optional: Clean up log if not needed
# rm "$LOG_FILE"
#/usr/local/emhttp/webGui/scripts/notify -i normal -s "Cache Drive Backup Completed" -d " Cache Drive Backup completed at `date`"
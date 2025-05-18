#!/bin/bash

RATHENA_DIR=${RATHENA_DIR:-/rAthena}
LOG_DIR="${RATHENA_DIR}/logs"
DATE=$(date +%F)  # YYYY-MM-DD format

mkdir -p "$LOG_DIR"

echo "📜 Starting rAthena servers with daily log rotation..."

# Start char-server
"$RATHENA_DIR"/char-server > "$LOG_DIR/char-${DATE}.log" 2>&1 &
echo "🧑 char-server started (log: $LOG_DIR/char-${DATE}.log)"

# Start login-server
"$RATHENA_DIR"/login-server > "$LOG_DIR/login-${DATE}.log" 2>&1 &
echo "🔐 login-server started (log: $LOG_DIR/login-${DATE}.log)"

# Start map-server
"$RATHENA_DIR"/map-server > "$LOG_DIR/map-${DATE}.log" 2>&1 &
echo "🗺️ map-server started (log: $LOG_DIR/map-${DATE}.log)"

# Start web-server
"$RATHENA_DIR"/web-server > "$LOG_DIR/web-${DATE}.log" 2>&1 &
echo "🗺️ web-server started (log: $LOG_DIR/web-${DATE}.log)"

# Wait for all to end (optional)
wait

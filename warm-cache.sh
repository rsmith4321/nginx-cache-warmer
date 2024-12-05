#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
SITEMAP_INDEX_URL="https://example.com/sitemap.xml"  # Change to your sitemap URL
TIME_ZONE="${1:-UTC}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOGS_DIR="$SCRIPT_DIR/logs"
LOG_RETENTION_DAYS=7

# Define User-Agent string
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Ensure logs directory exists
mkdir -p "$LOGS_DIR"

# Generate daily log file name
current_date=$(TZ=$TIME_ZONE date '+%Y-%m-%d')
LOG_FILE="$LOGS_DIR/index_$current_date.html"

# Function to initialize the log file
initialize_log_file() {
    if [ ! -f "$LOG_FILE" ]; then
        cat > "$LOG_FILE" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Cache Warming Log - $current_date</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 10px; background-color: #f4f4f9; font-size: 12px; }
        .log-entry { padding: 2px 0; line-height: 1.4; }
        .success { color: green; }
        .error { color: red; font-weight: bold; }
        .status { color: blue; }
        .timestamp { font-weight: bold; color: #555; }
        .log-section {
            border: 1px solid #ddd;
            border-radius: 4px;
            margin: 10px 0;
            padding: 10px;
            background-color: white;
        }
        .section-header {
            font-size: 14px;
            font-weight: bold; color: #333;
            margin-bottom: 10px;
            padding-bottom: 5px;
            border-bottom: 1px solid #eee;
        }
    </style>
</head>
<body>
    <h1>Cache Warming Log - $current_date</h1>
    <div class="log-container">
    </div>
</body>
</html>
EOF
    fi
}

# Function to add log entry
log_entry() {
    local message=$1
    local class=${2:-}
    local timestamp=$(TZ=$TIME_ZONE date '+%Y-%m-%d %H:%M:%S')
    echo "        <p class='log-entry${class:+ }${class}'><span class='timestamp'>[$timestamp]</span> $message</p>" >> "$TEMP_LOG"
}

# Rotate logs and initialize today's log
initialize_log_file

# Initialize temporary log file with section header
TEMP_LOG="$SCRIPT_DIR/temp_log.txt"
CURRENT_TIME=$(TZ=$TIME_ZONE date '+%Y-%m-%d %H:%M:%S %Z')
cat > "$TEMP_LOG" <<EOF
    <div class="log-section">
        <div class="section-header">Cache Warming Session - $CURRENT_TIME</div>
EOF

# Start logging
log_entry "Starting cache warming session..."

# Process sitemap and warm cache
{
    # Get all URLs from sitemap index and sub-sitemaps
    curl -s -A "$USER_AGENT" "$SITEMAP_INDEX_URL" | grep -oE '<loc>[^<]+</loc>' | sed -e 's/<loc>//g' -e 's|</loc>||g' | while read -r sitemap; do
        log_entry "Processing sitemap: $sitemap"
        curl -s -A "$USER_AGENT" "$sitemap" | grep -oE '<loc>[^<]+</loc>' | sed -e 's/<loc>//g' -e 's|</loc>||g' | while read -r url; do
            echo "Visiting: $url"
            http_status=$(curl -s -A "$USER_AGENT" -o /dev/null -w "%{http_code}" "$url")
            log_entry "$url - Status: <span class='status'>$http_status</span>"
            sleep 1
        done
    done
} || {
    log_entry "Failed to process sitemap" "error"
    echo "    </div>" >> "$TEMP_LOG"
    sed -i.bak "/class=\"log-container\">/r $TEMP_LOG" "$LOG_FILE"
    rm -f "$LOG_FILE.bak" "$TEMP_LOG"
    exit 1
}

log_entry "Cache warming completed" "success"

# Close the log section
echo "    </div>" >> "$TEMP_LOG"

# Insert the new section at the top of the log container
sed -i.bak "/class=\"log-container\">/r $TEMP_LOG" "$LOG_FILE"
rm -f "$LOG_FILE.bak" "$TEMP_LOG"

# Clean up old logs
find "$LOGS_DIR" -type f -name "index_*.html" -mtime +$LOG_RETENTION_DAYS -exec rm -f {} \; || true

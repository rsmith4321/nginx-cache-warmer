#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

SITEMAP_INDEX_URL="https://example.com/sitemap.xml"  # Change to your sitemap URL
TIME_ZONE="${1:-UTC}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/index.html"
TEMP_LOG="$SCRIPT_DIR/temp_log.txt"

# Define User-Agent string
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Create or rotate log file
if [ -f "$LOG_FILE" ] && [ "$(find "$LOG_FILE" -mmin +1440)" ]; then
    mv "$LOG_FILE" "$SCRIPT_DIR/logs/index_$(TZ=$TIME_ZONE date +%Y-%m-%d_%H-%M-%S).html"
fi

# Initialize log file if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    mkdir -p "$SCRIPT_DIR/logs"
    cat > "$LOG_FILE" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Cache Warming Log</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 10px; background-color: #f4f4f9; font-size: 12px; }
        .log-entry { padding: 2px 0; line-height: 0; }
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
            font-weight: bold;
            color: #333;
            margin-bottom: 10px;
            padding-bottom: 5px;
            border-bottom: 1px solid #eee;
        }
    </style>
</head>
<body>
    <h1>Cache Warming Log - $(TZ=$TIME_ZONE date '+%Y-%m-%d')</h1>
    <div class="log-container">
    </div>
</body>
</html>
EOF
fi

# Initialize temporary log file with section header
CURRENT_TIME=$(TZ=$TIME_ZONE date '+%Y-%m-%d %H:%M:%S %Z')
cat > "$TEMP_LOG" <<EOF
    <div class="log-section">
        <div class="section-header">Cache Warming Session - $CURRENT_TIME</div>
EOF

# Function to add log entry
log_entry() {
    local message=$1
    local class=${2:-}
    local timestamp=$(TZ=$TIME_ZONE date '+%Y-%m-%d %H:%M:%S')
    echo "        <p class='log-entry${class:+ }${class}'><span class='timestamp'>[$timestamp]</span> $message</p>" >> "$TEMP_LOG"
}

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
    # Insert the new section at the top of the log container
    sed -i.bak "/class=\"log-container\">/r $TEMP_LOG" "$LOG_FILE"
    rm "$LOG_FILE.bak" "$TEMP_LOG"
    exit 1
}

log_entry "Cache warming completed" "success"

# Close the log section
echo "    </div>" >> "$TEMP_LOG"

# Insert the new section at the top of the log container
sed -i.bak "/class=\"log-container\">/r $TEMP_LOG" "$LOG_FILE"
rm "$LOG_FILE.bak" "$TEMP_LOG"

# Clean up old logs
find "$SCRIPT_DIR/logs" -type f -name "index_*.html" -mtime +7 -exec rm {} \;

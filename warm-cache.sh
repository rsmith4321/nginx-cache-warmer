#!/bin/bash

# Hardcoded sitemap URL
SITEMAP_INDEX_URL="https://example.com/sitemap.xml"  # Change to your sitemap URL

# Check for time zone argument
if [ $# -gt 1 ]; then
  echo "Usage: $0 [<time_zone>]"
  exit 1
fi

# Optional time zone (passed as the first argument), defaulting to UTC
TIME_ZONE="${1:-UTC}"

# Directory paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
CURRENT_LOG_FILE="$SCRIPT_DIR/index.html"
TEMP_LOG_FILE="$SCRIPT_DIR/temp_log.html"
SITEMAP_LIST="$SCRIPT_DIR/sitemap_list.txt"
PAGE_URLS="$SCRIPT_DIR/page_urls.txt"

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

# Functions for date formatting
format_date() {
  TZ="$TIME_ZONE" date "+%Y-%m-%d %H:%M:%S"
}

format_date_filename() {
  TZ="$TIME_ZONE" date "+%Y-%m-%d_%H-%M-%S"
}

# Start the temporary log file with basic HTML structure
cat <<EOF > "$TEMP_LOG_FILE"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Cache Warming Log</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 10px; background-color: #f4f4f9; font-size: 12px; }
        .log-entry { padding: 2px 0; }
        .success { color: green; }
        .error { color: red; font-weight: bold; }
        .status { color: blue; }
        .timestamp { font-weight: bold; color: #555; }
    </style>
</head>
<body>
    <h1>Cache Warming Log</h1>
    <div>
EOF

# Fetch sitemap and extract URLs
echo "<p class='log-entry'><span class='timestamp'>[$(format_date)]</span> Fetching sitemap index: $SITEMAP_INDEX_URL...</p>" >> "$TEMP_LOG_FILE"
curl -s "$SITEMAP_INDEX_URL" | grep -oE '<loc>[^<]+</loc>' | sed -e 's/<loc>//g' -e 's|</loc>||g' > "$SITEMAP_LIST"

if [ ! -s "$SITEMAP_LIST" ]; then
  echo "<p class='log-entry error'><span class='timestamp'>[$(format_date)]</span> No sitemap URLs found.</p>" >> "$TEMP_LOG_FILE"
  echo "</div></body></html>" >> "$TEMP_LOG_FILE"
  cat "$TEMP_LOG_FILE" >> "$CURRENT_LOG_FILE"
  rm "$TEMP_LOG_FILE"
  exit 1
fi

# Extract page URLs from sitemap
echo "<p class='log-entry'><span class='timestamp'>[$(format_date)]</span> Extracting page URLs...</p>" >> "$TEMP_LOG_FILE"
> "$PAGE_URLS"

while read -r sitemap_url; do
  echo "<p class='log-entry'><span class='timestamp'>[$(format_date)]</span> Processing: $sitemap_url</p>" >> "$TEMP_LOG_FILE"
  curl -s "$sitemap_url" | grep -oE '<loc>[^<]+</loc>' | sed -e 's/<loc>//g' -e 's|</loc>||g' >> "$PAGE_URLS" || {
    echo "<p class='log-entry error'><span class='timestamp'>[$(format_date)]</span> Failed to process: $sitemap_url</p>" >> "$TEMP_LOG_FILE"
  }
done < "$SITEMAP_LIST"

if [ ! -s "$PAGE_URLS" ]; then
  echo "<p class='log-entry error'><span class='timestamp'>[$(format_date)]</span> No page URLs found.</p>" >> "$TEMP_LOG_FILE"
  rm "$SITEMAP_LIST"
  echo "</div></body></html>" >> "$TEMP_LOG_FILE"
  cat "$TEMP_LOG_FILE" >> "$CURRENT_LOG_FILE"
  rm "$TEMP_LOG_FILE"
  exit 1
fi

# Visit each page URL
echo "<p class='log-entry'><span class='timestamp'>[$(format_date)]</span> Visiting URLs...</p>" >> "$TEMP_LOG_FILE"
while read -r url; do
  http_status=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  echo "<p class='log-entry'><span class='timestamp'>[$(format_date)]</span> $url - Status: <span class='status'>$http_status</span></p>" >> "$TEMP_LOG_FILE"
  sleep 1  # Rate limiting
done < "$PAGE_URLS"

rm "$SITEMAP_LIST" "$PAGE_URLS"

echo "<p class='log-entry success'><span class='timestamp'>[$(format_date)]</span> Completed.</p>" >> "$TEMP_LOG_FILE"
echo "</div></body></html>" >> "$TEMP_LOG_FILE"

# Rotate logs if a new day has started
if [ -f "$CURRENT_LOG_FILE" ]; then
  current_date=$(date '+%Y-%m-%d')
  existing_log_date=$(date -r "$CURRENT_LOG_FILE" '+%Y-%m-%d')

  if [ "$current_date" != "$existing_log_date" ]; then
    mv "$CURRENT_LOG_FILE" "$LOG_DIR/index_$(format_date_filename).html"
  fi
fi

# Append new logs to the current log file
cat "$TEMP_LOG_FILE" >> "$CURRENT_LOG_FILE"
rm "$TEMP_LOG_FILE"

# Move older logs to /logs and delete those older than 5 days
find "$LOG_DIR" -type f -name "index_*.html" -mtime +5 -exec rm {} \;

#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

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

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

# Functions for date formatting
format_date() {
  TZ="$TIME_ZONE" date "+%Y-%m-%d %H:%M:%S"
}

format_date_filename() {
  TZ="$TIME_ZONE" date "+%Y-%m-%d_%H-%M-%S"
}

# Rotate current log if it is older than 24 hours
echo "Checking if the current log file needs rotation..."
if [ -f "$CURRENT_LOG_FILE" ] && [ "$(find "$CURRENT_LOG_FILE" -mmin +1440)" ]; then
  echo "Log file is older than 24 hours. Rotating..."
  mv "$CURRENT_LOG_FILE" "$LOG_DIR/index_$(format_date_filename).html"
else
  echo "No log rotation needed."
fi

# Create a new log file with the initial HTML structure if it doesn't exist or was rotated
if [ ! -f "$CURRENT_LOG_FILE" ]; then
  echo "Creating a new log file: $CURRENT_LOG_FILE"
  cat <<EOF > "$CURRENT_LOG_FILE"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Cache Warming Log</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 10px; background-color: #f4f4f9; font-size: 12px; }
        .log-entry { padding: 2px 0; line-height: 0 }
        .success { color: green; }
        .error { color: red; font-weight: bold; }
        .status { color: blue; }
        .timestamp { font-weight: bold; color: #555; }
    </style>
</head>
<body>
    <h1>Cache Warming Log - $(TZ="$TIME_ZONE" date '+%Y-%m-%d')</h1>
    <div>
EOF
else
  echo "Log file already exists and is up-to-date."
fi

# Start the temporary log file
echo "Starting temporary log file: $TEMP_LOG_FILE"
echo "<div>" > "$TEMP_LOG_FILE"

# Fetch sitemap and extract URLs
echo "Fetching sitemap index..."
echo "<p class='log-entry'><span class='timestamp'>[$(format_date)]</span> Fetching sitemap index: $SITEMAP_INDEX_URL...</p>" >> "$TEMP_LOG_FILE"
if ! curl -s "$SITEMAP_INDEX_URL" | grep -oE '<loc>[^<]+</loc>' | sed -e 's/<loc>//g' -e 's|</loc>||g' > "$SCRIPT_DIR/sitemap_list.txt"; then
  echo "Error: Failed to fetch or parse sitemap."
  echo "<p class='log-entry error'><span class='timestamp'>[$(format_date)]</span> Failed to fetch or parse sitemap.</p>" >> "$TEMP_LOG_FILE"
  exit 1
fi

if [ ! -s "$SCRIPT_DIR/sitemap_list.txt" ]; then
  echo "No sitemap URLs found."
  echo "<p class='log-entry error'><span class='timestamp'>[$(format_date)]</span> No sitemap URLs found.</p>" >> "$TEMP_LOG_FILE"
  echo "</div>" >> "$TEMP_LOG_FILE"
  cat "$TEMP_LOG_FILE" "$CURRENT_LOG_FILE" > "${CURRENT_LOG_FILE}.tmp" && mv "${CURRENT_LOG_FILE}.tmp" "$CURRENT_LOG_FILE"
  rm "$TEMP_LOG_FILE"
  exit 1
fi

# Extract page URLs from sitemap
echo "Extracting page URLs..."
echo "<p class='log-entry'><span class='timestamp'>[$(format_date)]</span> Extracting page URLs...</p>" >> "$TEMP_LOG_FILE"
> "$SCRIPT_DIR/page_urls.txt"

while read -r sitemap_url; do
  echo "Processing sitemap URL: $sitemap_url"
  echo "<p class='log-entry'><span class='timestamp'>[$(format_date)]</span> Processing: $sitemap_url</p>" >> "$TEMP_LOG_FILE"
  if ! curl -s "$sitemap_url" | grep -oE '<loc>[^<]+</loc>' | sed -e 's/<loc>//g' -e 's|</loc>||g' >> "$SCRIPT_DIR/page_urls.txt"; then
    echo "Error: Failed to process $sitemap_url"
    echo "<p class='log-entry error'><span class='timestamp'>[$(format_date)]</span> Failed to process: $sitemap_url</p>" >> "$TEMP_LOG_FILE"
  fi
done < "$SCRIPT_DIR/sitemap_list.txt"

if [ ! -s "$SCRIPT_DIR/page_urls.txt" ]; then
  echo "No page URLs found."
  echo "<p class='log-entry error'><span class='timestamp'>[$(format_date)]</span> No page URLs found.</p>" >> "$TEMP_LOG_FILE"
  rm "$SCRIPT_DIR/sitemap_list.txt"
  echo "</div>" >> "$TEMP_LOG_FILE"
  cat "$TEMP_LOG_FILE" "$CURRENT_LOG_FILE" > "${CURRENT_LOG_FILE}.tmp" && mv "${CURRENT_LOG_FILE}.tmp" "$CURRENT_LOG_FILE"
  rm "$TEMP_LOG_FILE"
  exit 1
fi

# Visit each page URL
echo "Visiting page URLs..."
echo "<p class='log-entry'><span class='timestamp'>[$(format_date)]</span> Visiting URLs...</p>" >> "$TEMP_LOG_FILE"
while read -r url; do
  echo "Visiting URL: $url"
  http_status=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  echo "Status for $url: $http_status"
  echo "<p class='log-entry'><span class='timestamp'>[$(format_date)]</span> $url - Status: <span class='status'>$http_status</span></p>" >> "$TEMP_LOG_FILE"
  sleep 1  # Rate limiting
done < "$SCRIPT_DIR/page_urls.txt"

# Clean up intermediate files
rm "$SCRIPT_DIR/sitemap_list.txt" "$SCRIPT_DIR/page_urls.txt"

# Finalize the log
echo "<p class='log-entry success'><span class='timestamp'>[$(format_date)]</span> Completed.</p>" >> "$TEMP_LOG_FILE"
echo "</div>" >> "$TEMP_LOG_FILE"

# Append new logs to the current log file while maintaining the full structure
echo "Appending logs to the current log file..."
{
  head -n -2 "$CURRENT_LOG_FILE"
  cat "$TEMP_LOG_FILE"
  echo "</body></html>"
} > "${CURRENT_LOG_FILE}.tmp" && mv "${CURRENT_LOG_FILE}.tmp" "$CURRENT_LOG_FILE"

# Clean up temporary log file
rm "$TEMP_LOG_FILE"

# Delete logs older than 7 days
echo "Deleting logs older than 7 days in $LOG_DIR..."
find "$LOG_DIR" -type f -name "index_*.html" -mtime +7 -exec rm {} \;

echo "Script completed successfully."

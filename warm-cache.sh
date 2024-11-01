#!/bin/bash

# Hardcoded sitemap URL
SITEMAP_INDEX_URL="https://example.com/sitemap.xml"  # Change to your sitemap URL

# Check for the time zone argument
if [ $# -gt 1 ]; then
  echo "Usage: $0 [<time_zone>]"
  exit 1
fi

# Optional time zone (passed as the first argument), defaulting to UTC
TIME_ZONE="${1:-UTC}"

# Directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/index.html"  # Change the final log file name to index.html
TEMP_LOG_FILE="$SCRIPT_DIR/temp_log.html"
SITEMAP_LIST="$SCRIPT_DIR/sitemap_list.txt"
PAGE_URLS="$SCRIPT_DIR/page_urls.txt"

# Ensure the log file exists
if [ ! -f "$LOG_FILE" ]; then
  touch "$LOG_FILE"  # Create the index.html file if it does not exist
fi

# Function to format the date based on the specified time zone
format_date() {
  TZ="$TIME_ZONE" date
}

# Step 1: Start temporary log document with proper HTML and compact CSS
cat <<EOF > "$TEMP_LOG_FILE"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Warm Cache Log</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 10px; background-color: #f4f4f9; font-size: 12px; } /* Reduced font size */
        .log-entry { margin: 0; padding: 2px 0; } /* Reduced margin and padding */
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

# Fetch the sitemap index and extract sitemap URLs
echo "<p class='log-entry'><span class='timestamp'>[$(format_date)]</span> Fetching sitemap index from the public URL: $SITEMAP_INDEX_URL...</p>" >> "$TEMP_LOG_FILE"
curl -s "$SITEMAP_INDEX_URL" | grep -oE '<loc>[^<]+</loc>' | sed -e 's/<loc>//g' -e 's|</loc>||g' > "$SITEMAP_LIST"

# Check if sitemap URLs were found
if [ ! -s "$SITEMAP_LIST" ]; then
  echo "<p class='log-entry error'><span class='timestamp'>[$(format_date)]</span> No sitemap URLs found in the sitemap index.</p>" >> "$TEMP_LOG_FILE"
  echo "</div></body></html>" >> "$TEMP_LOG_FILE"
  cat "$TEMP_LOG_FILE" >> "$LOG_FILE"
  rm "$TEMP_LOG_FILE"  # Ensure temp_log.html is removed
  exit 1
fi

# Step 2: Loop through each sitemap URL to extract page URLs
echo "<p class='log-entry'><span class='timestamp'>[$(format_date)]</span> Fetching page URLs from nested sitemaps...</p>" >> "$TEMP_LOG_FILE"
> "$PAGE_URLS"  # Clear previous page URLs file

while IFS= read -r sitemap_url; do
  echo "<p class='log-entry'><span class='timestamp'>[$(format_date)]</span> Processing sitemap: $sitemap_url</p>" >> "$TEMP_LOG_FILE"
  
  # Check if curl command succeeded
  if ! curl -s "$sitemap_url" | grep -oE '<loc>[^<]+</loc>' | sed -e 's/<loc>//g' -e 's|</loc>||g' >> "$PAGE_URLS"; then
    echo "<p class='log-entry error'><span class='timestamp'>[$(format_date)]</span> Failed to fetch or process sitemap: $sitemap_url</p>" >> "$TEMP_LOG_FILE"
  fi
done < "$SITEMAP_LIST"

# Check if page URLs were found
if [ ! -s "$PAGE_URLS" ]; then
  echo "<p class='log-entry error'><span class='timestamp'>[$(format_date)]</span> No page URLs found in the nested sitemaps.</p>" >> "$TEMP_LOG_FILE"
  rm "$SITEMAP_LIST"
  echo "</div></body></html>" >> "$TEMP_LOG_FILE"
  cat "$TEMP_LOG_FILE" >> "$LOG_FILE"
  rm "$TEMP_LOG_FILE"  # Ensure temp_log.html is removed
  exit 1
fi

# Step 3: Visit each page URL to warm the cache and log the HTTP status code
echo "<p class='log-entry'><span class='timestamp'>[$(format_date)]</span> Warming up cache by visiting each URL...</p>" >> "$TEMP_LOG_FILE"
while IFS= read -r url; do
  http_status=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  echo "<p class='log-entry'><span class='timestamp'>[$(format_date)]</span> Visiting $url - Status Code: <span class='status'>$http_status</span></p>" >> "$TEMP_LOG_FILE"
  sleep 1  # Rate limit: Sleep for 1 second between requests
done < "$PAGE_URLS"

# Clean up temporary files
rm "$SITEMAP_LIST" "$PAGE_URLS"

echo "<p class='log-entry success'><span class='timestamp'>[$(format_date)]</span> Cache warming completed.</p>" >> "$TEMP_LOG_FILE"
echo "</div></body></html>" >> "$TEMP_LOG_FILE"

# Check if the log file exists and its line count
if [ -f "$LOG_FILE" ]; then
  line_count=$(wc -l < "$LOG_FILE")
  if (( line_count > 2000 )); then
    echo "<p class='log-entry warning'><span class='timestamp'>[$(format_date)]</span> Log file exceeded 2000 lines. Truncating...</p>" >> "$TEMP_LOG_FILE"
    
    # Keep only the last 2000 lines of the log file
    tail -n 2000 "$LOG_FILE" > "$SCRIPT_DIR/truncated_log.html"
    mv "$SCRIPT_DIR/truncated_log.html" "$LOG_FILE"
  fi
fi

# Combine new logs with existing log file, keeping new logs on top
cat "$TEMP_LOG_FILE" "$LOG_FILE" > "$SCRIPT_DIR/combined_log.html"
mv "$SCRIPT_DIR/combined_log.html" "$LOG_FILE"

# Always remove temp_log.html at the end
rm "$TEMP_LOG_FILE"

# nginx-cache-warmer
I used ChatGPT to help with this. I couldn't find a great script to warm the cache of a WordPress website running Nginx FastCGI or Redis Full Page, and I don't have enough Bash skills to make this on my own. I wanted a script that would simply load every page on a website based on a Sitemap, such as created with Yoast SEO. 

Put this script in a directory on the website, such as `/warmcache/warm-cache.sh`. Make the script executable:

```bash
chmod +x warm-cache.sh
```

Run the script using:

```bash
./warm-cache.sh "https://example.com/sitemap.xml" "America/New_York"
```

You can set the script to run every hour using `crontab -e`, then adding:

```bash
0 * * * * /path/to/your/script/warm_cache.sh <sitemap_url> [<time_zone>] > /dev/null 2>&1
```

It will create a nice log file that can be viewed by visiting the directory. The file will be at `/warmcache/index.html`.

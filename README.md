# nginx-cache-warmer
I used ChatGPT to help with this. I couldn't find a great script to warm the cache of a WordPress website running Nginx FastCGI or Redis Full Page, and I don't have enough Bash skills to make this on my own. I wanted a script that would simply load every page on a website based on a Sitemap, such as created with Yoast SEO, to warm the cache. This seems to work perfectly on my website.

Copy and paste this script in a directory on the website, such as `/warmcache/warm-cache.sh`.

```bash
nano warm-cache.sh
```

Make the script executable:

```bash
chmod +x warm-cache.sh
```

For testing run the script directly using (time_zone is optional):

```bash
./warm-cache.sh "https://example.com/sitemap.xml" "America/New_York"
```

You can set the script to run every hour automatically using `crontab -e`, then adding (time_zone is optional):

```bash
0 * * * * /path/to/your/script/warm_cache.sh <sitemap_url> <time_zone> > /dev/null 2>&1
```

It will create a nice log file that can be viewed by visiting the directory. The file will be at `/warmcache/index.html`. This is great because you can check if the script is working, and it's also a great way to check that all webpages are loading. They will have a 200 code if they loaded correctly. The log file will be a maximum of 2000 lines. Of course all this can be modified in the code for you needs.

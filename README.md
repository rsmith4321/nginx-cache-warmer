# Simple Bash Script to Warm Nginx FastCGI or Redis Full Page Cache based on Sitemap
I couldn't find a great script to warm the cache of a WordPress website running Nginx FastCGI or Redis Full Page cache so I made one. This should also work to warm the Cloudflare cache, but I haven't tested that. I wanted a script that would load every page on a website based on a Sitemap, such as created with Yoast SEO, to warm the page cache. This will work with a sitemap index that contains other sitemaps, such as the one created by Yoast SEO. This works perfectly on my website. I have it set to load one page per second, but this can easily be modified. I don't recommend removing the pause. At least in my config, NGINX will start rate limiting, and pages will fail to load without the pause. I also recommend you password-protect the directory the script is in. Please let me know if you have any questions or recommendations for improving this.

Copy and paste this script to a directory on your website, such as `/warmcache/warm-cache.sh`. For security reasons, the sitemap URL is hard coded. You'll need to edit this line in the script to point to your sitemap before you run it on your website. For even more security, you can password-protect this directory so no one else can view the log files.

```bash
cd /path/to/your/wordpress/warmcache
nano warm-cache.sh
```
Copy and paste the code into the warm-cache.sh file. 

Make the script executable:

```bash
chmod +x warm-cache.sh
```

For testing, run the script directly using (time_zone is optional):

```bash
./warm-cache.sh "America/New_York"
```
Make sure the output lists all the pages in your sitemap.

You can set the script to run every hour automatically using cron (time_zone is optional):

```bash
crontab -e
0 * * * * /path/to/your/wordpress/warmcache/warm_cache.sh <time_zone> > /dev/null 2>&1
```

It will create a nice HTML log file that can be viewed by visiting the directory from which the script is run. For example if you put the script in the recommended /warmcache/ folder, the file will be at `/warmcache/index.html`. That means you can just visit https://mywebsite.com/warmcache/ to view the log. Remember to password-protect this directory if you don't want users to see the log, but it's just a list of your website pages and their status codes. This is great because you can check if the script is working, and it's also a great way to check that all your web pages are loading correctly. They will have a 200 status code if they are loaded correctly. The HTML log file will be rotated daily and old log files are stored in the /log directory. They are deleted after 7 days. Of course, all this can be modified in the code to fit your needs. The code is well commented.

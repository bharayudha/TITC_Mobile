import urllib.request
import re

try:
    js_url = 'https://titc.or.id/wp-content/plugins/fluent-community/assets/app.js?version=2.7.7'
    req = urllib.request.Request(js_url, headers={'User-Agent': 'Mozilla/5.0'})
    js_content = urllib.request.urlopen(req).read().decode('utf-8')
    endpoints = set(re.findall(r'[\"\']([^\'\"]*follow[^\'\"]*)[\"\']', js_content))
    print("Found follow endpoints in app.js:", endpoints)
except Exception as e:
    print('Error:', e)

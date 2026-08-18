import urllib.request
import re
import json

try:
    js_url = 'https://titc.or.id/wp-content/plugins/fluent-community/assets/portal_general.js?ver=2.7.7'
    js_content = urllib.request.urlopen(js_url).read().decode('utf-8')
    # Find endpoints matching follow
    endpoints = set(re.findall(r'[\'"]([^\'"]*follow[^\'"]*)[\'"]', js_content))
    print("Found follow endpoints:", endpoints)
except Exception as e:
    print('Error:', e)

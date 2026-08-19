import urllib.request
import re

try:
    html = urllib.request.urlopen('https://titc.or.id/portal/').read().decode('utf-8')
    js_files = set(re.findall(r'src="([^"]+\.js[^\"]*)"', html))

    print("Found JS files:", js_files)
    for js_url in js_files:
        if 'http' not in js_url:
            js_url = 'https://titc.or.id' + js_url
        print('Checking JS:', js_url)
        js_content = urllib.request.urlopen(js_url).read().decode('utf-8')
        routes = set(re.findall(r'path:\s*"(/[^\"]+)"', js_content))
        for route in routes:
            print('ROUTE:', route)
except Exception as e:
    print('Error:', e)

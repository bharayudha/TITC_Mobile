import re
data = open('fcom_app.js', encoding='utf-8').read()
matches = list(set(re.findall(r'[\'\"`][^\'\"`]*avatar[^\'\"`]*[\'\"`]', data)))
for m in matches[:50]:
    print(m)

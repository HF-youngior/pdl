from bs4 import BeautifulSoup
from pathlib import Path
html = Path('backend/public/api-docs.html').read_text(encoding='utf-8')
soup = BeautifulSoup(html, 'html.parser')
entries = []
for endpoint in soup.select('.endpoint-header'):
    method = endpoint.select_one('.method')
    path = endpoint.select_one('.path')
    if method and path:
        m = method.get_text(strip=True).upper()
        p = path.get_text(strip=True)
        if p.startswith('/api'):
            entries.append((m, p))
print(len(entries))
for m,p in entries:
    print(m, p)

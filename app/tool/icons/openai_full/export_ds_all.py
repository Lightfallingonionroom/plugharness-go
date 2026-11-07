#!/usr/bin/env python3
"""Export ALL official ChatGPT ds_* icons (24dp regular) from the APK.

Source: assets/composeResources/com.openai.kmp.platform.design.resources/drawable/
These are plaintext Android vector XML with android:pathData, unlike the 48
res/drawable ones which are binary AXML. This is the complete official icon set.
"""
import zipfile, re, os, json, html

APK = '/tmp/cgpt/new.apk'
OUT = '/tmp/cgpt/ds_all'
os.makedirs(OUT, exist_ok=True)

z = zipfile.ZipFile(APK)
paths = [n for n in z.namelist()
         if n.startswith('assets/composeResources')
         and re.search(r'/ds_.*_regular_24\.xml$', n)]

manifest = []
for p in paths:
    name = p.rsplit('/', 1)[-1][:-4]
    short = name[len('ds_'):-len('_regular_24')]
    raw = z.read(p).decode('utf-8', 'replace')
    # extract pathData + fillType
    paths_data = re.findall(r'android:pathData="([^"]+)"', raw)
    fills = re.findall(r'android:fillType="([^"]+)"', raw)
    if not paths_data:
        continue
    # Build a 24x24 SVG. evenOdd where the source says so.
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">']
    for i, d in enumerate(paths_data):
        rule = fills[i] if i < len(fills) else 'nonZero'
        fr = ' fill-rule="evenodd"' if rule == 'evenOdd' else ''
        clip = ''
        svg.append(f'  <path d="{html.escape(d, quote=True)}" fill="#000000"{fr}{clip}/>')
    svg.append('</svg>')
    with open(f'{OUT}/{short}.svg', 'w') as f:
        f.write('\n'.join(svg))
    manifest.append({'resource': name, 'short': short, 'paths': len(paths_data), 'svg': f'{short}.svg'})

manifest.sort(key=lambda x: x['short'])
with open('/tmp/cgpt/ds_all_manifest.json', 'w') as f:
    json.dump(manifest, f, indent=1)
print('exported:', len(manifest), 'icons to', OUT)
print('first 10:', [m['short'] for m in manifest[:10]])
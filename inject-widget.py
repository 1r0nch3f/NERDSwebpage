#!/usr/bin/env python3
"""
Inject the NERDS Messenger widget <script> tag into all HTML files.
Run from the root of your NERDSwebpage repo clone.

- Skips index.html (Nexus Grill tool)
- Uses a comment marker to prevent double-injection on reruns
- Inserts before </body>
"""

import os
import glob

MARKER = '<!-- NERDS-MESSENGER-WIDGET -->'
SNIPPET = f'{MARKER}\n<script src="messenger-widget.js" defer></script>'

SKIP = {'index.html'}

def inject(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    if MARKER in content:
        print(f'  SKIP (already injected): {filepath}')
        return False

    if '</body>' not in content.lower():
        print(f'  SKIP (no </body>):       {filepath}')
        return False

    # Case-insensitive replace, preserve original tag casing
    import re
    content = re.sub(
        r'(</body>)',
        SNIPPET + '\n\\1',
        content,
        count=1,
        flags=re.IGNORECASE
    )

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f'  DONE: {filepath}')
    return True

def main():
    html_files = sorted(glob.glob('*.html'))

    if not html_files:
        print('No HTML files found. Run this from the repo root.')
        return

    print(f'Found {len(html_files)} HTML files.\n')
    injected = 0

    for f in html_files:
        if f in SKIP:
            print(f'  SKIP (excluded):         {f}')
            continue
        if inject(f):
            injected += 1

    print(f'\nInjected into {injected} file(s).')
    print('Commit, push, and the widget is live on GitHub Pages.')

if __name__ == '__main__':
    main()

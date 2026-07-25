#!/usr/bin/env python3
"""
Swap the old NERDS Messenger widget for Tawk.to live chat.
Run from the root of your NERDSwebpage repo clone.

- Removes the old <!-- NERDS-MESSENGER-WIDGET --> + script tag
- Injects the Tawk.to embed script before </body>
- Skips index.html (Nexus Grill tool)
- Uses a marker to prevent double-injection on reruns
"""

import os
import re
import glob

OLD_MARKER = '<!-- NERDS-MESSENGER-WIDGET -->'
NEW_MARKER = '<!-- NERDS-TAWK-CHAT -->'

TAWK_SNIPPET = f"""{NEW_MARKER}
<!--Start of Tawk.to Script-->
<script type="text/javascript">
var Tawk_API=Tawk_API||{{}}, Tawk_LoadStart=new Date();
(function(){{
var s1=document.createElement("script"),s0=document.getElementsByTagName("script")[0];
s1.async=true;
s1.src='https://embed.tawk.to/6a64b64a1320a91d46342627/1jucmg4ch';
s1.charset='UTF-8';
s1.setAttribute('crossorigin','*');
s0.parentNode.insertBefore(s1,s0);
}})();
</script>
<!--End of Tawk.to Script-->"""

SKIP = {'index.html'}


def process(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changed = False

    # Remove old Messenger widget lines if present
    if OLD_MARKER in content:
        content = content.replace(OLD_MARKER + '\n<script src="messenger-widget.js" defer></script>\n', '')
        content = content.replace(OLD_MARKER + '\n<script src="messenger-widget.js" defer></script>', '')
        changed = True

    # Skip if Tawk already injected
    if NEW_MARKER in content:
        if changed:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f'  CLEANED old widget:  {filepath}')
        else:
            print(f'  SKIP (Tawk exists):  {filepath}')
        return changed

    if '</body>' not in content.lower():
        print(f'  SKIP (no </body>):   {filepath}')
        return False

    # Inject Tawk.to before </body>
    content = re.sub(
        r'(</body>)',
        TAWK_SNIPPET + '\n\\1',
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
    updated = 0

    for f in html_files:
        if f in SKIP:
            print(f'  SKIP (excluded):     {f}')
            continue
        if process(f):
            updated += 1

    print(f'\nUpdated {updated} file(s).')
    print('Commit, push, and Tawk.to goes live on GitHub Pages.')


if __name__ == '__main__':
    main()

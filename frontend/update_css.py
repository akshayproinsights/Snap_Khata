import re

with open('/root/Snap_Khata/frontend/public/receipt.html', 'r') as f:
    content = f.read()

# Find the @media print block
m = re.search(r'@media print\s*\{([\s\S]*?)\n        \}\s*\n        /\* ── Auto Print Overlay ── \*/', content)
if not m:
    print("Could not find @media print block")
    exit(1)

print_css = m.group(1)

# Create the .pdf-export block
export_css = "\n        /* --- PDF Export Styles --- */\n"
for line in print_css.split('\n'):
    line = line.strip()
    if not line:
        continue
    # skip body background/margin/padding changes for export, we want the container to be standard
    if line.startswith('body {'):
        export_css += "        .pdf-export { background: #fff !important; }\n"
        continue
    if line.startswith('background: #fff;') or line.startswith('margin: 0 !important;') or line.startswith('padding: 10mm 12mm !important;'):
        continue
    
    # Prefix selectors with .pdf-export
    # Example: .scaled-container { -> .pdf-export .scaled-container {
    
    # Let's do a simple regex substitution for selectors
    # We'll just split by '{' and prepend .pdf-export to the selectors
    parts = line.split('{')
    if len(parts) == 2:
        selectors = parts[0].split(',')
        new_selectors = []
        for sel in selectors:
            sel = sel.strip()
            if sel == '*' or sel == 'body':
                new_selectors.append('.pdf-export ' + sel)
            elif sel.startswith('.'):
                new_selectors.append('.pdf-export ' + sel)
            else:
                new_selectors.append('.pdf-export ' + sel)
        
        # for specific cases like scaled-container width
        if 'scaled-container' in line:
            export_css += "        " + ", ".join(new_selectors) + " { " + parts[1] + "\n"
        else:
            export_css += "        " + ", ".join(new_selectors) + " { " + parts[1] + "\n"
    else:
        export_css += "        " + line + "\n"

# We actually need to fix scaled-container width for pdf-export
# Because if we set width: 100%, it will take mobile width!
# We want width: 850px!
export_css = export_css.replace('width: 100% !important;', '')
export_css = export_css.replace('max-width: 100% !important;', '')

with open('export_css.txt', 'w') as f:
    f.write(export_css)
print("Done extracting")

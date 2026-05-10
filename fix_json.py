import glob

files = glob.glob('backend/user_configs/templates/*.json')
for f in files:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # 1. Modify the gemini instruction to remove the prompt for Received Amount and Balance Due
    # Look for the exact lines in the system instruction
    
    new_lines = []
    for line in content.split('\n'):
        if '- Received Amount:' in line or '- Balance Due:' in line:
            continue
        new_lines.append(line)
        
    content = '\n'.join(new_lines)

    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)
        
print("Done updating JSON templates")

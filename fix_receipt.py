import re

with open('frontend/public/receipt.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Colors in root
content = content.replace('--bg: #f8fafc;', '--bg: #eceff1;')
content = content.replace('--border: #e2e8f0;', '--border: #cccccc;')
content = content.replace('--border-strong: #94a3b8;', '--border-strong: #000000;')
content = content.replace('--text-primary: #0f172a;', '--text-primary: #000000;')
content = content.replace('--text-secondary: #475569;', '--text-secondary: #333333;')
content = content.replace('--text-muted: #94a3b8;', '--text-muted: #555555;')
content = content.replace('--accent: #4f46e5;', '--accent: #000000;')
content = content.replace('--accent-dark: #3730a3;', '--accent-dark: #000000;')
content = content.replace('--accent-light: #eef2ff;', '--accent-light: #f5f5f5;')
content = content.replace('--green: #10b981;', '--green: #000000;')
content = content.replace('--green-bg: #ecfdf5;', '--green-bg: #ffffff;')
content = content.replace('--green-border: #a7f3d0;', '--green-border: #cccccc;')
content = content.replace('--amber: #f59e0b;', '--amber: #000000;')
content = content.replace('--amber-bg: #fffbeb;', '--amber-bg: #ffffff;')
content = content.replace('--amber-border: #fef3c7;', '--amber-border: #cccccc;')
content = content.replace('--red: #ef4444;', '--red: #000000;')
content = content.replace('--invoice-border: #0f172a;', '--invoice-border: #000000;')

# 2. inv-doc class
content = content.replace('''        .inv-doc {
            background: var(--white);
            border: 1px solid #e5e7eb;
            border-radius: 12px;
            box-shadow: 
                0 4px 6px -1px rgba(0,0,0,0.05),
                0 10px 15px -3px rgba(0,0,0,0.1),
                0 0 0 1px rgba(0,0,0,0.02);
            overflow: hidden;
            position: relative;
            min-height: 1000px;
            display: flex;
            flex-direction: column;
            color: var(--text-primary);
        }''', '''        .inv-doc {
            background: var(--white);
            border: 1px solid #000000;
            border-radius: 2px;
            overflow: hidden;
            position: relative;
            min-height: 1000px;
            display: flex;
            flex-direction: column;
            color: var(--text-primary);
        }''')

# 3. inv-shop-header class
content = content.replace('''        .inv-shop-header {
            padding: 48px 48px 32px;
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            background: #ffffff;
        }''', '''        .inv-shop-header {
            padding: 48px 48px 32px;
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            background: var(--white);
            border-bottom: 1px solid var(--border-strong);
        }''')

# 4. Status pill
content = content.replace('''        .inv-paid {
            background: #dcfce7;
            color: #166534;
        }

        .inv-pending {
            background: #fef3c7;
            color: #b45309;
        }''', '''        .inv-paid {
            background: #ffffff;
            color: #000000;
            border: 1px solid #000000;
        }

        .inv-pending {
            background: #ffffff;
            color: #000000;
            border: 1px dashed #000000;
        }''')

# 5. Table border bottom
content = content.replace('border-bottom: 1px solid #f1f5f9;', 'border-bottom: 1px solid var(--border);')

# 6. Amount words
content = content.replace('''        .inv-amount-words {
            max-width: 320px;
            font-size: 12px;
            color: var(--text-secondary);
            background: #f8fafc;
            padding: 16px;
            border-radius: 8px;
            margin-top: 8px;
        }''', '''        .inv-amount-words {
            max-width: 320px;
            font-size: 12px;
            color: var(--text-primary);
            background: var(--white);
            padding: 12px;
            border: 1px solid var(--border);
            border-radius: 4px;
            margin-top: 8px;
        }''')

# 7. Totals rows
content = content.replace('''        .inv-totals-row.received {
            color: var(--accent);
            font-weight: 500;
        }
        .inv-totals-row.received .amount { color: var(--accent); font-weight: 600; }

        .inv-totals-row.balance {
            color: #10b981;
            font-weight: 600;
            padding: 12px 16px;
            background: #ecfdf5;
            border-radius: 8px;
            margin-top: 8px;
        }
        .inv-totals-row.balance .amount { color: #10b981; font-weight: 700; }''', '''        .inv-totals-row.received {
            color: var(--text-primary);
            font-weight: 500;
        }
        .inv-totals-row.received .amount { color: var(--text-primary); font-weight: 600; }

        .inv-totals-row.balance {
            color: var(--text-primary);
            font-weight: 700;
            padding: 12px 16px;
            background: var(--white);
            border-top: 1px dashed var(--border-strong);
            border-bottom: 1px dashed var(--border-strong);
            border-radius: 0;
            margin-top: 8px;
        }
        .inv-totals-row.balance .amount { color: var(--text-primary); font-weight: 800; }''')

# 8. Footer background
content = content.replace('''        .inv-footer {
            padding: 32px 48px;
            background: #f8fafc;
            display: flex;
            justify-content: space-between;
            align-items: flex-end;
            border-top: 1px solid var(--border-strong);
        }''', '''        .inv-footer {
            padding: 32px 48px;
            background: var(--white);
            display: flex;
            justify-content: space-between;
            align-items: flex-end;
            border-top: 1px solid var(--border-strong);
        }''')


# Fix font slightly since standard offline invoices are often classic fonts
content = content.replace('''font-family: 'Inter', system-ui, sans-serif;''', '''font-family: 'Inter', Arial, sans-serif;''')

# Inline styles
content = content.replace('background:#f8fafc;', 'background:#f9f9f9;border-top:1px solid #000;border-bottom:1px solid #000;')

with open('frontend/public/receipt.html', 'w', encoding='utf-8') as f:
    f.write(content)

with open('frontend/dist/receipt.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated successfully.")

import sys

with open('/tmp/invoice_pdf_generator_7982787c.dart', 'r') as f:
    content = f.read()

# Add a dummy preWarm method
insert_pos = content.find('static Future<Uint8List> generate')
if insert_pos != -1:
    content = content[:insert_pos] + "  static Future<void> preWarm([String? logoUrl]) async { await _ensureFonts(); if (logoUrl != null) _fetchLogoBytes(logoUrl); }\n\n" + content[insert_pos:]

with open('/root/Snap_Khata/mobile/lib/core/utils/invoice_pdf_generator.dart', 'w') as f:
    f.write(content)

print("Patched and overwritten")

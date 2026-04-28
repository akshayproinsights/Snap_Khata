import re

with open("backend/services/verification.py", "r") as f:
    content = f.read()

# Add _is_valid_scalar definition after _find_col
is_valid_func = """
def _is_valid_scalar(val):
    if val is None:
        return False
    if isinstance(val, (list, dict, tuple)):
        return True
    try:
        return bool(pd.notna(val))
    except ValueError:
        return True
"""

# Find where to insert it (after _find_col definition finishes)
insert_pos = content.find("def build_verified(")
if insert_pos != -1:
    content = content[:insert_pos] + is_valid_func + "\n" + content[insert_pos:]

# Replace pd.notna with _is_valid_scalar between lines 676 and 760
# Actually, we can just replace 'pd.notna(' with '_is_valid_scalar(' inside the apply date and receipt corrections blocks.
# Let's do a regex substitution only for lines after "Applying date and receipt corrections..."
start_marker = 'await emit_progress("correcting", 25, "Applying date and receipt corrections...")'
end_marker = '# 3B. Mark ALL receipts as "Verified" if they are fully Done'

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx != -1 and end_idx != -1:
    sub_content = content[start_idx:end_idx]
    sub_content = sub_content.replace('pd.notna(', '_is_valid_scalar(')
    content = content[:start_idx] + sub_content + content[end_idx:]

with open("backend/services/verification.py", "w") as f:
    f.write(content)

print("Done fixing pd.notna")

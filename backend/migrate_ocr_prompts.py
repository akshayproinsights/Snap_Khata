import json
import re
from pathlib import Path

BASE_DIR = Path(__file__).parent
USER_CONFIGS_DIR = BASE_DIR / "user_configs"

def migrate_text(text, is_vendor=False):
    original = text
    
    if is_vendor:
        # B2B Vendor Invoices

        # 1. Update line items description translation rule (common in step 3 or general)
        text = text.replace(
            "If description is in Marathi/Hindi, translate/transliterate to English and output in the format: 'English Name (Original Text)'.",
            "If description is in Marathi/Hindi, keep it exactly as written (do not translate or transliterate; if English keep English, if Marathi keep Marathi). Ensure EVERY single row/item is extracted individually without skipping, summarizing, or merging."
        )
        text = text.replace(
            "description: Item name / particulars. **Translation Policy**: If in Marathi/Hindi, output as 'English Name (Original Text)'.",
            "description: Item name / particulars. Keep it exactly as written (do not translate or transliterate; if English keep English, if Marathi keep Marathi). Ensure EVERY single row/item from the invoice line-item table is extracted individually. DO NOT skip, merge, group, or summarize any items."
        )
        
        # 2. Update language policy at the top
        text = text.replace(
            "Language Policy: The invoice may contain text in Marathi, Hindi, or English. For 'vendor_name' and line item 'description', if the text is in Marathi or Hindi, translate it to English and output in the format: 'English Name (Original Text)'. If it is already in English, keep it as is.",
            "Language Policy: The invoice may contain text in Marathi, Hindi, or English. For 'vendor_name', if the text is in Marathi or Hindi, translate/transliterate it to English and output in the format: 'English Name (Original Text)'. For line item 'description', keep it exactly as written (do not translate or transliterate; if English keep English, if Marathi keep Marathi)."
        )
        
        # 3. Update LANGUAGE & NUMERALS section
        text = text.replace(
            "LANGUAGE & NUMERALS: The invoice may contain text/numbers in Marathi, Hindi, or English. Convert any Marathi numerical digits to standard English digits. If any vendor name or item description is in Marathi or Hindi, translate/transliterate to English and output in the format: 'English Name (Original Text)'. If it is already in English, keep it as is.",
            "LANGUAGE & NUMERALS: The invoice may contain text/numbers in Marathi, Hindi, or English. Convert any Marathi numerical digits to standard English digits. If any vendor name is in Marathi or Hindi, translate/transliterate it to English and output in the format: 'English Name (Original Text)'. If item description is in Marathi/Hindi, keep it exactly as written (do not translate or transliterate; if English keep English, if Marathi keep Marathi)."
        )
    else:
        # B2C Sales Bills / Receipts

        # 1. Language Policy / RULES
        text = text.replace(
            "Language Policy: The bill may be in Marathi, Hindi, or English. If description or customer name is in Marathi/Hindi, translate/transliterate it to English and output in the format 'English Name (Original Text)' (e.g. 'Gulab Waghmare (गुलाब वाघमारे)'). Convert any Marathi numerical digits to standard English digits.",
            "Language Policy: The bill may be in Marathi, Hindi, or English. If customer name is in Marathi/Hindi, translate/transliterate it to English and output in the format 'English Name (Original Text)' (e.g. 'Gulab Waghmare (गुलाब वाघमारे)'). Convert any Marathi numerical digits to standard English digits. Keep item descriptions exactly as written (do not translate or transliterate; if English keep English, if Marathi keep Marathi)."
        )
        
        # 2. Items / LINE ITEMS section
        text = text.replace(
            "If description is in Marathi/Hindi, translate/transliterate it to English and output in the format: 'English Name (Original Text)'.",
            "If description is in Marathi/Hindi, keep it exactly as written (do not translate or transliterate; if English keep English, if Marathi keep Marathi)."
        )
        
        text = text.replace(
            "Language Policy: If description is in Marathi/Hindi, translate and output as 'English Name (Original Text)'.",
            "If description is in Marathi/Hindi, keep it exactly as written (do not translate or transliterate; if English keep English, if Marathi keep Marathi)."
        )

        text = text.replace(
            "- Language Policy: If description is in Marathi/Hindi, translate and output as 'English Name (Original Text)'.",
            "- If description is in Marathi/Hindi, keep it exactly as written (do not translate or transliterate; if English keep English, if Marathi keep Marathi)."
        )
        
    return text

def run_migration(dry_run=True):
    all_files = list(USER_CONFIGS_DIR.glob("*.json")) + list((USER_CONFIGS_DIR / "templates").glob("*.json"))
    
    modified_count = 0
    print(f"Starting migration. Dry Run: {dry_run}")
    print("=" * 60)
    
    for fpath in sorted(all_files):
        with open(fpath, "r", encoding="utf-8") as f:
            data = json.load(f)
            
        changed = False
        
        # Modify gemini system instruction
        if "gemini" in data and "system_instruction" in data["gemini"]:
            orig = data["gemini"]["system_instruction"]
            new_text = migrate_text(orig, is_vendor=False)
            if orig != new_text:
                data["gemini"]["system_instruction"] = new_text
                changed = True
                print(f"[{fpath.name}] gemini section modified.")
                
        # Modify vendor_gemini system instruction
        if "vendor_gemini" in data and "system_instruction" in data["vendor_gemini"]:
            orig = data["vendor_gemini"]["system_instruction"]
            new_text = migrate_text(orig, is_vendor=True)
            if orig != new_text:
                data["vendor_gemini"]["system_instruction"] = new_text
                changed = True
                print(f"[{fpath.name}] vendor_gemini section modified.")
                
        if changed:
            modified_count += 1
            if not dry_run:
                with open(fpath, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=4, ensure_ascii=False)
                print(f"  -> Saved changes to {fpath.name}")
            else:
                print(f"  -> [DRY RUN] Would save changes to {fpath.name}")
                
    print("=" * 60)
    print(f"Processed {len(all_files)} files. Modified: {modified_count}")

if __name__ == "__main__":
    import sys
    dry = True
    if len(sys.argv) > 1 and sys.argv[1].lower() == "apply":
        dry = False
    run_migration(dry)

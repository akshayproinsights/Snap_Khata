import json
import codecs
import glob
import os

def process_file(file_path):
    with codecs.open(file_path, 'r', 'utf-8') as f:
        try:
            data = json.load(f)
        except:
            return
            
    modified = False
    
    if 'gemini' in data and 'system_instruction' in data['gemini']:
        prompt1 = data['gemini']['system_instruction']
        if 'Language Policy' not in prompt1:
            prompt1 = prompt1.replace(
                '3. **Handwriting:** Prioritize accuracy. If a line is illegible, lower the confidence score.\n\n',
                '3. **Handwriting:** Prioritize accuracy. If a line is illegible, lower the confidence score.\n4. **Language Policy:** The receipt/bill may be written in Marathi, Hindi, or English. ALWAYS extract and return the text EXACTLY as written in its original language (DO NOT translate). If words are in Marathi or Hindi, return them in Marathi or Hindi.\n\n'
            )
            prompt1 = prompt1.replace(
                '* **Customer Name:** English only.',
                '* **Customer Name:** Extract EXACTLY as written (may be in Marathi, Hindi, or English).'
            )
            data['gemini']['system_instruction'] = prompt1
            modified = True

    if 'vendor_gemini' in data and 'system_instruction' in data['vendor_gemini']:
        prompt2 = data['vendor_gemini']['system_instruction']
        if 'Language Policy' not in prompt2:
            policy_str = "- Part Numbers: Extract character-by-character. A single digit error ('O' vs '0') is a critical failure.\n"
            if policy_str in prompt2:
                new_policy_str = policy_str + "- Language Policy: The invoice may contain text in Marathi, Hindi, or English. Extract text EXACTLY as written in its original language. DO NOT translate.\n"
                data['vendor_gemini']['system_instruction'] = prompt2.replace(policy_str, new_policy_str)
                modified = True

    if 'vendor_mapping_gemini' in data and 'system_instruction' in data['vendor_mapping_gemini']:
        prompt3 = data['vendor_mapping_gemini']['system_instruction']
        if 'Language Policy' not in prompt3:
            hw_str = "- If completely illegible, return null rather than guessing\n"
            if hw_str in prompt3:
                new_hw_str = hw_str + "- Language Policy: Text may be in Marathi, Hindi, or English. Extract text EXACTLY as written without translating.\n"
                data['vendor_mapping_gemini']['system_instruction'] = prompt3.replace(hw_str, new_hw_str)
                modified = True
                
    if modified:
        with codecs.open(file_path, 'w', 'utf-8') as f:
            json.dump(data, f, indent=4, ensure_ascii=False)
            f.write('\n')
        print(f"Updated {file_path}")

for root, _, files in os.walk('backend/user_configs'):
    for file in files:
        if file.endswith('.json'):
            process_file(os.path.join(root, file))

print("Done all!")

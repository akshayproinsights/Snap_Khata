import json
import codecs

def update_adnak():
    file_path = 'backend/user_configs/adnak.json'
    with codecs.open(file_path, 'r', 'utf-8') as f:
        data = json.load(f)
        
    # 1. Update gemini
    prompt1 = data['gemini']['system_instruction']
    prompt1 = prompt1.replace(
        '3. **Handwriting:** Prioritize accuracy. If a line is illegible, lower the confidence score.\\n\\n',
        '3. **Handwriting:** Prioritize accuracy. If a line is illegible, lower the confidence score.\\n4. **Language Policy:** The receipt/bill may be written in Marathi, Hindi, or English. ALWAYS extract and return the text EXACTLY as written in its original language (DO NOT translate). If words are in Marathi or Hindi, return them in Marathi or Hindi.\\n\\n'
    )
    prompt1 = prompt1.replace(
        '* **Customer Name:** English only.',
        '* **Customer Name:** Extract EXACTLY as written (may be in Marathi, Hindi, or English).'
    )
    
    # In case the '\n' are literal newlines instead of string representations:
    prompt1 = prompt1.replace(
        '3. **Handwriting:** Prioritize accuracy. If a line is illegible, lower the confidence score.\n\n',
        '3. **Handwriting:** Prioritize accuracy. If a line is illegible, lower the confidence score.\n4. **Language Policy:** The receipt/bill may be written in Marathi, Hindi, or English. ALWAYS extract and return the text EXACTLY as written in its original language (DO NOT translate). If words are in Marathi or Hindi, return them in Marathi or Hindi.\n\n'
    )
    data['gemini']['system_instruction'] = prompt1

    # 2. Update vendor_gemini
    prompt2 = data['vendor_gemini']['system_instruction']
    policy_str = "- Part Numbers: Extract character-by-character. A single digit error ('O' vs '0') is a critical failure.\n"
    new_policy_str = policy_str + "- Language Policy: The invoice may contain text in Marathi, Hindi, or English. Extract text EXACTLY as written in its original language. DO NOT translate.\n"
    prompt2 = prompt2.replace(policy_str, new_policy_str)
    data['vendor_gemini']['system_instruction'] = prompt2

    # 3. Update vendor_mapping_gemini
    prompt3 = data['vendor_mapping_gemini']['system_instruction']
    hw_str = "- If completely illegible, return null rather than guessing\n"
    new_hw_str = hw_str + "- Language Policy: Text may be in Marathi, Hindi, or English. Extract text EXACTLY as written without translating.\n"
    prompt3 = prompt3.replace(hw_str, new_hw_str)
    data['vendor_mapping_gemini']['system_instruction'] = prompt3

    with codecs.open(file_path, 'w', 'utf-8') as f:
        json.dump(data, f, indent=4, ensure_ascii=False)
        f.write('\n')
        
update_adnak()
print("Done!")

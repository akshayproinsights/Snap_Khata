import asyncio
import os
import sys
from fastapi import UploadFile

# Add backend directory to sys.path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(backend_dir)

from routes.shop_profile import autofill_shop_profile

async def main():
    # Path to the generated sample receipt
    image_path = "/root/.gemini/antigravity-ide/brain/03289de2-a5fb-4784-b02f-f932d525d00f/sample_receipt_1780811598429.png"
    
    if not os.path.exists(image_path):
        print(f"Error: Sample receipt image not found at {image_path}")
        return
        
    print(f"Reading sample receipt: {image_path}")
    with open(image_path, "rb") as f:
        image_bytes = f.read()
        
    # Mock FastAPI UploadFile
    import io
    file_like = io.BytesIO(image_bytes)
    upload_file = UploadFile(
        filename="sample_receipt.png",
        file=file_like,
        headers={"content-type": "image/png"}
    )
    
    # Mock authenticated user
    mock_user = {"username": "AkshayK"}
    
    print("Sending receipt image to autofill_shop_profile endpoint...")
    try:
        result = await autofill_shop_profile(file=upload_file, current_user=mock_user)
        print("\n--- EXTRACTION RESULT ---")
        import json
        print(json.dumps(result, indent=4))
        print("-------------------------")
        
        # Verify keys
        expected_keys = {"shop_name", "shop_address", "shop_phone", "shop_gst", "shop_upi_id", "shop_type"}
        missing_keys = expected_keys - set(result.keys())
        if missing_keys:
            print(f"FAIL: Missing keys in response: {missing_keys}")
        else:
            print("SUCCESS: All expected keys are present!")
            
    except Exception as e:
        print(f"Error during API call: {e}")

if __name__ == "__main__":
    asyncio.run(main())

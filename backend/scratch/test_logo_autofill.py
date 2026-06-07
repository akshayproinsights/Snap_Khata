import asyncio
import os
import sys
import io
import json
from PIL import Image, ImageDraw, ImageFont
from fastapi import UploadFile

# Add backend directory to sys.path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(backend_dir)

from routes.shop_profile import autofill_shop_profile

# Ensure we run from backend directory to pick up the .env config properly
os.chdir(backend_dir)

async def test_autofill_logo():
    print("Creating a mock receipt image with a logo...")
    # Create a white image representing a receipt
    W, H = 800, 1000
    img = Image.new("RGB", (W, H), color="white")
    draw = ImageDraw.Draw(img)
    
    # Draw a blue circle to represent the shop logo at the top
    # Bounding box coordinates: left=350, top=50, right=450, bottom=150
    # In 0-1000 scale: xmin=437.5, ymin=50.0, xmax=562.5, ymax=150.0
    draw.ellipse([350, 50, 450, 150], fill="blue", outline="darkblue", width=3)
    
    # Write "LOGO" in white inside the blue circle
    draw.text((380, 90), "LOGO", fill="white")
    
    # Write some shop information on the receipt
    draw.text((300, 200), "ADNAK HARDWARE SHOP", fill="black")
    draw.text((100, 250), "Address: 45 Market Yard, Pune, Maharashtra 411037", fill="black")
    draw.text((100, 290), "Phone: +91 99999 88888", fill="black")
    draw.text((100, 330), "GSTIN: 27ABCDE1234F1Z5", fill="black")
    draw.text((100, 370), "UPI ID: adnak@okaxis", fill="black")
    
    # Convert image to bytes
    buffer = io.BytesIO()
    img.save(buffer, format="JPEG")
    image_bytes = buffer.getvalue()
    
    # Mock UploadFile
    file_like = io.BytesIO(image_bytes)
    upload_file = UploadFile(
        filename="test_receipt.jpg",
        file=file_like,
        headers={"content-type": "image/jpeg"}
    )
    
    # Mock authenticated user and R2 bucket
    mock_user = {"username": "adnak-test"}
    mock_bucket = "digientry-local-dev"
    
    print("Invoking autofill_shop_profile endpoint...")
    try:
        result = await autofill_shop_profile(
            file=upload_file,
            current_user=mock_user,
            r2_bucket=mock_bucket
        )
        print("\n=== EXTRACTION RESULT ===")
        print(json.dumps(result, indent=4))
        print("=========================")
        
        # Verify the returned fields
        assert result["shop_name"] != "", "shop_name should not be empty"
        assert "99999" in result["shop_phone"], f"shop_phone unexpected: {result['shop_phone']}"
        assert "27ABCDE" in result["shop_gst"], f"shop_gst unexpected: {result['shop_gst']}"
        assert result["shop_logo_url"] != "", "shop_logo_url should be populated"
        
        print("\nSUCCESS: Extraction of details and logo cropping verified successfully!")
        print(f"Cropped Shop Logo URL: {result['shop_logo_url']}")
        
    except AssertionError as ae:
        print(f"\nASSERTION FAILED: {ae}")
        sys.exit(1)
    except Exception as e:
        print(f"\nERROR running test: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(test_autofill_logo())

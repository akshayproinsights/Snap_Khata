import io
from PIL import Image
from utils.image_optimizer import optimize_image_for_gemini, OPTIMAL_MAX_DIMENSION, TARGET_FILE_SIZE_KB

def test_fast_path():
    print("Running Fast Path Test...")
    # Create a small JPEG image
    img = Image.new('RGB', (1000, 1000), color=(73, 109, 137))
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='JPEG')
    img_data = img_byte_arr.getvalue()
    
    # Test optimization
    optimized_data, metadata = optimize_image_for_gemini(img_data)
    
    print(f"Original Format: {metadata['original_format']}")
    print(f"Optimized Format: {metadata['optimized_format']}")
    print(f"Quality: {metadata['quality']}")
    
    if metadata['quality'] == 'original':
        print("✅ Fast Path triggered for JPEG as expected")
    else:
        print("❌ Fast Path NOT triggered for JPEG")

def test_webp_fast_path():
    print("\nRunning WebP Fast Path Test...")
    # Create a small WebP image
    img = Image.new('RGB', (1000, 1000), color=(73, 109, 137))
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='WEBP')
    img_data = img_byte_arr.getvalue()
    
    # Test optimization
    optimized_data, metadata = optimize_image_for_gemini(img_data)
    
    print(f"Original Format: {metadata['original_format']}")
    print(f"Optimized Format: {metadata['optimized_format']}")
    print(f"Quality: {metadata['quality']}")
    
    if metadata['quality'] == 'original' and metadata['original_format'] == 'WEBP':
        print("✅ Fast Path triggered for WEBP as expected")
    else:
        print("❌ Fast Path NOT triggered for WEBP")

def test_resize_optimization():
    print("\nRunning Resize Optimization Test...")
    # Create a large image
    img = Image.new('RGB', (2000, 2000), color=(73, 109, 137))
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='JPEG')
    img_data = img_byte_arr.getvalue()
    
    # Test optimization
    optimized_data, metadata = optimize_image_for_gemini(img_data)
    
    print(f"Original Dimensions: {metadata['original_dimensions']}")
    print(f"Final Dimensions: {metadata['final_dimensions']}")
    print(f"Optimized Size: {metadata['optimized_size_kb']} KB")
    
    if metadata['final_dimensions'][0] <= OPTIMAL_MAX_DIMENSION:
        print(f"✅ Image resized to {metadata['final_dimensions']} as expected (Limit: {OPTIMAL_MAX_DIMENSION})")
    else:
        print("❌ Image NOT resized correctly")

if __name__ == "__main__":
    test_fast_path()
    test_webp_fast_path()
    test_resize_optimization()

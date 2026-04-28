import pandas as pd
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def test_safe_drop():
    # Simulating the DataFrame in verification.py
    df = pd.DataFrame({
        'receipt_number': ['123', '456'],
        'line_item_row_bbox': ['bbox1', 'bbox2'],
        'row_id': ['1', '2']
    })
    
    columns_to_exclude = [
        'line_item_row_bbox',
        'missing_col'
    ]
    
    logger.info("Testing safe drop...")
    for col in columns_to_exclude:
        # This simulates the logic I added
        if col in df.columns:
            logger.info(f"Dropping {col}...")
            df = df.drop(columns=[col], errors='ignore')
        else:
            logger.info(f"{col} not found, skipping (safe)...")
            # Even if we didn't check, errors='ignore' should handle it
            df = df.drop(columns=[col], errors='ignore')

    logger.info(f"Final columns: {list(df.columns)}")
    assert 'line_item_row_bbox' not in df.columns
    assert 'receipt_number' in df.columns
    logger.info("✓ Safe drop test passed!")

if __name__ == "__main__":
    test_safe_drop()

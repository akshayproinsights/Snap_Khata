import pandas as pd
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def repro():
    df = pd.DataFrame({'A': [1], 'B': [2], 'line_item_row_bbox': [3]})
    columns_to_exclude = ['line_item_row_bbox', 'non_existent']
    
    for col in columns_to_exclude:
        if col in df.columns:
            logger.info(f"Dropping {col}")
            df = df.drop(columns=[col])
            
    print("Success")

if __name__ == "__main__":
    repro()

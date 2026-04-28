import pandas as pd
import numpy as np

df = pd.DataFrame({'A': [1, 2, 3], 'B': [None, None, None]})
mask = df['A'] > 1 # 2 rows

val = ['x', 'y'] # length 2, matches mask sum
df.loc[mask, 'B'] = val
print("Matches length:")
print(df)

df = pd.DataFrame({'A': [1, 2, 3], 'B': [None, None, None]})
val = ['x'] # length 1, mask sum is 2
try:
    df.loc[mask, 'B'] = val
except Exception as e:
    print(f"\nLength 1 error: {e}")

df = pd.DataFrame({'A': [1, 2, 3], 'B': [None, None, None]})
val = ['x', 'y', 'z'] # length 3
try:
    df.loc[mask, 'B'] = val
except Exception as e:
    print(f"\nLength 3 error: {e}")

# What if we want to set a list as a single value for multiple rows?
df = pd.DataFrame({'A': [1, 2, 3], 'B': [object(), object(), object()]})
val = ['a', 'b'] # The list itself
try:
    # This is what's likely happening
    df.loc[mask, 'B'] = val
except Exception as e:
    print(f"\nSetting list as value error: {e}")

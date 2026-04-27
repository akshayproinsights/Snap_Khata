import requests

url = "https://pub-1ee455c147c54e23b37edcf721f0e3a9.r2.dev/omk/sales/20260427_153348_08ea80_CAP2614790005050587755.jpg"
response = requests.head(url)
print(f"URL: {url}")
print(f"Status Code: {response.status_code}")

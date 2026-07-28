"""One-off diagnostic: hits NSE directly (not through jugaad_data) to see
what's actually being returned instead of a zip file."""

import requests

session = requests.Session()

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "*/*",
    "Accept-Language": "en-US,en;q=0.9",
}

# Step 1: visit the homepage first, to pick up NSE's required session cookies
print("Visiting NSE homepage to get cookies...")
r1 = session.get("https://www.nseindia.com", headers=headers, timeout=15)
print("Homepage status:", r1.status_code)

# Step 2: try the actual F&O bhavcopy download URL for a recent date
test_url = "https://archives.nseindia.com/content/historical/DERIVATIVES/2026/JUL/fo24JUL2026bhav.csv.zip"
print(f"\nTrying: {test_url}")
r2 = session.get(test_url, headers=headers, timeout=15)
print("Status:", r2.status_code)
print("Content-Type:", r2.headers.get("Content-Type"))
print("First 300 bytes of response:")
print(r2.content[:300])
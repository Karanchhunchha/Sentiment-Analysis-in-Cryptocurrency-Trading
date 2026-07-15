import os
import requests
import zipfile
import pandas as pd
from datetime import datetime, timedelta
from io import BytesIO

# Configuration
SYMBOL = "BTCUSDT"
INTERVAL = "15m"
MARKET_TYPE = "spot"  # "spot" or "futures/um"
START_YEAR = 2018
NOW = datetime.now()
DOWNLOAD_DIR = "data/market/raw_downloads"
OUTPUT_FILE = f"data/market/{SYMBOL.lower()}_{INTERVAL}_data_full.csv"

os.makedirs(DOWNLOAD_DIR, exist_ok=True)

monthly_base_url = f"https://data.binance.vision/data/{MARKET_TYPE}/monthly/klines/{SYMBOL}/{INTERVAL}/"
daily_base_url = f"https://data.binance.vision/data/{MARKET_TYPE}/daily/klines/{SYMBOL}/{INTERVAL}/"

all_dataframes = []

def download_and_extract(url, file_name):
    print(f"Checking {file_name}...", end=" ")
    try:
        response = requests.get(url, stream=True)
        if response.status_code == 200:
            with zipfile.ZipFile(BytesIO(response.content)) as z:
                csv_filename = z.namelist()[0]
                with z.open(csv_filename) as f:
                    df = pd.read_csv(f, header=None)
                    df.columns = [
                        "Open_Time", "Open", "High", "Low", "Close", "Volume",
                        "Close_Time", "Quote_Asset_Volume", "Number_Of_Trades",
                        "Taker_Buy_Base_Volume", "Taker_Buy_Quote_Volume", "Ignore"
                    ]
                    all_dataframes.append(df)
            print("Downloaded and Extracted")
            return True
        else:
            print(f"Not found (Status {response.status_code})")
            return False
    except Exception as e:
        print(f"Error: {e}")
        return False

print(f"Starting automated FULL download for {SYMBOL} {INTERVAL} klines...")

# 1. Download Historical Monthly Data
print("\n--- Phase 1: Downloading Monthly Historical Data ---")
for year in range(START_YEAR, NOW.year + 1):
    for month in range(1, 13):
        # Stop monthly downloads for the current year and current (or future) months
        # Because the current month's monthly zip won't exist until the month is fully over.
        if year == NOW.year and month >= NOW.month:
            break
            
        month_str = f"{month:02d}"
        file_name = f"{SYMBOL}-{INTERVAL}-{year}-{month_str}.zip"
        url = monthly_base_url + file_name
        download_and_extract(url, file_name)

# 2. Download Daily Data for the Current Month
print("\n--- Phase 2: Downloading Daily Data for Current Month ---")
# Start from the 1st of the current month
current_date = datetime(NOW.year, NOW.month, 1)
while current_date <= NOW:
    date_str = current_date.strftime("%Y-%m-%d")
    file_name = f"{SYMBOL}-{INTERVAL}-{date_str}.zip"
    url = daily_base_url + file_name
    download_and_extract(url, file_name)
    current_date += timedelta(days=1)

# 3. Combine and Save
if all_dataframes:
    print("\nCombining all data into a single dataset...")
    final_df = pd.concat(all_dataframes, ignore_index=True)
    
    # Sort to ensure absolute chronological order
    final_df = final_df.sort_values(by="Open_Time").reset_index(drop=True)
    
    # Convert timestamps
    final_df['Open_Time'] = pd.to_datetime(final_df['Open_Time'], unit='ms')
    final_df['Close_Time'] = pd.to_datetime(final_df['Close_Time'], unit='ms')
    
    # Remove any potential duplicates (sometimes overlaps happen)
    final_df = final_df.drop_duplicates(subset=['Open_Time'])
    
    # Save
    final_df.to_csv(OUTPUT_FILE, index=False)
    print(f"Success! Combined {len(final_df)} rows of data saved to: {OUTPUT_FILE}")
else:
    print("\nNo data was downloaded. Please check your internet connection or date ranges.")

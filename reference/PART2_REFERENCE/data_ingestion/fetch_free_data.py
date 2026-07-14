# fetch_free_data.py
# KCryptoX8 Ingestion Engine
# Fetches live data from free APIs using python standard library.

import urllib.request
import json
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
import os

def fetch_binance_ohlcv(symbol="BTCUSDT", interval="5m", limit=1000):
    """Fetches OHLCV price data from Binance API"""
    print(f"📥 Fetching {limit} {interval} candles for {symbol} from Binance...")
    url = f"https://api.binance.com/api/v3/klines?symbol={symbol}&interval={interval}&limit={limit}"
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read())
            
        processed_prices = []
        for row in data:
            # Binance output structure: 
            # [OpenTime, Open, High, Low, Close, Volume, CloseTime, ...]
            timestamp = datetime.fromtimestamp(row[0]/1000.0, tz=timezone.utc).isoformat()
            processed_prices.append({
                "timestamp": timestamp,
                "symbol": symbol.replace("USDT", ""),
                "open": float(row[1]),
                "high": float(row[2]),
                "low": float(row[3]),
                "close": float(row[4]),
                "volume": float(row[5])
            })
        return processed_prices
    except Exception as e:
        print(f"❌ Error fetching Binance OHLCV: {e}")
        return []

def fetch_rss_feeds():
    """Parses CoinDesk and CoinTelegraph RSS feeds"""
    feeds = [
        {"name": "coindesk", "url": "https://www.coindesk.com/arc/outboundfeeds/rss/"},
        {"name": "cointelegraph", "url": "https://cointelegraph.com/rss"}
    ]
    
    all_articles = []
    
    for feed in feeds:
        print(f"📰 Fetching RSS feed from {feed['name']}...")
        try:
            req = urllib.request.Request(feed['url'], headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req) as response:
                xml_data = response.read()
                
            root = ET.fromstring(xml_data)
            for item in root.findall('.//item'):
                title = item.find('title').text if item.find('title') is not None else ""
                description = item.find('description').text if item.find('description') is not None else ""
                pub_date_str = item.find('pubDate').text if item.find('pubDate') is not None else ""
                
                # Parse pubDate (Standard RSS format: e.g. "Mon, 13 Jul 2026 14:00:00 +0000")
                try:
                    # Strip out GMT or timezone offsets
                    clean_date_str = pub_date_str.split(" +")[0].split(" -")[0]
                    pub_date = datetime.strptime(clean_date_str, "%a, %d %b %Y %H:%M:%S").replace(tzinfo=timezone.utc).isoformat()
                except Exception:
                    pub_date = datetime.now(timezone.utc).isoformat()
                
                combined_content = f"{title}. {description}"
                # Clean HTML tags if any
                combined_content = combined_content.replace("<p>", "").replace("</p>", "").strip()
                
                all_articles.append({
                    "timestamp": pub_date,
                    "source": f"rss_{feed['name']}",
                    "text": combined_content
                })
        except Exception as e:
            print(f"❌ Error parsing {feed['name']} RSS feed: {e}")
            
    return all_articles

def save_data_locally(prices, feeds, output_dir="temp_data"):
    """Saves the fetched prices and feeds to JSON files for MATLAB loading"""
    os.makedirs(output_dir, exist_ok=True)
    
    prices_file = os.path.join(output_dir, "binance_prices.json")
    feeds_file = os.path.join(output_dir, "rss_feeds.json")
    
    with open(prices_file, "w") as f:
        json.dump(prices, f, indent=4)
        
    with open(feeds_file, "w") as f:
        json.dump(feeds, f, indent=4)
        
    print(f"✅ Temporary data files saved in {output_dir}/ directory.")

if __name__ == "__main__":
    prices = fetch_binance_ohlcv("BTCUSDT", "5m", 1000)
    feeds = fetch_rss_feeds()
    save_data_locally(prices, feeds)

import urllib.request
import json

def get_trend(interval):
    url = f'https://api.binance.com/api/v3/klines?symbol=BTCUSDT&interval={interval}&limit=2'
    data = json.loads(urllib.request.urlopen(url).read())
    return float(data[1][4]) - float(data[0][4])

price = json.loads(urllib.request.urlopen('https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT').read())['price']

print("========================================")
print("FINAL MACRO DATA CHECK")
print("========================================")
print(f"Current Price: ${float(price):.2f}")
print(f"30-Minute Momentum:  ${get_trend('30m'):.2f}")
print(f"1-Hour Momentum:     ${get_trend('1h'):.2f}")
print(f"4-Hour Macro Trend:  ${get_trend('4h'):.2f}")
print(f"Daily Macro Trend:   ${get_trend('1d'):.2f}")
print("========================================")

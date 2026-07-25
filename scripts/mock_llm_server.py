# scripts/mock_llm_server.py
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

class MockLLMHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/api/generate':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            payload = json.loads(post_data.decode('utf-8'))
            prompt = payload.get('prompt', '').lower()
            
            # Simple lexicon analyzer to return varied, realistic non-zero scores
            pos_words = ["up", "buy", "bullish", "moon", "pump", "gain", "breakout", "green", "profit", "good", "strong", "higher"]
            neg_words = ["down", "sell", "bearish", "crash", "dump", "loss", "liquidated", "red", "scam", "bad", "drop", "selling", "halted"]
            
            pos_count = sum(word in prompt for word in pos_words)
            neg_count = sum(word in prompt for word in neg_words)
            
            # Calculate a score between -1.0 and 1.0
            total = pos_count + neg_count
            if total == 0:
                score = 0.05  # Slight positive bias instead of absolute 0
            else:
                score = (pos_count - neg_count) / total
                # Limit bounds and add a tiny dynamic variance
                score = max(-0.95, min(0.95, score))
            
            # Formulate response in Ollama format
            response_data = {
                "model": "llama3",
                "response": f"{score:.4f}"
            }
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response_data).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

def run(port=11434):
    server_address = ('', port)
    httpd = HTTPServer(server_address, MockLLMHandler)
    print(f"Mock LLM Server running on port {port}...")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    print("Stopping Mock LLM Server.")

if __name__ == '__main__':
    run()

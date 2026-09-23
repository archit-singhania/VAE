"""Synthetic local UI demo running the real ML engine. No external writes."""

import json
from datetime import UTC, datetime, timedelta
from http.server import ThreadingHTTPServer

from mock_ui_api import Handler

from aevra_api.services.ml_insights import History, analyze


class MlHandler(Handler):
    def do_POST(self):
        if not self.path.endswith('/ml/insights'):
            return super().do_POST()
        payload = json.loads(self.rfile.read(int(self.headers.get('Content-Length', '0'))))
        captions = [f'Fresh coffee roast {i} with espresso aroma #coffee #roast{i}' for i in range(5)]
        captions += [f'Mountain hiking trail {i} with outdoor adventures #hiking #trail{i}' for i in range(5)]
        history = History(
            texts=[{'id': str(i), 'text': text, 'platform': 'instagram'} for i, text in enumerate(captions)],
            approved=captions[:5],
            assets=[{'id': 'demo-coffee', 'text': 'Fresh coffee roast espresso aroma', 'label': 'Coffee morning.jpg'}],
            posts=[], daily={},
        )
        now = datetime.now(UTC)
        for i in range(120):
            words = 5 + (i * 17) % 50
            platform = 'instagram' if i % 2 else 'facebook'
            rate = words / 4 + (10 if platform == 'instagram' else 0)
            history.posts.append({'id': str(i), 'text': 'coffee ' * words, 'platform': platform,
                                  'published': (now - timedelta(days=150 - i)).replace(hour=12),
                                  'impressions': 10000, 'engagements': int(rate * 100), 'rate': rate})
        total = 0
        for i in range(35):
            total += 10 + i * 2
            history.daily[(now - timedelta(days=34 - i)).date()] = {'demo': total}
        report = analyze(history, payload.get('draft', ''), payload.get('platform', 'instagram'))
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(report).encode())


if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', 8000), MlHandler).serve_forever()

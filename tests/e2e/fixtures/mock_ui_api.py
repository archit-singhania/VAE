from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from datetime import datetime, timezone
now=datetime.now(timezone.utc).isoformat()
class Handler(BaseHTTPRequestHandler):
 def do_GET(self):
  path=self.path
  value=[]
  if path.endswith('/auth/me'): value={'id':'qa-user','email':'creator@example.test','display_name':'Alex Studio','account_type':'creator','brand_name':'Studio','avatar_url':None,'is_admin':False,'is_active':True,'account_status':'approved'}
  elif path.endswith('/workspaces'): value=[{'id':'qa-workspace','name':'Studio','timezone':'UTC','is_active':True}]
  elif path.endswith('/publishing/accounts'): value=[{'id':'qa-channel','platform':'instagram','display_name':'@studio','status':'connected','capabilities':['publish'],'last_verified_at':now}]
  elif path.endswith('/media/assets'): value=[{'id':'qa-asset','filename':'Morning light.png','media_type':'image','status':'ready','prompt':'Warm morning light','download_url':'/brand/aevra-mark.svg','created_at':now}]
  elif path.endswith('/operations/schedule'): value=[{'id':'qa-post','social_account_id':'qa-channel','scheduled_for':now,'status':'scheduled','payload':{'text':'A moment worth sharing.'},'created_at':now}]
  elif path.endswith('/operations/metrics'): value=[{'id':'qa-metric','social_account_id':'qa-channel','external_post_id':'Post 01','collected_at':now,'impressions':1240,'engagements':86,'likes':70,'comments':10,'shares':6,'clicks':14}]
  self.send_response(200);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(json.dumps(value).encode())
 def do_POST(self):
  self.send_response(405);self.end_headers()
 def log_message(self,*args): pass
if __name__ == '__main__':
 ThreadingHTTPServer(('127.0.0.1',8000),Handler).serve_forever()

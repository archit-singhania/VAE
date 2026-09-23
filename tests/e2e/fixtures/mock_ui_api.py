from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import argparse
from datetime import datetime, timezone
now=datetime.now(timezone.utc).isoformat()
admin_usage = dict(assets=24, generated_assets=18, channels=2, scheduled=5, queued=1,
                  published=12, failed=1, schedule_failed=0, impressions=12400,
                  engagements=860, clicks=140, measured_posts=12, generation_runs=8,
                  prompt_tokens=4200, completion_tokens=2600)
admin_overview = dict(users_total=1, users_approved=1, assets_total=24, channels_total=2,
    totals=admin_usage, users=[dict(admin_usage, user_id='qa-customer', display_name='Alex Studio',
    brand_name='Studio', account_type='creator', account_status='approved', created_at=now)],
    platforms=[dict(admin_usage, platform='instagram', connected=2)],
    models=[dict(kind='llm', provider='Demo provider', model='Demo model', requests=8,
    failed=0, prompt_tokens=4200, completion_tokens=2600, metered_runs=8)],
    metrics_updated_at=now, generated_at=now)

class Handler(BaseHTTPRequestHandler):
 admin = False
 signed_out = False
 def do_GET(self):
  path=self.path
  value=[]
  if path.endswith('/auth/me') and self.signed_out:
   self.send_response(401);self.end_headers();return
  if path.endswith('/auth/admin/overview'):
   self.send_response(200);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(json.dumps(admin_overview).encode());return
  if path.endswith('/auth/me'): value={'id':'qa-user','email':'creator@example.test','display_name':'Alex Studio','account_type':'creator','brand_name':'Studio','avatar_url':None,'is_admin':self.admin,'is_active':True,'account_status':'approved'}
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
 parser=argparse.ArgumentParser()
 parser.add_argument('--admin',action='store_true')
 parser.add_argument('--signed-out',action='store_true')
 args=parser.parse_args()
 Handler.admin=args.admin
 Handler.signed_out=args.signed_out
 ThreadingHTTPServer(('127.0.0.1',8000),Handler).serve_forever()

#!/usr/bin/env python3
"""Static inventory checks for the supplied mindRID schema/client sources."""
from pathlib import Path
import re, sys
root=Path(sys.argv[1]) if len(sys.argv)>1 else Path('.')
schema=(root/'schema.sql').read_text()
app=(root/'app.js').read_text()
tables=set(re.findall(r'create table if not exists public\.([a-z_]+)',schema,re.I))
rls=set(re.findall(r'alter table public\.([a-z_]+) enable row level security',schema,re.I))
policies=re.findall(r'create policy\s+([a-z_]+)\s+on\s+(?:public|storage)\.([a-z_]+)',schema,re.I)
print('public tables:',len(tables))
print('explicit RLS enable statements:',len(rls))
print('tables lacking explicit RLS enable in this file:',', '.join(sorted(tables-rls)) or 'none')
print('policies:',len(policies))
checks={
 'circle_messages RLS enabled':'circle_messages' in rls,
 'Google OAuth client flow':bool(re.search(r'signInWithOAuth|provider\s*:\s*[\'\"]google[\'\"]',app,re.I)),
 'mention consent flow':bool(re.search(r'mention.*consent|consent.*mention',schema+'\n'+app,re.I)),
 'account export UI':bool(re.search(r'export.*account|export.*data|download.*data',app,re.I)),
 'account deletion RPC named':'mindrid_delete_account' in schema,
 'is_preview in schema':bool(re.search(r'is_preview\s+boolean',schema)),
}
for name,ok in checks.items(): print(('PASS' if ok else 'FLAG'),name)

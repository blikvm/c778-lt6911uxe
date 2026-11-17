from pathlib import Path
import time,os
p=Path.home()/'.local/state/c778-factory'
while True:
 try:
  f=p/'audio-status.txt'
  ok=f.read_text().startswith('声音正常') and time.time()-f.stat().st_mtime<6
  for name,text in [('audio-green.txt','声音正常' if ok else ''),('audio-red.txt','' if ok else '声音异常')]:
   tmp=p/(name+'.tmp');tmp.write_text(text);os.replace(tmp,p/name)
 except Exception: pass
 time.sleep(.3)

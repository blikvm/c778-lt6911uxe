import subprocess,os,time,json,signal,re
from pathlib import Path
base=Path(__file__).resolve().parent
p=Path.home()/'.local/state/c778-factory'
p.mkdir(parents=True,exist_ok=True)
os.chdir(p)
import fcntl
lock=open(p/'factory.lock','w')
try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
except BlockingIOError:raise SystemExit()
os.environ.update(DISPLAY=':0',SDL_VIDEODRIVER='x11')
(p/'audio-status.txt').write_text('声音待检测');(p/'audio-green.txt').write_text('');(p/'audio-red.txt').write_text('声音异常')
display_env=dict(os.environ)
subprocess.run(['wlr-randr','--output','HDMI-A-1','--pos','0,0'],env=display_env)
subprocess.run(['wlr-randr','--output','HDMI-A-2','--off'],env=display_env)
time.sleep(2)
subprocess.run(['wlr-randr','--output','HDMI-A-2','--on','--mode','3840x2160@60Hz','--pos','1280,0'],env=display_env)
time.sleep(3)
children={}
def stop(signum,frame):raise SystemExit()
signal.signal(signal.SIGTERM,stop)
signal.signal(signal.SIGINT,stop)
def start(name,args,display=None):
 env=os.environ.copy()
 if display is not None:env['SDL_VIDEO_FULLSCREEN_DISPLAY']=str(display)
 log=open(p/(name+'.log'),'a')
 children[name]=(subprocess.Popen(args,env=env,stdout=log,stderr=log,start_new_session=True),args,display)
start('source',json.loads((base/'source-args.json').read_text()),1)
start('tone',['bash','-o','pipefail','-c','ffmpeg -nostdin -re -f lavfi -i "aevalsrc=0.10*sin(2*PI*1000*t)|0.10*sin(2*PI*1500*t):s=48000" -f s16le - 2>tone-generator.log | aplay -D plughw:vc4hdmi1,0 -t raw -f S16_LE -r48000 -c2'])
start('status-colors',['python3',str(base/'status-colors.py')])
start('audio-monitor',['python3',str(base/'audio-monitor.py')])
try:
 while True:
  if 'preview' not in children:
   r=subprocess.run(['bash',str(base.parent/'scripts/configure-capture.sh')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
   if r.returncode==0:
    args=json.loads((base/'preview-args.json').read_text())
    node=subprocess.check_output(['sh','-c','. ./scripts/find-path.sh; c778_find_path; printf %s "$C778_VIDEO"'],cwd=base.parent,text=True).strip()
    args[args.index('-i')+1]=node
    fmt=subprocess.check_output(['v4l2-ctl','-d',node,'--get-fmt-video'],text=True)
    if "'UYVY'" not in fmt:raise RuntimeError('Factory preview currently requires UYVY')
    m=re.search(r'Width/Height\s*:\s*(\d+)/(\d+)',fmt)
    if m:args[args.index('-video_size')+1]=m[1]+'x'+m[2]
    start('preview',args,0)
  for name,(proc,args,display) in list(children.items()):
   if proc.poll() is not None:
    if name=='preview':del children[name]
    else:start(name,args,display)
  for logfile in p.glob("*.log"):
   if logfile.stat().st_size>8*1024*1024:
    with logfile.open("w"):pass
  time.sleep(2)
finally:
 for proc,args,display in children.values():
  try:os.killpg(proc.pid,signal.SIGTERM)
  except ProcessLookupError:pass

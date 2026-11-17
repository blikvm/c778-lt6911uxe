import subprocess, time, json, os
from pathlib import Path
from audio_check import analyze
p = Path.home()/'.local/state/c778-factory'
p.mkdir(parents=True, exist_ok=True)
def publish(text, report):
    tmp=p/'audio-status.tmp'; tmp.write_text(text); os.replace(tmp,p/'audio-status.txt')
    tmp=p/'audio-result.tmp'; tmp.write_text(json.dumps(dict(time=time.time(), **report))); os.replace(tmp,p/'audio-result.json')
while True:
    try:
        r=subprocess.run(['arecord','-q','-D','hw:C778I2S,0','-f','S32_LE','-r','48000','-c','2','-d','1',str(p/'monitor.wav')],capture_output=True,timeout=3)
        if r.returncode:
            publish('声音异常：采集失败',dict(ok=False,error=r.stderr.decode(errors='replace')))
        else:
            result=analyze(p/'monitor.wav')
            publish('声音正常：左右声道通过' if result['ok'] else '声音异常：测试音不符', result)
            print(json.dumps(result),flush=True)
            if result['ok']:
                subprocess.run(['aplay','-q','-D','plughw:vc4hdmi0,0',str(p/'monitor.wav')],check=True,timeout=3)
    except subprocess.TimeoutExpired:
        publish('声音异常：采集或播放超时',dict(ok=False,error='timeout'))
    except Exception as e:
        publish('声音异常：检测失败',dict(ok=False,error=str(e)))
    time.sleep(.2)

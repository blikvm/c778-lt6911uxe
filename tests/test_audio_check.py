import importlib.util, unittest, tempfile, wave, array, math, sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('audio_check',Path(__file__).resolve().parents[1]/'factory/audio_check.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class StereoCheck(unittest.TestCase):
 def check_tones(self,left,right):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'test.wav';a=array.array('i')
   for n in range(48000):
    for hz in (left,right):a.append(int(.1*2**31*math.sin(2*math.pi*hz*n/48000)) if hz else 0)
   if sys.byteorder!='little':a.byteswap()
   with wave.open(str(p),'wb') as w:w.setparams((2,4,48000,0,'NONE','none'));w.writeframes(a.tobytes())
   return m.analyze(p)['ok']
 def test_stereo(self):self.assertTrue(self.check_tones(1000,1500))
 def test_right_missing(self):self.assertFalse(self.check_tones(1000,0))
 def test_left_missing(self):self.assertFalse(self.check_tones(0,1500))
 def test_swapped(self):self.assertFalse(self.check_tones(1500,1000))
 def test_same_channels(self):self.assertFalse(self.check_tones(1000,1000))
if __name__=='__main__':unittest.main()

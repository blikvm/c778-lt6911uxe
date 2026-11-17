"""Bounded stereo test-tone checks; values are not calibrated audio measurements."""
import array, math, sys, wave

def analyze(path):
    with wave.open(str(path)) as w:
        if (w.getnchannels(), w.getsampwidth(), w.getframerate()) != (2, 4, 48000):
            raise ValueError('Expected stereo S32_LE 48 kHz')
        a = array.array('i', w.readframes(w.getnframes()))
    if sys.byteorder != 'little':
        a.byteswap()
    result = []
    for channel, expected in enumerate((1000, 1500)):
        x = a[channel::2]
        rms = math.sqrt(sum(v*v for v in x)/max(1, len(x)))/2**31
        crossings = sum((x[i] >= 0) != (x[i-1] >= 0) for i in range(1, len(x)))
        hz = crossings*48000/(2*max(1, len(x)))
        # Require a full bounded recording and the expected channel-specific tone.
        ok = len(x) >= 47000 and 0.005 < rms < 0.5 and abs(hz-expected) < 30
        result.append(dict(channel=channel, rms=rms, hz=hz, expected=expected, ok=ok))
    return dict(ok=all(c['ok'] for c in result), channels=result)

import numpy as np
import sounddevice as sd
import threading


SAMPLE_RATE = 16000
CHANNELS = 1


class Recorder:
    def __init__(self):
        self._buffer = []
        self._stream = None
        self._lock = threading.Lock()

    def _callback(self, indata, frames, time_info, status):
        with self._lock:
            self._buffer.append(indata.copy())

    def start(self):
        with self._lock:
            self._buffer = []
        self._stream = sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=CHANNELS,
            dtype="float32",
            callback=self._callback,
        )
        self._stream.start()

    def stop(self):
        if self._stream is not None:
            self._stream.stop()
            self._stream.close()
            self._stream = None
        with self._lock:
            if not self._buffer:
                return np.array([], dtype=np.float32)
            audio = np.concatenate(self._buffer, axis=0).flatten()
            self._buffer = []
        return audio

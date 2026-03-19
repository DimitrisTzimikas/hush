import whisper
import numpy as np


class Transcriber:
    def __init__(self, model_name="base"):
        self._model = None
        self._model_name = model_name

    def load_model(self):
        self._model = whisper.load_model(self._model_name)

    def transcribe(self, audio: np.ndarray) -> str:
        if self._model is None:
            self.load_model()
        if len(audio) == 0:
            return ""
        # Whisper expects float32 audio at 16kHz
        # Pad or trim to 30 seconds as whisper expects
        result = self._model.transcribe(audio, fp16=False)
        text = result["text"].strip()
        return text

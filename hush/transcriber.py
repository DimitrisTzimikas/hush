import whisper
import numpy as np


class Transcriber:
    def __init__(self, model_name="base"):
        self._model = None
        self._model_name = model_name
        self.language = None  # None = auto-detect

    def load_model(self):
        self._model = whisper.load_model(self._model_name)

    def transcribe(self, audio: np.ndarray) -> str:
        if self._model is None:
            self.load_model()
        if len(audio) == 0:
            return ""
        opts = {"fp16": False}
        if self.language:
            opts["language"] = self.language
        result = self._model.transcribe(audio, **opts)
        text = result["text"].strip()
        return text

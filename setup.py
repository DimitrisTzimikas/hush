from setuptools import setup, find_packages

setup(
    name="hush",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[
        "openai-whisper",
        "sounddevice",
        "numpy",
        "rumps",
        "pynput",
        "pyperclip",
    ],
    entry_points={
        "console_scripts": [
            "hush=hush.app:main",
        ],
    },
)

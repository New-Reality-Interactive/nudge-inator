# Alarm tones

The six alarm tones the app ships (Chime, Bell, Pulse, Beacon, Rise and Siren, from gentle to
insistent) are original. `generate-tones.py` synthesizes every one from sine waves and simple
envelopes: no samples, no recordings and no third-party audio went into them, so there is nothing
to license, and Nudge-inator's own license covers them like the rest of the repository.

## Regenerate

```
python3 scripts/tones/generate-tones.py
```

This needs only Python 3 and rewrites `App/Resources/Tones/<name>.caf`. Nothing in it is random, so
running it again produces the same files. Each file is about 25 seconds of mono 16-bit linear PCM at
22.05 kHz; keep a tone under 30 seconds, because Apple's notification sound documentation says a
longer file falls back to the default sound.

## Replace a tone

Change its function in `generate-tones.py` and run the script, or drop in a replacement
`App/Resources/Tones/<name>.caf` made another way (it must be your own work or properly licensed,
and under 30 seconds). Keep the file name: it is the tone's saved ID (`AlarmSound.id`) plus
`.caf`, and the alarm adapter and the preview pass it by that name. Never rename one.

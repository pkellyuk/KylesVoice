# Store assets

Everything Google Play asks for, generated reproducibly rather than drawn by
hand so it can be regenerated when the app changes.

| File | Purpose | Produced by |
|---|---|---|
| `icon-512.png` | Play Store listing icon | `tools/generate_icon.py` |
| `feature-graphic-1024x500.png` | Play Store feature graphic | `tools/generate_feature_graphic.py` |
| `shot-*.png` | Tablet screenshots, 2560 x 1600 | Captured from the tablet emulator |

The launcher icons under `app/android/app/src/main/res/mipmap-*` come from the
same icon script.

## Regenerating

```bat
python3 tools/generate_icon.py
python3 tools/generate_feature_graphic.py
```

## Retaking the screenshots

The demo board is generated so the screenshots do not depend on whatever happens
to be on a device:

```bat
python3 tools/make_demo_board.py

:: A debug build is needed because run-as only works on debuggable apps.
cd app && flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb push ..\tools\demo_board.json /data/local/tmp/board.json
adb shell run-as io.github.pkellyuk.kylesvoice mkdir -p app_flutter
adb shell run-as io.github.pkellyuk.kylesvoice cp /data/local/tmp/board.json app_flutter/board.json
adb shell am start -n io.github.pkellyuk.kylesvoice/.MainActivity
adb exec-out screencap -p > ..\docs\store\shot-1-board.png
```

No real photograph of a child appears in any store asset, and none should.

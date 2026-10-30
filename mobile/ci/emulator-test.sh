#!/usr/bin/env bash
# Test de fumée sur émulateur : installe l'APK, lance l'appli, ouvre un formulaire, prend des captures.
set -ux
PKG=fr.sitenor.terrain
mkdir -p shots

adb install -r -g Terrain-SATREL-SITENOR.apk
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
sleep 25
adb exec-out screencap -p > shots/01-accueil.png
echo "pid: $(adb shell pidof $PKG)" | tee shots/pid.txt

# Le contenu d'une WebView n'apparaît dans l'arbre d'accessibilité qu'après un premier relevé : on réessaie.
tap_text() {
  for i in 1 2 3 4 5; do
    adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    adb pull /sdcard/ui.xml shots/ui.xml >/dev/null 2>&1
    if python3 - "$1" "${2:-contains}" <<'PY'
import re, sys, subprocess
text, mode = sys.argv[1].lower(), sys.argv[2]
xml = open('shots/ui.xml', encoding='utf-8', errors='ignore').read()
for m in re.finditer(r'<node[^>]*?(?:text|content-desc)="([^"]*)"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml):
    value = m.group(1).lower()
    if (value == text) if mode == 'exact' else (text in value):
        l, t, r, b = map(int, m.groups()[1:])
        x, y = (l + r) // 2, (t + b) // 2
        print(f"tap '{m.group(1)}' at {x},{y}")
        subprocess.run(['adb', 'shell', 'input', 'tap', str(x), str(y)])
        sys.exit(0)
print(f"texte '{sys.argv[1]}' introuvable")
sys.exit(1)
PY
    then return 0; fi
    sleep 3
  done
  return 1
}

tap_text "Audit terrain"; sleep 3
adb exec-out screencap -p > shots/02-formulaire.png
tap_text "Nouvelle saisie"; sleep 3
adb exec-out screencap -p > shots/03-etape-1.png
tap_text "Suivant"; sleep 2
adb exec-out screencap -p > shots/04-etape-2.png
tap_text "Suivant"; sleep 2
adb exec-out screencap -p > shots/05-etape-3.png

adb logcat -d -s Capacitor Capacitor/Console chromium:E AndroidRuntime:E > shots/logcat.txt
exit 0

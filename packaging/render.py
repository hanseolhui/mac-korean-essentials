# DMG 배경 그림 만들기 (1x · 2x → 하나의 tiff)
import os, subprocess, time
HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
def shot(scale, out):
    if os.path.exists(out): os.remove(out)
    p = subprocess.Popen([CHROME, "--headless=new", f"--user-data-dir={HERE}/.chrome", "--hide-scrollbars", f"--force-device-scale-factor={scale}",
                          "--window-size=660,400", "--virtual-time-budget=800", f"--screenshot={out}", "file://" + os.path.join(HERE, "dmg-bg.html")],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(60):
        if os.path.exists(out) and os.path.getsize(out) > 0: break
        time.sleep(0.5)
    time.sleep(0.5); p.kill(); p.wait()
shot(1, os.path.join(HERE, "dmg-bg.png")); shot(2, os.path.join(HERE, "dmg-bg@2x.png"))
subprocess.run(["tiffutil", "-cathidpicheck", "dmg-bg.png", "dmg-bg@2x.png", "-out", "dmg-bg.tiff"], cwd=HERE, capture_output=True)
subprocess.run(["rm", "-rf", os.path.join(HERE, ".chrome")])
print(os.listdir(HERE))

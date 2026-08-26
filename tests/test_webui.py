import pathlib
import re

html = pathlib.Path(__file__).parents[1].joinpath("webroot/index.html").read_text()
assert "ksu.exec" in html and "from 'kernelsu'" not in html
for required in ("statusTitle", "strategies", "progress", "output", "clearLog", "refreshLog", "exportLog", "logging", "loggingState", "domains", "saveDomains", "domainState"):
    assert f'id="{required}"' in html
assert "Работает" in html and "Остановлен" in html
assert "border-radius:20px" in html
assert "/data/adb/ksu/bin/ksud" in html and "module action zapret_android" in html
assert "logging-on" in html and "logging-off" in html
assert "/storage/emulated/0/Download/zapret-" in html
assert "list-general-user.txt" in html and "Пользовательские домены" in html
script = re.search(r"<script>(.*)</script>", html, re.S).group(1)
pathlib.Path("/tmp/zapret-webui.js").write_text(script)
print("OK")

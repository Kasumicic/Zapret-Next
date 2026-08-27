import pathlib
import re

html = pathlib.Path(__file__).parents[1].joinpath("webroot/index.html").read_text()
assert "ksu.exec" in html and "from 'kernelsu'" not in html
assert "<title>zapret</title>" in html and "<span>zapret</span>" in html
for required in ("statusTitle", "statusBadge", "powerButton", "strategies", "modes", "applyMode", "progress", "output", "openLog", "clearLog", "refreshLog", "exportLog", "logging", "loggingState", "domains", "saveDomains", "domainState", "themeToggle", "themeIcon", "diagService", "diagNetwork", "diagConfig", "updateLabel", "updateState"):
    assert f'id="{required}"' in html
for screen in ("home", "settings", "diagnostics"):
    assert f'data-screen="{screen}"' in html
assert "Активен" in html and "Отключён" in html and "Запуск…" in html and "Ошибка" in html
assert "#e7a33e" in html and "#f7f4ee" in html and "#121212" in html
assert "prefers-color-scheme:dark" in html and "data-theme" in html
assert "/data/adb/ksu/bin/ksud" in html and "module action zapret_android" in html
assert "logging-on" in html and "logging-off" in html
assert "/storage/emulated/0/Download/zapret-" in html
assert "list-general-user.txt" in html and "Пользовательский режим" in html
assert "mode status" in html and "Совместимый · все сайты на портах" in html
assert "Стратегия и обновление" in html and "Расширенные настройки" not in html
for icon in ("icon-mode", "icon-settings", "icon-diagnostics", "icon-logo", "icon-chevron", "icon-moon", "icon-sun"):
    assert f'id="{icon}"' in html
assert 'class="row-icon">M' not in html and 'class="row-icon">⋮' not in html
assert "Скачиваем стратегии и nfqws" in html and "Обновление завершено" in html
assert "M10 108 C72 108 68 70 139 70 C156 70 174 70 191 70 C262 70 254 108 320 108" in html
assert ".running .route-live{stroke-dasharray:500 0}" in html
assert 'href="https://github.com/Kasumicic/Zapret-Next"' in html and "Открыть GitHub" in html
assert "${logFile}.1" in html
assert "logPanel.classList.add('open')" in html
script = re.search(r"<script>(.*)</script>", html, re.S).group(1)
pathlib.Path("/tmp/zapret-webui.js").write_text(script)
print("OK")

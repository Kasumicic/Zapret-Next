# Zapret Android

Автономный root-модуль KernelSU/Magisk: запускает `nfqws` при загрузке,
настраивает IPv4/IPv6 NFQUEUE и предоставляет WebUI/CLI.

## Сборка и установка

```sh
chmod +x build.sh tests/test_parser.sh
./tests/test_parser.sh
./build.sh
```

Во время сборки Python 3 скачивает актуальные стратегии, списки и дампы Flowseal,
а также официальные `nfqws` для arm64 и arm. Готовый ZIP не требует сети при
установке. Установите его в KernelSU/Magisk и перезагрузитесь — стандартная
`general.bat` запускается автоматически. Управление:

```sh
su -c 'zapret list'
su -c 'zapret strategy general.bat'
su -c 'zapret restart'
su -c 'zapret toggle'
su -c 'zapret logging off'
su -c 'zapret logging on'
```

KernelSU WebUI работает без системного монтирования. Для короткой команды `zapret`
в KernelSU нужен метамодуль OverlayFS; без него используйте полный путь
`/data/adb/modules/zapret_android/zapret`. Magisk монтирует `system/bin/zapret`
самостоятельно.

Настройки находятся в `/data/adb/modules/zapret_android/config.conf`. `INTERFACE=any`
охватывает Wi-Fi и мобильную сеть; можно задать `wlan0` или маску `rmnet+` для
iptables. Команда `zapret update` и `AUTO_UPDATE=1` остаются доступны для
последующих обновлений на устройстве, но для первого запуска не нужны.
Трафик loopback, VPN и туннельных интерфейсов (`tun*`, `wg*`, `ppp*`, IPsec,
Tailscale, ZeroTier и другие распространённые туннели) исключён из NFQUEUE.
Для совместимости с Root-режимом v2rayNG модуль также пропускает `utun*`, UID
v2rayNG и его метки маршрутизации `1`/`255`; цепь `CORE_FILTER` выполняется до
NFQUEUE независимо от порядка запуска приложений.

Переключатель «Логи» в WebUI и команда `zapret logging on|off` сохраняют настройку
в `config.conf`. Запуск из WebUI передаётся через `ksud module action`, поэтому
Android не завершает `nfqws` вместе с процессом KernelSU Manager.
Кнопка действия модуля в KernelSU переключает последнюю выбранную стратегию,
а «Экспорт» сохраняет журнал в общую папку `Download`.

Требования устройства: root, поддержка `NETFILTER_NETLINK_QUEUE` ядром и доступная
цель `NFQUEUE` в iptables либо nftables. Если производитель удалил NFQUEUE из ядра,
модуль не сможет перенаправить пакеты — это нельзя исправить скриптом.

Источники: стратегии [Flowseal](https://github.com/Flowseal/zapret-discord-youtube)
или [Sergeydigl3](https://github.com/Sergeydigl3/zapret-discord-youtube-linux),
бинарник [bol-van/zapret](https://github.com/bol-van/zapret).

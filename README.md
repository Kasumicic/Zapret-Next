# Zapret-Next

<p align="center">
  <strong>Автономный DPI-bypass модуль для Android</strong><br>
  KernelSU · Magisk · arm64 · arm · WebUI · CLI
</p>

<p align="center">
  <img alt="Android" src="https://img.shields.io/badge/platform-Android-55d98b">
  <img alt="Architectures" src="https://img.shields.io/badge/ABI-arm64%20%7C%20arm-6d5dfc">
  <img alt="Root" src="https://img.shields.io/badge/root-KernelSU%20%7C%20Magisk-ff6577">
</p>

Zapret-Next запускает `nfqws` при загрузке Android, настраивает IPv4/IPv6
NFQUEUE и предоставляет управление через KernelSU WebUI или CLI. Установочный
ZIP уже содержит бинарники, стратегии, списки и дампы: обязательное обновление
после установки не требуется.

> [!IMPORTANT]
> Модуль не является VPN и не расшифровывает трафик. Он изменяет признаки
> пакетов, по которым системы DPI определяют протоколы и сайты.

## Возможности

- полностью автономная установка без загрузок на телефоне;
- автоматический выбор `nfqws` для `arm64` или `arm`;
- современный KernelSU WebUI и CLI-команда `zapret`;
- стратегии Flowseal, пользовательские домены и три режима охвата;
- поддержка iptables и nftables, IPv4 и IPv6;
- исключение VPN/TUN/WireGuard и совместимость с Root-режимом v2rayNG;
- сохранение состояния после перезагрузки и проверка успешного запуска;
- переключаемый журнал, ротация и экспорт в папку `Download`;
- динамический статус прямо в описании модуля KernelSU.

## Требования

| Компонент | Требование |
|---|---|
| Root-менеджер | KernelSU или Magisk |
| Архитектура | `arm64-v8a` или `armeabi-v7a` |
| Ядро | `NETFILTER_NETLINK_QUEUE` и цель `NFQUEUE` |
| Firewall | iptables или nftables |

Если производитель удалил NFQUEUE из ядра, исправить это модулем невозможно.

## Установка

1. Скачайте `Zapret-Next.zip`.
2. Установите ZIP в KernelSU или Magisk.
3. Перезагрузите устройство.
4. Откройте WebUI модуля и выберите подходящую стратегию.

После первого запуска используется `general.bat`. В KernelSU штатная action-кнопка
переключает последнюю выбранную стратегию: повторное нажатие останавливает модуль.

## WebUI

В интерфейсе доступны:

- запуск, остановка и перезапуск `nfqws`;
- выбор стратегии и режима обработки;
- редактирование пользовательского списка доменов;
- включение и выключение логирования;
- просмотр, очистка и экспорт журнала;
- обновление стратегий и `nfqws` вручную.

Пользовательские домены сохраняются в
`data/lists/list-general-user.txt`. Указывайте по одному домену на строку:

```text
rutracker.org
nnmclub.to
example.org
```

Если модуль работает, сохранение списка автоматически перезапускает `nfqws`.

## Режимы обработки

| Режим в WebUI | CLI | Что обрабатывается |
|---|---|---|
| Списки доменов + IP | `loaded` | Доменные и IP-списки Flowseal |
| Только домены | `domains` | Только домены из основных и пользовательских списков |
| Все сайты на портах стратегии | `all` | Любые адреса, но только на портах выбранной стратегии |

VPN, прокси и туннельные интерфейсы исключаются во всех режимах. Режим `all`
не означает перехват каждого порта устройства.

## CLI

```sh
# Полный путь работает в KernelSU без OverlayFS
ZAPRET=/data/adb/modules/zapret_android/zapret

su -c "$ZAPRET status"
su -c "$ZAPRET list"
su -c "$ZAPRET strategy 'general (ALT).bat'"
su -c "$ZAPRET mode domains"
su -c "$ZAPRET restart"
su -c "$ZAPRET toggle"
su -c "$ZAPRET logging off"
```

Magisk обычно монтирует короткую команду `zapret` из `system/bin`. Для неё в
KernelSU потребуется OverlayFS; полный путь выше работает без метамодулей.

## Конфигурация

Файл настроек: `/data/adb/modules/zapret_android/config.conf`.

| Параметр | Значение по умолчанию | Назначение |
|---|---:|---|
| `STRATEGY` | `general.bat` | Файл стратегии Flowseal |
| `MODE` | `loaded` | `loaded`, `domains` или `all` |
| `INTERFACE` | `any` | Все сети либо интерфейс/маска, например `wlan0`, `rmnet+` |
| `FIREWALL` | `auto` | `auto`, `iptables` или `nft` |
| `LOGGING` | `1` | Запись диагностического журнала |
| `LOG_MAX_BYTES` | `2097152` | Размер текущего журнала до ротации |
| `AUTO_UPDATE` | `0` | Автоматическое обновление на устройстве |

Ручная остановка записывает `ENABLED=0`, поэтому модуль не запустится сам после
перезагрузки. Следующий ручной запуск снова включает автозапуск.

## Совместимость с VPN и прокси

Из NFQUEUE исключены loopback и распространённые туннели: `tun*`, `utun*`,
`tap*`, `wg*`, `ppp*`, IPsec, VTI, XFRM, GRE, Tailscale и ZeroTier.

Для v2rayNG Root Mode дополнительно пропускаются:

- UID пакетов `com.v2ray.ang` и `com.v2ray.ang.fdroid`;
- маршрутные метки `1` и `255`;
- интерфейс `utun7788` через общую маску `utun*`;
- цепочка `CORE_FILTER` до правил Zapret-Next.

## Журнал и диагностика

Основной журнал: `data/zapret.log`. При достижении 2 МБ он переносится в
`data/zapret.log.1`; хранится только одна предыдущая копия. Кнопка «Скачать»
объединяет обе части и сохраняет файл в Android `Download`.

При создании bug report приложите экспортированный журнал и укажите Android,
ядро, root-менеджер, стратегию, режим и другие сетевые root-приложения.
Перед публикацией удалите из журнала приватные домены и адреса.

## Последняя сборка

<!-- build-info:start -->
| Компонент | Версия последней сборки |
|---|---|
| Zapret-Next | `1.3.1` |
| nfqws / bol-van zapret | `v72.13` |
| Стратегии и списки Flowseal | `fb32282c55a0` |
| Исходный commit Zapret-Next | `b6a0cb3b7a75` |
| Дата сборки | `2026-08-26 14:16 UTC` |
<!-- build-info:end -->

## Сборка

На ПК нужны Bash, Python 3 и доступ к GitHub:

```sh
./tests/test_all.sh
./build.sh
```

`build.sh` запускает тесты, скачивает актуальные материалы Flowseal и официальный
релиз zapret, затем создаёт `Zapret-Next.zip`.

## Участие в разработке

Правила и чек-листы находятся в [CONTRIBUTING.md](CONTRIBUTING.md). Для ошибок
и предложений используйте шаблоны Issues, а перед Pull Request запустите
`./tests/test_all.sh`. Один PR должен решать одну задачу.

## Благодарности и происхождение

Zapret-Next создан с опорой на открытые проекты:

- [Sergeydigl3/zapret-discord-youtube-linux](https://github.com/Sergeydigl3/zapret-discord-youtube-linux) — архитектурное вдохновение и база Linux-адаптера;
- [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube) — база стратегий, списки и бинарные дампы;
- [bol-van/zapret](https://github.com/bol-van/zapret) — оригинальный проект и движок `nfqws`.

Zapret-Next не аффилирован с авторами перечисленных проектов. Права на сторонние
компоненты принадлежат их авторам и регулируются лицензиями исходных репозиториев.

## Ответственность

Проект предоставляется без гарантий. Пользователь самостоятельно отвечает за
совместимость с устройством и соблюдение применимого законодательства.

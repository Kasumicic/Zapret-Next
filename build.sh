#!/bin/sh
set -eu
cd "$(dirname "$0")"
./tests/test_all.sh
out=${1:-Zapret-Next.zip}
rm -f "$out"
python3 - "$out" <<'PY'
import io, json, pathlib, sys, tarfile, urllib.request, zipfile

root = pathlib.Path.cwd()
items = ('module.prop', 'customize.sh', 'service.sh', 'action.sh', 'uninstall.sh',
         'zapret', 'config.conf.example', 'lib', 'system', 'webroot', 'META-INF',
         'README.md', 'CONTRIBUTING.md')

def get(url):
    print(f'Downloading {url}', flush=True)
    request = urllib.request.Request(url, headers={'User-Agent': 'zapret-android-builder'})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()

def members(archive, predicate):
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:gz') as tar:
        for member in tar.getmembers():
            if member.isfile() and predicate(pathlib.PurePosixPath(member.name)):
                yield pathlib.PurePosixPath(member.name), tar.extractfile(member).read(), member.mode

flowseal = get('https://github.com/Flowseal/zapret-discord-youtube/archive/refs/heads/main.tar.gz')
release = json.loads(get('https://api.github.com/repos/bol-van/zapret/releases/latest'))
tag = release['tag_name']
zapret = get(f'https://github.com/bol-van/zapret/releases/download/{tag}/zapret-{tag}.tar.gz')

with zipfile.ZipFile(sys.argv[1], 'w', zipfile.ZIP_DEFLATED) as archive:
    for item in items:
        path = root / item
        paths = path.rglob('*') if path.is_dir() else (path,)
        for source in paths:
            if source.is_file() and source.name != '.DS_Store':
                archive.write(source, source.relative_to(root))
    found = set()
    for path, data, mode in members(flowseal, lambda p: (p.suffix.lower() == '.bat' and p.name.lower().startswith(('general', 'discord'))) or '/lists/' in f'/{p}' or (p.suffix.lower() == '.bin' and '/bin/' in f'/{p}')):
        if path.suffix.lower() == '.bat': target = f'payload/data/strategies/{path.name}'
        elif '/lists/' in f'/{path}': target = f'payload/data/lists/{path.name}'
        else: target = f'payload/data/bin/{path.name}'
        archive.writestr(target, data)
        found.add(target.split('/')[2])
    platforms = {'linux-arm64': 'arm64-v8a', 'linux-arm': 'armeabi-v7a'}
    binaries = set()
    for path, data, mode in members(zapret, lambda p: p.name == 'nfqws' and p.parent.name in platforms):
        abi = platforms[path.parent.name]
        info = zipfile.ZipInfo(f'payload/bin/{abi}/nfqws')
        info.external_attr = 0o755 << 16
        archive.writestr(info, data)
        binaries.add(abi)
    if not {'strategies', 'lists', 'bin'} <= found or binaries != set(platforms.values()):
        raise SystemExit(f'Incomplete payload: data={found}, binaries={binaries}')
    if 'payload/data/strategies/general.bat' not in archive.namelist():
        raise SystemExit('Default strategy general.bat is missing upstream')
print(f'Packed Flowseal main + zapret {tag}')
PY
echo "$out"

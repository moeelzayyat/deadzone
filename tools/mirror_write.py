"""DEADZONE mirror export, local side (A1.3). See docs/MIRROR.md.

Usage (from the repo root):  python tools/mirror_write.py <result> [<result> ...]
Each <result> is the output of one tools/mirror_export.luau run, saved by the harness (a JSON list of text blocks)
or as the raw JSON string. Pass every part of a chunked export (START = 1, then each `next`).

Writes mirror/src one-to-one with the Studio roots, verifies every file by length + FNV-1a against Studio,
deletes mirror files that no longer exist in Studio, regenerates mirror/sourcemap.json and checks the script count.
Exit 0 only when everything matches.
"""
import json
import os
import sys

ROOTMAP = {'Shared': 'shared', 'Server': 'server', 'Client': 'client', 'Tests': 'tests'}
EXT = {'Script': '.server.luau', 'LocalScript': '.client.luau', 'ModuleScript': '.luau', 'StringValue': '.txt'}
SCRIPT_CLASSES = ('Script', 'LocalScript', 'ModuleScript')
SRC = os.path.join('mirror', 'src')
KEEP = {os.path.join(SRC, '.gitkeep')}


def fnv(b: bytes) -> str:
    h = 2166136261
    for x in b:
        h = ((h ^ x) * 16777619) % 2**32
    return '%08x' % h


def file_path(studio_path: str, cls: str) -> str:
    parts = studio_path.split('/')
    parts[0] = ROOTMAP[parts[0]]
    return os.path.join(SRC, *parts) + EXT[cls]


def load(path: str) -> dict:
    text = open(path, encoding='utf-8').read().strip()
    if text.startswith('['):  # harness tool-result file: [{"type": "text", "text": "<json>"}]
        text = json.loads(text)[0]['text'].strip()
    if text.startswith('"'):  # result pasted as a JSON string literal
        text = json.loads(text)
    return json.loads(text)


def main(args: list[str]) -> int:
    sys.stdout.reconfigure(encoding='utf-8')
    if not args:
        print(__doc__)
        return 2
    if not os.path.isdir(SRC):
        print('run from the repo root (mirror/src not found)')
        return 2
    parts = [load(a) for a in args]
    first = parts[0]
    for p in parts[1:]:
        if p['manifest'] != first['manifest']:
            print('MISMATCH: parts come from different Studio states; export again from START = 1')
            return 1
    errors = [e for p in parts for e in p['errors']]
    if errors:
        for e in sorted(set(errors)):
            print('ERROR ' + e)
        print('nothing written')
        return 1
    if not any(p['start'] == 1 for p in parts):
        print('INCOMPLETE: the START = 1 part is missing')
        return 1
    starts = {p['start'] for p in parts}
    for p in parts:
        if p.get('next') is not None and p['next'] not in starts:
            print('INCOMPLETE: run the export again with START = %d and pass that result too' % p['next'])
            return 1
    sources = {}
    for p in parts:
        sources.update(p['sources'] or {})

    ok = True
    expected = set()
    written = 0
    for e in first['manifest']:
        fp = file_path(e['path'], e['className'])
        expected.add(os.path.normpath(fp))
        if e['path'] in sources:
            b = sources[e['path']].encode('utf-8')
            os.makedirs(os.path.dirname(fp), exist_ok=True)
            with open(fp, 'wb') as f:
                f.write(b)
            written += 1
        if not os.path.exists(fp):
            print('MISSING %s (vendor? export again with INCLUDE_VENDOR = true)' % fp)
            ok = False
            continue
        b = open(fp, 'rb').read()
        good = len(b) == e['len'] and fnv(b) == e['hash']
        ok &= good
        if b'\r' in b:
            print('WARN  %s contains CR characters (.gitattributes stores LF)' % fp)
        print('%s %s %d %s' % ('OK  ' if good else 'BAD ', fp.replace(os.sep, '/'), len(b), fnv(b))
              + ('' if good else ' · studio %d %s (export again with INCLUDE_VENDOR = true if vendor)' % (e['len'], e['hash'])))

    removed = 0
    for d, _, files in os.walk(SRC, topdown=False):
        for name in files:
            fp = os.path.normpath(os.path.join(d, name))
            if fp not in expected and fp not in {os.path.normpath(k) for k in KEEP}:
                os.remove(fp)
                removed += 1
                print('DEL  ' + fp.replace(os.sep, '/'))
        if d != SRC and not os.listdir(d):
            os.rmdir(d)

    def conv(n: dict) -> dict:
        out = {'name': n['name'], 'className': n['className']}
        kids = [conv(c) for c in n.get('children') or []]
        if kids:
            out['children'] = kids
        if n.get('studioPath') and n['className'] in SCRIPT_CLASSES:
            out['filePaths'] = [file_path(n['studioPath'], n['className']).replace(os.sep, '/')]
        return out

    t = first['tree']
    sm = {'name': 'Deadzone', 'className': 'DataModel', 'children': [
        {'name': 'ReplicatedStorage', 'className': 'ReplicatedStorage', 'children': [conv(t['Shared']['node'])]},
        {'name': 'ServerScriptService', 'className': 'ServerScriptService', 'children': [conv(t['Server']['node'])]},
        {'name': 'ServerStorage', 'className': 'ServerStorage', 'children': [conv(t['Tests']['node'])]},
        {'name': 'StarterPlayer', 'className': 'StarterPlayer', 'children': [
            {'name': 'StarterPlayerScripts', 'className': 'StarterPlayerScripts', 'children': [conv(t['Client']['node'])]}]},
    ]}
    with open(os.path.join('mirror', 'sourcemap.json'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(sm, indent=1, ensure_ascii=False) + '\n')

    studio_scripts = sum(1 for e in first['manifest'] if e['className'] in SCRIPT_CLASSES)
    studio_text = len(first['manifest']) - studio_scripts
    mirror_scripts = mirror_text = 0
    for d, _, files in os.walk(SRC):
        for name in files:
            if name.endswith('.luau'):
                mirror_scripts += 1
            elif name.endswith('.txt'):
                mirror_text += 1
    count_ok = (studio_scripts == mirror_scripts == first['dataModelScripts'] == first['scriptsUnderRoots']
                and studio_text == mirror_text)
    print('written %d · deleted %d · sourcemap regenerated' % (written, removed))
    print('scripts: DataModel %d · under roots %d · mirror %d · StringValues: studio %d · mirror %d · %s' % (
        first['dataModelScripts'], first['scriptsUnderRoots'], mirror_scripts, studio_text, mirror_text,
        'MATCH' if count_ok else 'COUNT MISMATCH'))
    ok &= count_ok
    print('ALL OK' if ok else 'FAILED')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

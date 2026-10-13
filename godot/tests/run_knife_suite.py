"""Serial knife/menu verification with exact-byte settings protection.
Usage: python godot/tests/run_knife_suite.py --godot <console.exe> [--refresh-evidence]
The in-engine guard protects standalone scripts; this outer guard also restores
on native crashes, subprocess timeouts, assertion failures, and Ctrl-C.
"""
import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def file_bytes(path):
    return path.read_bytes() if path.exists() else None


def restore(path, data):
    if file_bytes(path) == data:
        return
    if data is None:
        path.unlink(missing_ok=True)
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


@contextmanager
def preserve_settings(path):
    snapshot = file_bytes(path)
    try:
        yield snapshot
    finally:
        restore(path, snapshot)


def sha256(data):
    return hashlib.sha256(data).hexdigest() if data is not None else 'ABSENT'


def settings_path():
    if 'APPDATA' not in os.environ:
        raise RuntimeError('Specify --settings-file outside Windows')
    project = (ROOT / 'godot/project.godot').read_text(encoding='utf-8')
    name = next(json.loads(line.split('=', 1)[1]) for line in project.splitlines() if line.startswith('config/name='))
    return Path(os.environ['APPDATA']) / 'Godot/app_userdata' / name / 'cs16_settings.cfg'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--settings-file', type=Path)
    parser.add_argument('--refresh-evidence', action='store_true')
    args = parser.parse_args()
    cfg = args.settings_file or settings_path()
    logs = ROOT / '.orchestration/knife-evidence/followup'
    logs.mkdir(parents=True, exist_ok=True)
    results = []

    def run(name, flags, expected_code=0, expected_assert=False):
        command = [args.godot, '--path', str(ROOT / 'godot'), *flags]
        before = file_bytes(cfg)
        with preserve_settings(cfg):
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                    encoding='utf-8', errors='replace', timeout=150)
            output = result.stdout + result.stderr
            (logs / (name + '.log')).write_text('COMMAND: ' + subprocess.list2cmdline(command) + '\n' + output, encoding='utf-8')
            intact = file_bytes(cfg) == before
        bad_diagnostics = any(line.startswith(('ERROR:', 'SCRIPT ERROR:', 'WARNING:')) for line in output.splitlines())
        ok = result.returncode == expected_code and intact
        if expected_assert:
            ok = ok and 'EXPECTED_SETTINGS_GUARD_ASSERT' in output and 'Test timed out' in output
        else:
            ok = ok and not bad_diagnostics
        print(f'{name}: {"PASS" if ok else "FAIL"}; exit={result.returncode}; settings_unchanged={intact}')
        for line in output.splitlines():
            if any(marker in line for marker in ('PASS', 'RESULT:', 'verified!', 'tests passed!')):
                print('  ' + line)
        results.append({'name': name, 'command': command, 'exit': result.returncode,
                        'settings_unchanged': intact, 'pass': ok})
        if not ok:
            raise RuntimeError(f'{name} failed; see {logs / (name + ".log")}')

    before = file_bytes(cfg)
    print('SETTINGS SHA256 BEFORE:', sha256(before))
    try:
        with preserve_settings(cfg):
            run('import', ['--headless', '--editor', '--import'])
            # Exercise real mutation for both exact non-canonical bytes and absence.
            # The outer finally restores the user's original bytes even if the guard fails.
            with preserve_settings(cfg):
                for existed in (True, False):
                    fixture = b'; preserve comments and CRLF exactly\r\n[knife]\r\ncurrent_knife="knife_default"\r\n' if existed else None
                    for mode in ('success', 'failure', 'assert'):
                        restore(cfg, fixture)
                        run(f'guard_{"existing" if existed else "absent"}_{mode}',
                            ['--headless', '--script', 'res://tests/test_settings_snapshot_probe.gd', '--', mode],
                            expected_code=0 if mode == 'success' else 1, expected_assert=mode == 'assert')
            for test in ('test_knife_inspect', 'test_knife_catalog', 'test_knife_selection',
                         'test_menu_and_settings', 'test_pause_menu', 'test_game_flow', 'pmove_test'):
                renderer = ['--rendering-method', 'gl_compatibility'] if test in ('test_pause_menu', 'test_game_flow') else ['--headless']
                run(test, renderer + ['--script', f'res://tests/{test}.gd'])
            if args.refresh_evidence:
                for test in ('render_knife_catalog', 'capture_knife_gameplay'):
                    run(test, ['--rendering-method', 'gl_compatibility', '--script', f'res://tests/{test}.gd'])
    finally:
        after = file_bytes(cfg)
        print('SETTINGS SHA256 AFTER: ', sha256(after))
        print('SETTINGS EXACT BYTES UNCHANGED:', before == after)
        (logs / 'results.json').write_text(json.dumps({'before_sha256': sha256(before), 'after_sha256': sha256(after),
                                                     'unchanged': before == after, 'results': results}, indent=2) + '\n', encoding='utf-8')
    print('KNIFE/MENU SUITE: PASS; settings restored on normal, failure and assert exits (existing and absent file)')


if __name__ == '__main__':
    main()

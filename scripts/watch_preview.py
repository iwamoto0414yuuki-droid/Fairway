"""Capture the DEBUG-only preview on an actual watchOS simulator."""
import json
import subprocess
import time
from pathlib import Path


def run(*args):
    return subprocess.check_output(args, text=True)


devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '-j'))['devices']
watches = [d for runtime, group in devices.items() if 'watchOS' in runtime for d in group if d.get('isAvailable')]
if not watches:
    raise SystemExit('No watchOS simulator installed; do not claim a Watch preview')
watches.sort(key=lambda d: ('41mm' not in d['name'], '40mm' not in d['name'], d['name']))
watch = watches[0]
print('Watch preview device:', watch['name'], flush=True)
run('xcrun', 'simctl', 'bootstatus', watch['udid'], '-b')
app = 'build/simulator/Build/Products/Debug-watchsimulator/FairwayWatch.app'
run('xcrun', 'simctl', 'install', watch['udid'], app)
for mode, filename in [('score', 'native-watch.png'), ('summary', 'native-watch-summary.png'), ('clubs', 'native-watch-clubs.png')]:
    subprocess.run(['xcrun', 'simctl', 'terminate', watch['udid'], 'local.fairway.score.watchkitapp'], capture_output=True)
    run('xcrun', 'simctl', 'launch', watch['udid'], 'local.fairway.score.watchkitapp', '--preview-' + mode)
    time.sleep(6)
    run('xcrun', 'simctl', 'io', watch['udid'], 'screenshot', 'build/' + filename)
Path('build/watch-preview-device.json').write_text(json.dumps(watch, indent=2))

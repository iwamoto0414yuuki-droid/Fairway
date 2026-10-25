"""Read public Anisette client metadata, without Apple login or provisioning.

Only GET /v3/client_info is requested. No credentials, OTP headers, ADI state,
pairing records or device identifiers are read or sent.
"""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
from pathlib import Path
import urllib.error
import urllib.request

SERVERS = (
    'https://ani.sidestore.io',
    'https://new.ani.sidestore.io',
    'https://ani.jkcoxson.com',
    'https://ani.iloader.app',
)
OLD_CLIENT = '<Mac15,7> <macOS;27.0;26A5378j> <com.apple.AuthKit/1 (com.apple.akd/1.0)>'
OLD_UA = 'akd/1.0 CFNetwork/808.1.4'


def inspect(server):
    result = {'server': server, 'endpoint': '/v3/client_info'}
    try:
        request = urllib.request.Request(server + '/v3/client_info',
                                         headers={'User-Agent': 'Fairway-PublicMetadataCheck/1'})
        with urllib.request.urlopen(request, timeout=12) as response:
            result['http_status'] = response.status
            data = json.loads(response.read(16385))
        pair = {key: data[key] for key in ('client_info', 'user_agent')}
        if any(not isinstance(value, str) or not value or len(value) > 1024
               or '\r' in value or '\n' in value for value in pair.values()):
            raise ValueError('Invalid public metadata')
        result.update(pair)
        result['old_watch_build_pair_matches'] = pair == {
            'client_info': OLD_CLIENT, 'user_agent': OLD_UA}
    except urllib.error.HTTPError as error:
        result.update(http_status=error.code, error='HTTPError')
    except Exception as error:
        result['error'] = type(error).__name__
    return result


def main():
    with ThreadPoolExecutor(max_workers=len(SERVERS)) as pool:
        results = list(pool.map(inspect, SERVERS))
    report = {'checked_at_utc': datetime.now(timezone.utc).isoformat(),
              'apple_login_attempted': False, 'account_data_accessed': False,
              'note': 'Current public metadata does not establish server state during the earlier failures.',
              'results': results}
    destination = Path(__file__).resolve().parents[2] / 'build/iloader-auth-audit'
    destination.mkdir(parents=True, exist_ok=True)
    (destination / 'public-metadata.json').write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()

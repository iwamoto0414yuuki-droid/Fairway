# Read-only investigation of the older Watch iloader authentication

Run `python public_anisette_check.py` with Python 3.10 or later. Only the Python
standard library is needed. The script queries four public `/v3/client_info`
endpoints and writes `build/iloader-auth-audit/public-metadata.json`.

It never logs in to Apple, requests OTP headers, provisions Anisette, reads
stored account data, modifies certificates or installs an application. A public
metadata response alone cannot prove that an Apple Account login will work.

See `docs/ILOADER_AUTH_INVESTIGATION.md` for the findings and limitations. The
dated example JSON contains public server metadata only. Do not add account
tokens, ADI blobs, passwords, pairing records or real device identifiers here.

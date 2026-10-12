#!/bin/sh
# Fails when any file under Sources/ names a network API or a URL literal. The only exemption is a line that carries
# the marker `// allow-url`; comments are not exempt. Run by hand or in CI: scripts/check-no-network.sh
set -eu
cd "$(dirname "$0")/.."

fail=0
bad() { printf 'no-network: %s\n' "$1" >&2; fail=1; }

# A missing Sources/ would otherwise pass silently, which is the failure this gate exists to catch.
[ -d Sources ] || bad "Sources/ is missing, so nothing was checked"

# Substring match on purpose: comments and longer identifiers fail too.
banned='URLSession|NWConnection|NWListener|CFNetwork|CFSocket|socket\(|getaddrinfo|WKWebView|https?://'
hits="$(grep -rEn "$banned" Sources | grep -vF '// allow-url' || true)"
[ -z "$hits" ] || bad "forbidden network reference (only a line marked '// allow-url' is exempt):
$hits"

[ "$fail" -eq 0 ] && printf 'no-network: ok\n'
exit "$fail"

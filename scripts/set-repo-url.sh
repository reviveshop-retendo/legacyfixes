#!/usr/bin/env bash
#
# Point repo.conf at your GitHub Pages URL.
# Usage: ./scripts/set-repo-url.sh https://yourname.github.io/legacyfixes
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
URL="${1:-}"

if [[ -z "$URL" ]]; then
    echo "usage: $0 https://yourname.github.io/your-repo" >&2
    exit 1
fi

URL="${URL%/}"
sed -i.bak "s|^REPO_URL=.*|REPO_URL=\"$URL\"|" "$ROOT/repo.conf"
rm -f "$ROOT/repo.conf.bak"

echo "REPO_URL is now $URL"
echo "The web page reads the source URL from the browser address bar, so"
echo "no HTML changes are needed."

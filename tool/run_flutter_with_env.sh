#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$project_root/.env"

if [[ ! -f "$env_file" ]]; then
  echo "프로젝트 루트에 .env 파일이 없습니다." >&2
  exit 1
fi

naver_map_client_id="$(python3 - "$env_file" <<'PY'
from pathlib import Path
import sys

for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    key, separator, value = line.partition("=")
    if separator and key.strip() == "NAVER_MAP_CLIENT_ID":
        value = value.split("#", 1)[0].strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        print(value)
        break
PY
)"

if [[ -z "$naver_map_client_id" ]]; then
  echo ".env에 NAVER_MAP_CLIENT_ID가 없거나 비어 있습니다." >&2
  exit 1
fi

cd "$project_root"
exec flutter run --dart-define="NAVER_MAP_CLIENT_ID=$naver_map_client_id" "$@"

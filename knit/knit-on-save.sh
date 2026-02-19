#!/usr/bin/env bash
set -euo pipefail

buffer_path="${1:-}"
tmp_input="$(mktemp)"
trap 'rm -f "$tmp_input"' EXIT

cat >"$tmp_input"

passthrough_and_exit() {
  cat "$tmp_input"
  exit 0
}

if [[ -z "$buffer_path" ]]; then
  passthrough_and_exit
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd "$script_dir/.." && pwd -P)"

# Build an absolute path for matching against this project.
if ! buffer_abs="$(cd "$(dirname "$buffer_path")" 2>/dev/null && pwd -P)/$(basename "$buffer_path")"; then
  passthrough_and_exit
fi

rmd_prefix="$project_root/Rmd Files/"
if [[ "$buffer_abs" != "$rmd_prefix"* || "$buffer_abs" != *.Rmd ]]; then
  passthrough_and_exit
fi

mkdir -p "$project_root/.zed"
log_file="$project_root/.zed/knit-on-save.log"
lock_file="$project_root/.zed/.knit-on-save.lock"

# Ensure the latest buffer content is on disk before rendering.
cp "$tmp_input" "$buffer_abs"

cd "$project_root"
if command -v flock >/dev/null 2>&1; then
  flock "$lock_file" \
    Rscript -e 'source("knit/knit.R"); knit(commandArgs(trailingOnly = TRUE)[1])' "$buffer_abs" \
    >>"$log_file" 2>&1 || true
else
  Rscript -e 'source("knit/knit.R"); knit(commandArgs(trailingOnly = TRUE)[1])' "$buffer_abs" \
    >>"$log_file" 2>&1 || true
fi

# Pass the buffer through unchanged so save behavior remains normal.
passthrough_and_exit

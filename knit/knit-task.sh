#!/usr/bin/env bash
set -euo pipefail

target_path="${1:-${ZED_FILE:-}}"
if [[ -z "$target_path" ]]; then
  exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd "$script_dir/.." && pwd -P)"

if ! target_abs="$(cd "$(dirname "$target_path")" 2>/dev/null && pwd -P)/$(basename "$target_path")"; then
  exit 0
fi

rmd_prefix="$project_root/Rmd Files/"
if [[ "$target_abs" != "$rmd_prefix"* || "$target_abs" != *.Rmd ]]; then
  exit 0
fi

lock_file="${XDG_RUNTIME_DIR:-/tmp}/rmd-template-knit.lock"
exec 9>"$lock_file"
if ! flock -n 9; then
  # Another render is already running; skip to keep save path responsive.
  exit 0
fi

output_log="$(mktemp /tmp/rmd-knit-output.XXXXXX.log)"
cleanup() {
  rm -f "$output_log"
}
trap cleanup EXIT

cd "$project_root"
if Rscript -e 'source("knit/knit.R"); knit(commandArgs(trailingOnly = TRUE)[1])' "$target_abs" >"$output_log" 2>&1; then
  exit 0
else
  status=$?
fi

timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
report_file="$(mktemp /tmp/rmd-knit-failure.XXXXXX.log)"
{
  printf '[%s] Knit failed\n' "$timestamp"
  printf 'Input: %s\n' "$target_abs"
  printf 'Exit code: %s\n\n' "$status"
  cat "$output_log"
} >"$report_file"

launched=0
if command -v hyprctl >/dev/null 2>&1 && command -v ghostty >/dev/null 2>&1; then
  viewer_script="$(mktemp /tmp/rmd-knit-viewer.XXXXXX.sh)"
  cat >"$viewer_script" <<VIEWER
#!/usr/bin/env bash
cat "${report_file}"
echo
read -r -p "Press Enter to close..." _
rm -f "${report_file}" "${viewer_script}"
VIEWER
  chmod +x "$viewer_script"

  if hyprctl dispatch exec "[float;no_initial_focus;center;size 1040 680] ghostty --font-size=10 --confirm-close-surface=false -e ${viewer_script}" >/dev/null 2>&1; then
    launched=1
  fi
fi

if [[ "$launched" -eq 0 ]]; then
  echo "Knit failed for $target_abs" >&2
  cat "$report_file" >&2
fi

exit "$status"

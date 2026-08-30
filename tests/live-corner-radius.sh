#!/usr/bin/env bash
set -euo pipefail

original=$(hyprctl getoption decoration:rounding -j | jq -r .int)
target=0
if [[ "$original" == 0 ]]; then target=13; fi

restore_rounding() {
  hyprctl reload >/dev/null
  for _ in $(seq 1 20); do
    hyprctl eval "hl.config({ decoration = { rounding = $original, }, })" >/dev/null
    sleep 0.03
  done
  sleep 0.5
}
trap restore_rounding EXIT

before=$(omarchy-shell shell call gshulga.dashboard status x | jq -r .cornerRadius)
hyprctl reload >/dev/null
for _ in $(seq 1 20); do
  hyprctl eval "hl.config({ decoration = { rounding = $target, }, })" >/dev/null
  sleep 0.03
done
sleep 0.5
effective=$(hyprctl getoption decoration:rounding -j | jq -r .int)
after=$(omarchy-shell shell call gshulga.dashboard status x | jq -r .cornerRadius)

printf 'configreloaded: system-before=%s dashboard-before=%s system-target=%s system-after=%s dashboard-after=%s\n' \
  "$original" "$before" "$target" "$effective" "$after"
test "$effective" = "$target"
test "$after" = "$target"

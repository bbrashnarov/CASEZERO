#!/usr/bin/env bash
# Real process-kill test: SIGKILL the Godot process after N committed steps (and during a
# continuous write stress), then boot again and check what the save restored.
# Usage: tools/qa/kill_test.sh [godot-binary]   -> writes build/kill_test_report.txt
set -u
GODOT=${1:-godot}
cd "$(dirname "$0")/../.."
USERDIR="$HOME/.local/share/godot/app_userdata/CASE ZERO/qa_kill"
OUT=build/kill_test_report.txt
mkdir -p build
: > "$OUT"
fail=0

run_until() { # $1 marker, rest: args
  local marker=$1; shift
  local log; log=$(mktemp)
  "$GODOT" --headless --path . -s res://tools/qa/kill_driver.gd -- "$@" > "$log" 2>&1 &
  local pid=$!
  for _ in $(seq 1 600); do
    if grep -q "$marker" "$log"; then break; fi
    if ! kill -0 $pid 2>/dev/null; then break; fi
    sleep 0.1
  done
  kill -9 $pid 2>/dev/null; wait $pid 2>/dev/null
  grep -E "STEP|STRESS|ERROR" "$log" | tail -3
  rm -f "$log"
}

verify() {
  "$GODOT" --headless --path . -s res://tools/qa/kill_driver.gd -- --verify 2>&1 | grep '^VERIFY ' | sed 's/^VERIFY //'
}

check() { # $1 label, $2 json, $3 python condition on d
  if python3 -c "import json,sys; d=json.loads(sys.argv[1]); sys.exit(0 if ($3) else 1)" "$2"; then
    echo "PASS  $1  $2" | tee -a "$OUT"
  else
    echo "FAIL  $1  $2" | tee -a "$OUT"; fail=1
  fi
}

declare -A EXPECT=(
  [1]="d['route']=='G_BOARD' and d['evidence']==[] and d['completed']['C01']==False"
  [2]="d['evidence']==['EV_C01_RAIN']"
  [3]="d['evidence']==['EV_C01_RAIN','EV_C01_DRY_FLOOR']"
  [4]="d['hint_level']==1 and len(d['evidence'])==2"
  [5]="d['questions'].get('C01_Q1')==True"
  [6]="d['evidence']==['EV_C01_RAIN','EV_C01_DRY_FLOOR','EV_C01_ADMISSION']"
  [7]="d['completed']['C01']==True and d['xp']==100"
)

for n in 1 2 3 4 5 6 7; do
  rm -rf "$USERDIR"
  run_until READY_FOR_KILL --steps=$n >/dev/null
  j=$(verify)
  check "kill -9 after step $n" "$j" "d['load_status'] in ('LOADED',) and ${EXPECT[$n]}"
done

# Second restart after a solve must not grant XP again.
j=$(verify)
check "restart again after solve keeps xp 100" "$j" "d['xp']==100 and d['completed']['C01']==True"

for k in 1 2 3 4 5; do
  rm -rf "$USERDIR"
  run_until "STRESS $((k*100))" --stress >/dev/null
  j=$(verify)
  check "kill -9 during write stress #$k (~$((k*100)) writes)" "$j" "d['load_status'] in ('LOADED','RECOVERED_FROM_BACKUP') and d['boot_status'] in ('OK','FRESH')"
done
rm -rf "$USERDIR"
echo "exit=$fail" >> "$OUT"
exit $fail

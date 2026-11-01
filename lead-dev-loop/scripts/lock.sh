#!/bin/sh
# One writer at a time on a shared environment (a dev server, a staging database).
#
#   lock.sh take "<who>: <what>"    # exits 1, printing the holder, if already held
#   lock.sh wait "<who>: <what>"    # blocks until free, then takes it (poll every 30 s)
#   lock.sh show                    # prints the holder, or "free"
#   lock.sh release                 # removes it
#
# Take it only to write: waiting on a slow job is not writing, so release it meanwhile.
# The lock file lives at $SHARED_ENV_LOCK (default ~/.cache/lead-dev-loop/ENV-LOCK).
L=${SHARED_ENV_LOCK:-$HOME/.cache/lead-dev-loop/ENV-LOCK}
mkdir -p "$(dirname "$L")"
case "$1" in
  take)
    # set -C: the redirect fails if the file exists, so taking is atomic.
    if ( set -C; printf '%s %s\n' "$(date -u +%FT%TZ)" "${2:?say who and what}" > "$L" ) 2>/dev/null; then
      echo "taken"
    else
      echo "held: $(cat "$L")"; exit 1
    fi ;;
  wait)
    until ( set -C; printf '%s %s\n' "$(date -u +%FT%TZ)" "${2:?say who and what}" > "$L" ) 2>/dev/null; do
      sleep 30
    done
    echo "taken" ;;
  show) if [ -f "$L" ]; then cat "$L"; else echo free; fi ;;
  release) rm -f "$L"; echo released ;;
  *) echo "usage: lock.sh take|wait|show|release [who: what]"; exit 2 ;;
esac

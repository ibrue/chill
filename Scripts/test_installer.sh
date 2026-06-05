#!/bin/bash
#
# Sandbox test harness for the Chill installer scripts.
#
# macOS has no real container for running a .pkg, so instead of mutating the
# host we run the *actual* preinstall/postinstall scripts with every system
# command they touch (launchctl, chown, chmod, pkill, pgrep, id, open) replaced
# by shims on PATH. The shims log every call and return whatever exit code the
# current scenario dictates, letting us reproduce the launchd failure modes that
# make a real install abort - without loading daemons or chowning real files.
#
# It checks two things:
#   1. The shipping scripts exit 0 across every realistic install scenario
#      (clean install, reinstall, bootstrap returns "5: Input/output error",
#      and the daemon genuinely failing to load).
#   2. The *previous* (buggy) postinstall is correctly detected as failing, so
#      we know the harness actually exercises the failure and the fix matters.
#
# Usage:  Scripts/test_installer.sh
# Exit:   0 if all assertions pass, 1 otherwise.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${SCRIPTS_DIR:-$REPO_ROOT/Scripts/installer-scripts}"
PREINSTALL="${PREINSTALL:-$SCRIPTS_DIR/preinstall}"
POSTINSTALL="${POSTINSTALL:-$SCRIPTS_DIR/postinstall}"

PASS=0
FAIL=0
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

green() { printf '\033[32m%s\033[0m' "$1"; }
red()   { printf '\033[31m%s\033[0m' "$1"; }

# ---------------------------------------------------------------------------
# Build the shim bin dir. Every shimmed command appends "<name> <args>" to
# $SHIM_LOG and exits with a per-subcommand code read from the environment, so a
# scenario is just a set of SHIM_*_RC variables.
# ---------------------------------------------------------------------------
SHIM_BIN="$TMP_ROOT/bin"
mkdir -p "$SHIM_BIN"

cat > "$SHIM_BIN/launchctl" <<'SHIM'
#!/bin/bash
echo "launchctl $*" >> "$SHIM_LOG"
case "$1" in
    bootstrap) exit "${SHIM_BOOTSTRAP_RC:-0}" ;;
    bootout)   exit "${SHIM_BOOTOUT_RC:-0}" ;;
    load)      exit "${SHIM_LOAD_RC:-0}" ;;
    unload)    exit "${SHIM_UNLOAD_RC:-0}" ;;
    print)     exit "${SHIM_PRINT_RC:-0}" ;;
    enable|kickstart|asuser) exit 0 ;;
    *)         exit 0 ;;
esac
SHIM

# chown/chmod/pkill/pgrep/id/open: log and return a controllable (default 0) code
# without touching the real system.
for cmd in chown chmod pkill open; do
    cat > "$SHIM_BIN/$cmd" <<SHIM
#!/bin/bash
echo "$cmd \$*" >> "\$SHIM_LOG"
exit \${SHIM_${cmd}_RC:-0}
SHIM
done

# pgrep: default "not found" (rc 1) so the old preinstall's pkill branch is
# skipped unless a scenario says a process is running.
cat > "$SHIM_BIN/pgrep" <<'SHIM'
#!/bin/bash
echo "pgrep $*" >> "$SHIM_LOG"
exit "${SHIM_PGREP_RC:-1}"
SHIM

# id: deterministic uid so the "open app for console user" branch is exercised
# regardless of who is actually logged in on the test machine.
cat > "$SHIM_BIN/id" <<'SHIM'
#!/bin/bash
echo "id $*" >> "$SHIM_LOG"
echo "501"
exit 0
SHIM

chmod +x "$SHIM_BIN"/*

# ---------------------------------------------------------------------------
# run_script <script> <expect: ok|fail> <label>  [SHIM_VAR=val ...]
# Runs one installer script in the sandbox and records the assertion result.
# ---------------------------------------------------------------------------
run_script() {
    local script="$1" expect="$2" label="$3"; shift 3
    local logfile="$TMP_ROOT/out.log"
    SHIM_LOG="$TMP_ROOT/calls.log"; : > "$SHIM_LOG"

    # Run with shims first on PATH and scenario codes in the environment.
    env -i \
        PATH="$SHIM_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
        SHIM_LOG="$SHIM_LOG" \
        "$@" \
        /bin/bash "$script" /pkg /target / /Volumes/Macintosh\ HD \
        >"$logfile" 2>&1
    local rc=$?

    local outcome="ok"; [ "$rc" -ne 0 ] && outcome="fail"
    if [ "$outcome" = "$expect" ]; then
        printf '  %s  %-46s (exit %d)\n' "$(green PASS)" "$label" "$rc"
        PASS=$((PASS + 1))
    else
        printf '  %s  %-46s (exit %d, expected %s)\n' "$(red FAIL)" "$label" "$rc" "$expect"
        echo "        --- script output ---"
        sed 's/^/        /' "$logfile"
        echo "        --- launchctl/shim calls ---"
        sed 's/^/        /' "$SHIM_LOG"
        FAIL=$((FAIL + 1))
    fi
}

# A self-contained copy of the PREVIOUS (buggy) postinstall, used only to prove
# the harness detects the failure the shipping script fixes.
BUGGY_POSTINSTALL="$TMP_ROOT/postinstall.buggy"
cat > "$BUGGY_POSTINSTALL" <<'EOF'
#!/bin/bash
set -e
APP_PATH="/Applications/Chill.app"
HELPER_PATH="/Library/PrivilegedHelperTools/com.chill.helper"
HELPER_PLIST="/Library/LaunchDaemons/com.chill.helper.plist"
HELPER_LABEL="com.chill.helper"
chown -R root:wheel "$APP_PATH"
chown root:wheel "$HELPER_PATH" "$HELPER_PLIST"
chmod 544 "$HELPER_PATH"
chmod 644 "$HELPER_PLIST"
if ! launchctl bootstrap system "$HELPER_PLIST"; then
    echo "launchctl bootstrap failed; falling back to legacy load" >&2
    launchctl load -w "$HELPER_PLIST"
fi
launchctl enable "system/$HELPER_LABEL" 2>/dev/null || true
launchctl kickstart -k "system/$HELPER_LABEL" 2>/dev/null || true
exit 0
EOF

echo "Chill installer sandbox harness"
echo "  scripts dir: $SCRIPTS_DIR"
echo

# --- Static checks -----------------------------------------------------------
echo "Syntax (bash -n):"
for s in "$PREINSTALL" "$POSTINSTALL"; do
    if bash -n "$s" 2>/dev/null; then
        printf '  %s  %s\n' "$(green PASS)" "$(basename "$s")"; PASS=$((PASS + 1))
    else
        printf '  %s  %s\n' "$(red FAIL)" "$(basename "$s")"; FAIL=$((FAIL + 1))
    fi
done
echo

# --- Shipping scripts must survive every scenario ----------------------------
echo "Shipping scripts (must all exit 0):"
run_script "$PREINSTALL"  ok "preinstall / clean (nothing loaded)"   SHIM_PRINT_RC=1
run_script "$PREINSTALL"  ok "preinstall / reinstall (already loaded)" SHIM_PRINT_RC=0 SHIM_PGREP_RC=0
run_script "$POSTINSTALL" ok "postinstall / clean install"           SHIM_BOOTSTRAP_RC=0 SHIM_PRINT_RC=0
run_script "$POSTINSTALL" ok "postinstall / bootstrap returns 5"     SHIM_BOOTSTRAP_RC=5 SHIM_LOAD_RC=1 SHIM_PRINT_RC=0
run_script "$POSTINSTALL" ok "postinstall / reinstall"              SHIM_BOOTOUT_RC=0 SHIM_BOOTSTRAP_RC=5 SHIM_LOAD_RC=1 SHIM_PRINT_RC=0
run_script "$POSTINSTALL" ok "postinstall / daemon won't load"      SHIM_BOOTSTRAP_RC=5 SHIM_LOAD_RC=1 SHIM_PRINT_RC=1
echo

# --- The old postinstall must be caught failing ------------------------------
echo "Regression guard (old script must FAIL these):"
run_script "$BUGGY_POSTINSTALL" fail "old postinstall / bootstrap returns 5" SHIM_BOOTSTRAP_RC=5 SHIM_LOAD_RC=1 SHIM_PRINT_RC=0
run_script "$BUGGY_POSTINSTALL" fail "old postinstall / daemon won't load"   SHIM_BOOTSTRAP_RC=5 SHIM_LOAD_RC=1 SHIM_PRINT_RC=1
echo

echo "-----------------------------------------------"
printf 'Result: %s passed, %s failed\n' "$(green "$PASS")" "$([ "$FAIL" -eq 0 ] && green 0 || red "$FAIL")"
[ "$FAIL" -eq 0 ]

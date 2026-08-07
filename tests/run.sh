#!/usr/bin/env bash
# fstablint tests. Read-only; fixtures in a temp dir.
set -uo pipefail
cd "$(dirname "$0")/.."
FL="python3 fstablint.py"
pass=0; fail=0
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

assert() {   # <desc> <expect> -- <cmd...>
    local desc="$1" expect="$2"; shift 2; [[ "$1" == "--" ]] && shift
    local out; out="$("$@" 2>&1)"
    if grep -qF -- "$expect" <<<"$out"; then printf '  PASS  %s\n' "$desc"; pass=$((pass+1))
    else printf '  FAIL  %s\n        wanted: %s\n        got: %s\n' "$desc" "$expect" "$out"; fail=$((fail+1)); fi
}
refute() {   # <desc> <needle> -- <cmd...>
    local desc="$1" needle="$2"; shift 2; [[ "$1" == "--" ]] && shift
    local out; out="$("$@" 2>&1)"
    if grep -qF -- "$needle" <<<"$out"; then printf '  FAIL  %s (found %s)\n' "$desc" "$needle"; fail=$((fail+1))
    else printf '  PASS  %s\n' "$desc"; pass=$((pass+1)); fi
}
assert_exit() {  # <desc> <code> -- <cmd...>
    local desc="$1" want="$2"; shift 2; [[ "$1" == "--" ]] && shift
    "$@" >/dev/null 2>&1; local rc=$?
    if [[ "$rc" == "$want" ]]; then printf '  PASS  %s\n' "$desc"; pass=$((pass+1))
    else printf '  FAIL  %s (exit %s want %s)\n' "$desc" "$rc" "$want"; fail=$((fail+1)); fi
}

echo "== syntax =="
if python3 -c "import ast; ast.parse(open('fstablint.py').read())"; then
    echo "  PASS  fstablint.py parses"; pass=$((pass+1))
else echo "  FAIL  syntax"; fail=$((fail+1)); fi

echo "== hardening options =="
printf 'tmpfs /tmp tmpfs defaults 0 0\n' > "$T/tmp"
assert "/tmp missing hardening" "/tmp is missing" -- $FL "$T/tmp" --no-color
assert "/tmp is HIGH"           "HIGH"             -- $FL "$T/tmp" --no-color
printf 'tmpfs /dev/shm tmpfs nodev,nosuid,noexec 0 0\n' > "$T/shm"
refute "hardened /dev/shm not flagged" "is missing" -- $FL "$T/shm" --no-color

echo "== network filesystems =="
printf '192.168.1.5:/s /mnt/n nfs defaults 0 0\n' > "$T/nfs"
assert "nfs without nofail HIGH"  "hang the boot"  -- $FL "$T/nfs" --no-color
assert "nfs without _netdev"      "before the network" -- $FL "$T/nfs" --no-color
printf '192.168.1.5:/s /mnt/n nfs _netdev,nofail 0 0\n' > "$T/nfsok"
refute "safe nfs not flagged"     "hang the boot"  -- $FL "$T/nfsok" --no-color

echo "== stable identifiers, duplicates, field count =="
printf '/dev/sdb1 /data ext4 defaults 0 2\n' > "$T/dev"
assert "device name flagged"      "device order is not stable" -- $FL "$T/dev" --no-color
printf 'UUID=a /data ext4 defaults 0 2\nUUID=b /data ext4 defaults 0 2\n' > "$T/dup"
assert "duplicate mountpoint HIGH" "already defined on line 1" -- $FL "$T/dup" --no-color
printf 'UUID=a /data ext4\n' > "$T/short"
assert "too few fields is error"  "need at least 4"  -- $FL "$T/short" --no-color
printf 'UUID=a /data ext4 defaults never 9\n' > "$T/badnumeric"
assert "invalid dump value rejected" "dump field must be 0 or 1" -- $FL "$T/badnumeric" --no-color
assert "invalid fsck pass rejected" "fsck pass must be 0, 1, or 2" -- $FL "$T/badnumeric" --no-color

echo "== a clean fstab =="
printf 'UUID=root / ext4 defaults 0 1\nUUID=t /tmp ext4 nodev,nosuid,noexec 0 2\n' > "$T/clean"
assert_exit "clean fstab exits zero" 0 -- $FL "$T/clean" --no-color

echo
echo "== $pass passed, $fail failed =="
[[ $fail -eq 0 ]]

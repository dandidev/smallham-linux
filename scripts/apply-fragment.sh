#!/bin/sh
# Usage: apply-fragment.sh <fragment> <.config>
# Sets every CONFIG_ line of the fragment in .config (replacing the old value).
# Run 'make oldconfig' afterwards to resolve dependencies.
frag=$1
conf=$2
awk '
    NR == FNR {
        if ($0 ~ /^CONFIG_[A-Za-z0-9_]+=/) {
            sym = $0; sub(/=.*/, "", sym)
            want[sym] = $0; order[++n] = sym
        }
        next
    }
    {
        sym = ""
        if ($0 ~ /^CONFIG_[A-Za-z0-9_]+=/) { sym = $0; sub(/=.*/, "", sym) }
        else if ($0 ~ /^# CONFIG_[A-Za-z0-9_]+ is not set$/) { sym = $2 }
        if (sym in want) next
        print
    }
    END { for (i = 1; i <= n; i++) print want[order[i]] }
' "$frag" "$conf" > "$conf.tmp" && mv "$conf.tmp" "$conf"

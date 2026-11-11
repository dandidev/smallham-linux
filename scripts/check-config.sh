#!/bin/sh
# Usage: check-config.sh <fragment> <.config>
# Fails if an option requested in the fragment did not end up in .config
# (e.g. a misspelled symbol or an unmet dependency).
frag=$1
conf=$2
rc=0
while IFS= read -r line; do
    case "$line" in
        CONFIG_*=*)
            sym=${line%%=*}
            if ! grep -qxF "$line" "$conf"; then
                actual=$(grep -E "^($sym=|# $sym is not set)" "$conf")
                echo "check-config: $line requested, got: ${actual:-<missing>}" >&2
                rc=1
            fi
            ;;
    esac
done < "$frag"
exit $rc

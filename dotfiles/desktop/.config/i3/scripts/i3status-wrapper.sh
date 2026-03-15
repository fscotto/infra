#!/usr/bin/env bash

battery_json() {
    local total_now=0
    local total_full=0
    local overall_status=""
    local now full status bat capacity icon color

    shopt -s nullglob

    for bat in /sys/class/power_supply/BAT*; do
        [[ -d "$bat" ]] || continue

        if [[ -r "$bat/energy_now" && -r "$bat/energy_full" ]]; then
            now=$(<"$bat/energy_now")
            full=$(<"$bat/energy_full")
        elif [[ -r "$bat/charge_now" && -r "$bat/charge_full" ]]; then
            now=$(<"$bat/charge_now")
            full=$(<"$bat/charge_full")
        else
            continue
        fi

        status=$(<"$bat/status")

        (( total_now += now ))
        (( total_full += full ))

        case "$status" in
            Charging)
                overall_status="Charging"
                ;;
            Discharging)
                [[ "$overall_status" != "Charging" ]] && overall_status="Discharging"
                ;;
            Full)
                [[ -z "$overall_status" ]] && overall_status="Full"
                ;;
            *)
                [[ -z "$overall_status" ]] && overall_status="$status"
                ;;
        esac
    done

    (( total_full > 0 )) || return 1

    capacity=$(( 100 * total_now / total_full ))

    case "$overall_status" in
        Charging) icon="⚡" ;;
        Discharging) icon="🔋" ;;
        Full) icon="✔" ;;
        *) icon="?" ;;
    esac

    if (( capacity <= 15 )); then
        color="#ff5555"
    elif (( capacity <= 30 )); then
        color="#f1fa8c"
    else
        color="#ffffff"
    fi

    printf '{"full_text":"%s %s%%","name":"battery","color":"%s"}' \
        "$icon" "$capacity" "$color"
}

i3status | while IFS= read -r line; do
    case "$line" in
        '{"version":'* | '[')
            printf '%s\n' "$line"
            ;;
        ,*)
            batt="$(battery_json)"
            if [[ -n "$batt" ]]; then
                line="${line#,}"
                printf ',[%s,%s\n' "$batt" "${line#\[}"
            else
                printf '%s\n' "$line"
            fi
            ;;
        \[*)
            batt="$(battery_json)"
            if [[ -n "$batt" ]]; then
                printf '[%s,%s\n' "$batt" "${line#\[}"
            else
                printf '%s\n' "$line"
            fi
            ;;
        *)
            printf '%s\n' "$line"
            ;;
    esac
done

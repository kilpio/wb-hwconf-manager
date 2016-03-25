eval "`slot_get_vars $SLOT`"
local SLOT_TYPE=${SLOT%%[0-9]}
local SLOT_NUM=${SLOT#$SLOT_TYPE}

CONFIG_GPIO=${CONFIG_GPIO:-/etc/wb-homa-gpio.conf}

# Add GPIO to the wb-homa-gpio driver config
# Args:
# - gpio name (for mqtt)
# - gpio number (as in /sys/class/gpio)
# - direction - "input" or "output"
# These 3 args can be repeated multiple times to add many gpios at once
wb_gpio_add() {
	local JSON=$CONFIG_GPIO
	local items=()
	while [[ $# -ge 3 ]]; do
		[[ -n "$1" && -n "$2" && -n "$3" ]] || {
			die "Bad arguments"
			return 1
		}
		items+=( "{name: \"$1\", gpio: $2, direction: \"$3\"}" )
		shift 3
	done

	json_array_append ".channels" "${items[@]}"
}

# Remove GPIO from the wb-homa-gpio driver config
# Args:
# - gpio number (as in /sys/class/gpio)
wb_gpio_del() {
	local JSON=$CONFIG_GPIO
	json_array_delete ".channels" \
		". as \$chan | ([$(join ', ' "$@")] | map(. == \$chan.gpio) | any)"
}

# Get maximum number of slot with given prefix that is present in config
# Args:
# - slot id prefix
wb_max_slot_num() {
	jq '
		[ .slots[].id | select(startswith("'$1'")) ] |
		map(ltrimstr("'$1'") | tonumber) |
		max
	' "$CONFIG"
}

slot_i2c_bus_num() {
	local bus_name=$(sed -rn "s/.*(mod[0-9]+)$/\1_i2c@0/p" <<< "$SLOT")
	[[ -z "$bus_name" ]] && return 1
	grep -l "^${bus_name}$" /sys/bus/i2c/devices/i2c-*/name |  grep -Po '(?<=i2c-)(\d+)'
}

slot_i2c_bus_sysfs() {
	local num=$(slot_i2c_bus_num)
	[[ -z "$num" ]] && return 1
	echo "/sys/bus/i2c/devices/i2c-${num}"
}

# Restarts given service if $NO_RESTART_SERVICE is not set.
# Args:
# - service name (from /etc/init.d/)
service_restart() {
	[[ -z "$NO_RESTART_SERVICE" ]] && service "$1" restart
}

# Restarts given service if $NO_RESTART_SERVICE is not set,
# and also deletes retained MQTT messages with supplied topic pattern.
# Args
# - service name (from /etc/init.d/)
# - MQTT topic to delete
service_restart_delete_retained() {
	[[ -z "$NO_RESTART_SERVICE" ]] && {
		service "$1" stop
		mqtt-delete-retained "$2"
		service "$1" start
	}
}

source "$DATADIR/modules/utils.sh"

AIDV_CHIPS=3
AIDV_CHAN_PER_CHIP=4
AIDV_CHANNEL_NUM=$((AIDV_CHIPS * AIDV_CHAN_PER_CHIP))
ADS_ADDR=72

local AIDV_JSON="/etc/wb-homa-adc.conf"

dec_to_hex() {
	printf '%x\n' $1
}

schedule_service_restart() {
	hook_once_after_config_change "service_restart_delete_retained wb-homa-adc /devices/wb-adc/#"
}

remove_channels() {
	local JSON=${AIDV_JSON}

	for ((chip = 0; chip < AIDV_CHIPS; chip++)); do
		json_array_delete ".iio_channels" \
			". as \$chan | ([\"`get_iio_match $chip`\"] | map(. == \$chan.match_iio) | any)"
	done
}

get_iio_match() {
	local chip=$1
	echo "${SLOT_I2C_DEVICE_MATCH}/*/*-00`dec_to_hex $((ADS_ADDR + chip))`"
}

hook_module_add() {
	remove_channels

	local items=()
	local chan mul max_voltage

	# Single-ended channels
	for ((chip = 0; chip < AIDV_CHIPS; chip++)); do
		for ((chip_chan = 0; chip_chan < AIDV_CHAN_PER_CHIP; chip_chan++)); do
			local chan=$((chip * 4 + chip_chan))
			local chan_mode="$(config_module_option ".channels[$chan].mode // \"voltage\"")"
			local scale mqtt_type
			case ${chan_mode} in
				"voltage")
					scale=2
					voltage_multiplier=1
					mqtt_type="voltage"
					;;
				"current_20ma")
					scale=1
					voltage_multiplier=0.01
					mqtt_type="current"
					;;
				*)
					continue;
					;;
			esac

			items+=( "{channel_number: \"voltage${chip_chan}\",
					   id: \"EXT1_A$((chan + 1))\",
					   averaging_window: 1,
					   decimal_places: 5,
					   max_voltage: 4.5,
					   scale: $scale,
					   match_iio: \"`get_iio_match $chip`\",
					   mqtt_type: \"${mqtt_type}\",
					   voltage_multiplier: ${voltage_multiplier}  }" )
		done
	done

	# Differential channels
	for ((chip = 0; chip < AIDV_CHIPS; chip++)); do
		for ((pair = 0; pair < 2; pair++)); do
			local chan0=$((chip * 4 + pair * 2))
			local chan1=$((chan0 + 1))


			local chan0_mode="$(config_module_option ".channels[$chan0].mode // \"voltage\"")"
			local chan1_mode="$(config_module_option ".channels[$chan1].mode // \"voltage\"")"

			if [[ "$chan0_mode" == "$chan1_mode" ]]; then
				local voltage_multiplier
				case "$chan0_mode" in
					"voltage")
						voltage_multiplier=1
						scale=0.5
						;;
					"voltage_pm50")
						voltage_multiplier=21.26
						scale=2
						;;
					*)
						continue;
						;;
				esac

				items+=( "{channel_number: \"voltage$((pair * 2))-voltage$((pair * 2 + 1))\",
						   id: \"EXT1_A$((chan0 + 1))_A$((chan1 + 1))\",
						   averaging_window: 1,
						   decimal_places: 3,
						   max_voltage: 10,
						   scale: ${scale},
						   match_iio: \"`get_iio_match $chip`\",
						   voltage_multiplier: ${voltage_multiplier}  }" )
			fi
		done
	done

	local JSON=${AIDV_JSON}
	json_array_append ".iio_channels" "${items[@]}"

	schedule_service_restart
}

hook_module_del() {
	remove_channels
	schedule_service_restart
}

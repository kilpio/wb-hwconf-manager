source "$DATADIR/modules/utils.sh"
local CONFIG_DAC=${CONFIG_DAC:-/etc/wb-mqtt-dac.conf}

hook_module_add() {
    local IIO_BUS_NUM=`ls -d /sys/devices/platform/${SLOT_ALIAS}_i2c@0/*/*/iio:device* | grep -Po '(?<=iio:device)(\d+)'`

    local JSON=$CONFIG_DAC
    local items=()
    local chan
    for chan in 0 1; do
        items+=( "{
            id: \"MOD${SLOT_NUM}_O$((chan+1))\",
            iio_device: ${IIO_BUS_NUM},
            iio_channel: $chan,
            max_value_mv: 10000,
            multiplier: 3.75
        }" )
        shift 3
    done
    json_array_append ".channels" "${items[@]}"

    hook_once_after_config_change "service_restart_delete_retained wb-rules /devices/wb-dac/#"
}


hook_module_del() {
    local JSON=$CONFIG_DAC
    json_array_delete ".channels" \
        ". as \$chan | ([\"MOD${SLOT_NUM}_O1\", \"MOD${SLOT_NUM}_O2\"] | map(. == \$chan.id) | any)"
    hook_once_after_config_change "service_restart_delete_retained wb-rules /devices/wb-dac/#"
}
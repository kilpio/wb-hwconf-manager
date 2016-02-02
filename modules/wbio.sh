source "$DATADIR/modules/utils.sh"

case "$MODULE" in
	*-di-*)
		GPIO_DIR=input
		;;
	*-do-*|*-dio-*)
		GPIO_DIR=output
		;;
esac

hook_module_add() {
	# Add WBIO_COUNT gpios with names and directions specified
	# in WBIO_NAME and WBIO_DIR arrays
	local items=()
	for ((i = 0; i < WBIO_COUNT; i++)); do
		items+=( \
			"EXT${SLOT_NUM}_${WBIO_GPIO_PREFIX}$[i+1]" \
			$[GPIO_BASE+i] \
			"$GPIO_DIR" \
		)
	done
	wb_gpio_add "${items[@]}"

	# If we are just used last available slot, add extra one for daisy-chaining
	[[ `wb_max_slot_num "$SLOT_TYPE"` == "$SLOT_NUM" &&
		"$SLOT_NUM" -lt 8 ]] &&
		config_slot_add \
			"${SLOT_TYPE}$[SLOT_NUM+1]" \
			"${SLOT_TYPE}" \
			"External I/O module $[SLOT_NUM+1]"
}

hook_module_del() {
	# Remove all the added gpios
	wb_gpio_del $(seq $GPIO_BASE $[GPIO_BASE+WBIO_COUNT-1])

	# If we are just deleted module from last used slot and the next one is unused,
	# delete it to keep 1 or 0 empty slots at the end of chain
	[[ `wb_max_slot_num "$SLOT_TYPE"` == $[SLOT_NUM+1] &&
		-z `config_slot_module "${SLOT_TYPE}$[SLOT_NUM+1]"` ]] &&
		config_slot_del "${SLOT_TYPE}$[SLOT_NUM+1]"
}
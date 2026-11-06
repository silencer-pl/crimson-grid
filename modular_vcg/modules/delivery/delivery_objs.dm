/obj/item/delivery_contract
	name = "APDS delivery tablet"
	desc = "A simple tablet device with a fairly big, but cheap looking screen that displays multi colored text. Comes in a case complete with a small GPS receiver and a compartment with spare RFID enabled keys."
	icon = 'modular_vcg/modules/delivery/icons/apds.dmi'
	ONFLOOR_ICON_HELPER('modular_vcg/modules/delivery/icons/apds_floor.dmi')
	icon_state = "tablet"
	lefthand_file = 'modular_vcg/modules/delivery/icons/apds_inhand_left.dmi'
	righthand_file = 'modular_vcg/modules/delivery/icons/apds_inhand_right.dmi'
	inhand_icon_state = "tablet"
	var/datum/delivery_datum/delivery
	var/datum/delivery_manifest/manifest

/obj/item/delivery_contract/New(mob/user, obj/board,difficulty)
	delivery = new(user,board,difficulty)
	delivery.contract = src
	manifest = new(delivery)
	. = ..()

/obj/item/delivery_contract/attack(mob/living/M, mob/living/user)
	if(!delivery)
		to_chat(user,span_notice("Error: No delivery datum attached. This is most likely a bug."))
		return
	if(!manifest) return "no_manifest"
	if(M == user)
		if(delivery.check_owner(user) == 0)
			user.balloon_alert(user, "no reaction!")
			return
		else
			manifest.read_data(user)
			return
	if(M.client == null)
		to_chat(user,span_notice("Error: Target mob has no client. This is not a player mob."))
		return
	if(delivery.check_owner(user) == 0)
		user.balloon_alert(user, "no reaction!")
		return
	if(delivery.check_owner(user) == 1)
		if(delivery.check_owner(M) == 0)
			if(tgui_alert(user,"Do you want to add [M] to the delivery contract?","Contract add confirmation",list("Yes","No"),timeout = 10 SECONDS) == "Yes")
				delivery.add_owner(M)
				var/obj/item/vamp/keys/cargo_truck/truck_keys = new(src)
				truck_keys.delivery = delivery
				truck_keys.owner = M
				M.put_in_hands(truck_keys)
				to_chat(user, span_notice("Success! User [M] added."))
			return
		if(delivery.check_owner(M) == 1)
			if(delivery.original_owner == M)
				to_chat(user,span_notice("You are the original owner of this Contract and cannot be removed. To finish the delivery early, go back to the office issuing the contract."))
				return
			if(delivery.original_owner != user)
				to_chat(user,span_notice("Only the original owner of the contract, [delivery.original_owner] can remove people from the contract."))
				return
			else
				if(delivery.delivery_recievers.len == 0)
					to_chat(user,span_warning("This delivery is complete and should be handed in. Removing users is no longer possibe."))
					return
				if(tgui_alert(user,"Do you want to remove [M] from the delivery contract?","Contract remove confirmation",list("Yes","No"),timeout = 10 SECONDS) == "Yes")
					delivery.contract_takers.Remove(M)
					for(var/obj/item/vamp/keys/cargo_truck/truck_keys in delivery.spawned_keys)
						if(truck_keys.owner == M)
							qdel(truck_keys)
					to_chat(user, span_notice("Success! User [M] removed."))
				return

	. = ..()

/obj/item/delivery_contract/attack_self(mob/user)
	if(!delivery)
		to_chat(user,span_notice("Error: No delivery datum attached. This is most likely a bug."))
		return
	if(!manifest) return "no_manifest"
	if(delivery.check_owner(user) == 0)
		user.balloon_alert(user, "no reaction!")
		return
	else
		if(do_after(user, 2 SECONDS, src, interaction_key = "doafter_apdstablet"))
			manifest.read_data(user)
	. = ..()


/obj/item/delivery_contract/Destroy()
	. = ..()
	if(delivery) qdel(delivery)
	if(manifest) qdel(manifest)


/obj/structure/delivery_board
	name = "APDS delivery system terminal"
	desc = "A bulky, noisy monitor screen with a very simple small keyboard and docking port for a tablet device."
	icon = 'modular_vcg/modules/delivery/icons/apds_terminal.dmi'
	icon_state = "terminal_on"
	var/free_icon = "terminal_on"
	var/busy_icon = "terminal_off"
	anchored = 1
	density = 0
	var/delivery_started = 0
	var/delivery_employer_tag = "default"
	var/next_delivery_timestamp
	var/list/crate_types = list(
		"red" = list(
			"cargo_name" = "Cleaning Supplies",
			"color" = "#7c1313",
			"desc" = "Red tinted crates typically contain cleaning supplies, including cleaning chemicals, replacement mops, rags and personal safety equipment.",
			),
		"blue" = list(
			"cargo_name" = "Maintenance Supplies",
			"color" = "#202bca",
			"desc" = "Anything and everything related to maintaining electronics in a store or house - replacement batteries, light bulbs, electronic components as well as tools needed to replace and fix devices using them. ",
			),
		"yellow" = list(
			"cargo_name" = "Equipment and Electronics",
			"color" = "#b8ac3f",
			"desc" = "Large items like computers and other electronics, lightning and ventilation systems, AC units as well as shelving and furniture typically in separate elements and needing further assembly. Also, tools required for the assembly of the above.",
			),
		"green" = list(
			"cargo_name" = "Personal Items",
			"color" = "#165f29",
			"desc" = "Private correspondence and deliveries marked as private. It could be cargo belonging to other crates but earmarked for private delivery due to private reselling or personal use. Typically, just mail but shipped in bulk. ",
			),
		)

/obj/structure/delivery_board/proc/delivery_icon()
	icon_state = free_icon
	update_icon()

/obj/structure/delivery_board/proc/delivery_cooldown(timer)
	var/time_to_wait = 5 MINUTES
	if(timer) time_to_wait = timer
	addtimer(CALLBACK(src,TYPE_PROC_REF(/obj/structure/delivery_board,delivery_icon)),time_to_wait)

/obj/structure/delivery_board/attack_hand(mob/living/user)
	. = ..()
	if(!delivery_started)
		if(world.time > next_delivery_timestamp)
			if(tgui_alert(user,"A new contract is available. Do you wish to start a delivery?","Delivery available",list("Yes","No"),timeout = 10 SECONDS) == "Yes")
				var/picked_difficulty
				var/difficulty_text
				switch(tgui_input_list(user,"Select a contract length, details will be outlined before accepting.","Contract Selection",list("Short","Medium","Long"),timeout = 10 SECONDS))
					if("Short")
						picked_difficulty = 1
						difficulty_text = "A short contract involves 3 locations with up to 6 crates each, meaning the entire delivery can be completed with one truck. The time limit is 20 minutes."
					if("Medium")
						picked_difficulty = 2
						difficulty_text = "A medium contract involves 5 locations with up to 10 crates each, the entire delivery should be completed in 3 runs. The time limit is 45 minutes. "
					if("Long")
						picked_difficulty = 3
						difficulty_text = "A long contract involves 7 locations with up to 15 crates each, meaning that without partial loads each delivery will require a restock. The timie limit is 90 minutes."
				if(tgui_alert(user,difficulty_text,"Confirm Contract",list("Yes","No"),timeout = 10 SECONDS) == "Yes")
					var/obj/item/delivery_contract/contract = new(user,src,picked_difficulty)
					switch(contract.delivery.start_contract())
						if(1)
							user.put_in_hands(contract)
							icon_state = busy_icon
							update_icon()
							to_chat(user,span_notice("Success! A new contract was created and aprorpiate items have been created and dispensed. Check the cotnract item for information about your delivery."))
							contract.manifest.save_data(init = TRUE)
							contract.manifest.read_data(contract.delivery.original_owner)
							delivery_started = 1
							return
						if("fail_reci")
							to_chat(user, span_warning("Not enough recievers avaialble in the game world. This is most likley because too many cotnracts are active at the same time, but is very likely a mapping bug."))
							qdel(contract)
						if("fail_garage")
							to_chat(user, span_warning("No garage area found. This is a mapping bug and should be reported."))
							qdel(contract)
						if("fail_disp")
							to_chat(user, span_warning("Not enough dispensers. This is a mapping bug and should be reported."))
							qdel(contract)
						if("fail_truck")
							to_chat(user, span_warning("Truck spawning failed. This is a mapping bug and should be reported."))
							qdel(contract)
					return
		else
			(to_chat(user,span_notice("A contract was just concluded. There are [time2text((next_delivery_timestamp - world.time),"mm:ss")] left until the next contract can be picked.")))
	else
		to_chat(user,span_notice("Someone is already doing a contract for this delivery office, or none are currently available."))

/obj/structure/delivery_board/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/delivery_contract/))
		return try_contract(user, tool) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING
	if(istype(tool, /obj/item/vamp/keys/cargo_truck))
		return try_contract(user, tool) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING
	return NONE

/obj/structure/delivery_board/proc/try_contract(mob/living/user,obj/item/delivery_contract/contract_item)
	if(contract_item.delivery.delivery_employer_tag != delivery_employer_tag)
		to_chat(user,span_warning("This contract does not seem to be from this board."))
		return
	if(contract_item.delivery.check_owner(user) == 0)
		to_chat(user,span_warning("You don't seem to be on this contract. Only the person who signed the cotract can add you."))
		return
	if(contract_item.delivery.delivery_recievers.len == 0)
		if(get_area(contract_item.delivery.active_truck) != contract_item.delivery.garage_area)
			to_chat(user,span_warning("Warning: Truck outside of garage area."))
		if(tgui_alert(user,"Do you wish to finalize the contract?","Finalize Confirm",list("Yes","No"),timeout = 10 SECONDS) == "Yes")
			contract_item.delivery.delivery_finish()
			return
	if(tgui_alert(user,"Do you wish to update the information on the contract?","Contract Update",list("Yes","No"),timeout = 10 SECONDS) == "Yes")
		contract_item.manifest.save_data()
		return
	if(get_area(contract_item.delivery.active_truck) != contract_item.delivery.garage_area)
		to_chat(user,span_warning("Warning: Truck outside of garage area."))
	if(tgui_alert(user,"Do you wish to finalize the contract early?","Finalize Confirm",list("Yes","No"),timeout = 10 SECONDS) == "Yes")
		contract_item.delivery.delivery_finish()
		return

/obj/structure/delivery_board/proc/try_keys(mob/living/user,obj/item/vamp/keys/cargo_truck/truck_keys)
	if(truck_keys.delivery.delivery_employer_tag != delivery_employer_tag)
		src.balloon_alert(user, "no reaction!")
		return
	if(tgui_alert(user,"Are you SURE you want to respawn the delivery truck? This will reduce your final grade.","Respawn Truck", list("Yes","No"), timeout = 10 SECONDS) == "Yes")
		var/obj/old_truck = truck_keys.delivery.active_truck
		var/obj/effect/landmark/delivery_truck_beacon/truck_beacon = truck_keys.delivery.truck_spawner
		qdel(old_truck)
		truck_beacon.spawn_truck(truck_keys.delivery)

/obj/structure/delivery_reciever

	name = "APDS delivery rack"
	desc = "A discrete delivery rack and RFID chip scanner connected to the APDS system. Supposedly, these chutes automatically open and process any standard crate with an APDS RFID chip once a delivery is complete."
	anchored = 1
	density = 0
	icon = 'modular_vcg/modules/delivery/icons/rack.dmi'
	icon_state = "rack_on"
	var/chute_name = "default"
	var/delivery_in_use = 0
	var/reciever_in_use = 0
	var/list/delivery_status = list(
		"red" = 0,
		"blue" = 0,
		"yellow" = 0,
		"green" = 0,
		)
	light_color = "#ffffff"
	light_power = 2

/obj/structure/delivery_reciever/proc/animation(type)
	if(!type) return
	switch(type)
		if(1)
			mouse_opacity = 0
			icon_state = "rack_down"
			update_icon()
			sleep(5)
			set_light(0)
			icon_state = "rack_off"
			update_icon()
			animate(src, alpha = 0, time = 5 SECONDS)
		if(2)
			mouse_opacity = 1
			animate(src,alpha = 255,time = 5 SECONDS)
			sleep(5 SECONDS)
			icon_state = "rack_up"
			update_icon()
			sleep(5)
			icon_state = "rack_on"
			update_icon()
			set_light(2)

/obj/structure/delivery_reciever/proc/reset_reciever()
	delivery_in_use = 0
	delivery_status = list(
		"red" = 0,
		"blue" = 0,
		"yellow" = 0,
		"green" = 0,
		)
	INVOKE_ASYNC(src,PROC_REF(animation),1)

/obj/structure/delivery_reciever/proc/check_deliveries()
	if(delivery_status["red"] != 0 || delivery_status["blue"] != 0 || delivery_status["yellow"] != 0 || delivery_status["green"] != 0) return 0
	return 1

/obj/structure/delivery_reciever/Initialize()
	. = ..()
	alpha = 0
	mouse_opacity = 0
	icon_state = "rack_off"
	GLOB.delivery_available_recievers.Add(src)
	name = "[initial(name)] - [capitalize(chute_name)]"

/obj/structure/delivery_reciever/Destroy()
	. = ..()
	GLOB.delivery_available_recievers.Remove(src)

/obj/structure/delivery_reciever/attack_hand(mob/living/user)
	. = ..()
	if(reciever_in_use == 1)
		src.balloon_alert(user, "in use!")
		return
	if(user.pulling)
		if(delivery_in_use == 0) return
		if(istype(user.pulling,/obj/structure/delivery_crate/))
			var/obj/structure/delivery_crate/pulled_crate = user.pulling
			if(pulled_crate.delivery.check_owner(user) == 0)
				balloon_alert(user, "no reaction!")
				return
			reciever_in_use = 1
			playsound(src,'modular_vcg/modules/delivery/sounds/cargocrate_move.ogg',50,10)
			if(do_after(user, 2 SECONDS, src))
				if(delivery_status[pulled_crate.crate_type] > 0)
					delivery_status[pulled_crate.crate_type] -= 1
					pulled_crate.delivery.delivery_score["delivered_crates"] += 1
					if(check_deliveries() == 1)
						pulled_crate.delivery.reciever_complete(src)
						reset_reciever()
				else
					pulled_crate.delivery.delivery_score["misdelivered_crates"] += 1
				playsound(src,'modular_vcg/modules/delivery/sounds/cargocrate_load.ogg',50,10)
				qdel(pulled_crate)
			reciever_in_use = 0

/obj/structure/delivery_dispenser

	name = "APDS Cargo Dispenser"
	desc = "A chute-based dispenser connected to the APDS system. Has a small RFID scanner located right bellow a colored light bulb. Using a key with a valid APDS RFID chip should activate the dispenser. It also looks like it should be possible to feed crates back into the device."
	anchored = 1
	density = 0
	icon = 'modular_vcg/modules/delivery/icons/dispenser.dmi'
	icon_state = "dispenser_on"
	var/chute_name = "default"
	var/dispenser_active = 0
	var/dispenser_in_use
	var/delivery_employer_tag
	var/crate_type
	light_color = "#ffffff"
	light_power = 20

/obj/structure/delivery_dispenser/Initialize()
	. = ..()
	GLOB.delivery_available_dispensers.Add(src)
	icon_state = "dispenser_off"
	update_icon()
	alpha = 0
	mouse_opacity = 0
	name = "[initial(name)] - [capitalize(chute_name)]]"

/obj/structure/delivery_dispenser/Destroy()
	. = ..()
	GLOB.delivery_available_dispensers.Remove(src)

/obj/structure/delivery_dispenser/proc/animation(type)
	if(!type) return
	switch(type)
		if(1)
			mouse_opacity = 0
			light_color = initial(light_color)
			set_light(0)
			icon_state = "dispenser_down"
			update_icon()
			sleep(5)
			icon_state = "dispenser_off"
			update_icon()
			animate(src,alpha = 0,5 SECONDS)
		if(2)
			mouse_opacity = 1
			animate(src,alpha = 255,time = 5 SECONDS)
			sleep(5 SECONDS)
			icon_state = "dispenser_up"
			update_icon()
			sleep(5)
			icon_state = "dispenser_on"
			update_icon()

/obj/structure/delivery_dispenser/proc/reset_dispenser()
	dispenser_active = 0
	crate_type = null
	INVOKE_ASYNC(src,PROC_REF(animation),1)

/obj/structure/delivery_dispenser/proc/dispense_cargo(obj/truck_key, turf/target_turf)
	if(!truck_key) return
	var/obj/item/vamp/keys/cargo_truck/key_item = truck_key
	var/obj/structure/delivery_crate/dispensed_crate = new(target_turf)
	key_item.delivery.active_crates.Add(dispensed_crate)
	dispensed_crate.crate_type = crate_type
	dispensed_crate.delivery = key_item.delivery
	dispensed_crate.source_dispenser = src
	dispensed_crate.name += " - [key_item.delivery.crate_designations["[crate_type]"]["cargo_name"]]"
	dispensed_crate.color = key_item.delivery.crate_designations["[crate_type]"]["color"]
	dispensed_crate.desc += " [key_item.delivery.crate_designations["[crate_type]"]["desc"]]"
	dispensed_crate.update_icon()
	playsound(src,'modular_vcg/modules/delivery/sounds/cargocrate_unload.ogg',50,10)
	key_item.delivery.delivery_score["dispensed_crates"] += 1

/obj/structure/delivery_dispenser/attack_hand(mob/living/user)
	. = ..()
	if(dispenser_active == 0)
		to_chat(user, span_notice("The device seems to be offline."))
		return
	if(dispenser_in_use == 1)
		src.balloon_alert(user, "in use!")
		return
	if(user.pulling == null)
		to_chat(user, span_notice("The dispenser only reacts to keys and other devices with an active APDS RFID chip."))
		return
	if(user.pulling != null)
		if(istype(user.pulling, /obj/structure/delivery_crate))
			var/obj/structure/delivery_crate/pulled_crate = user.pulling
			if(pulled_crate.source_dispenser == src)
				dispenser_in_use = 1
				playsound(src,'modular_vcg/modules/delivery/sounds/cargocrate_move.ogg',50,10)
				if(do_after(user, 2 SECONDS, src))
					pulled_crate.delivery.delivery_score["dispensed_crates"] -= 1
					playsound(src,'modular_vcg/modules/delivery/sounds/cargocrate_load.ogg',50,10)
					qdel(pulled_crate)
				dispenser_in_use = 0

/obj/structure/delivery_dispenser/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/vamp/keys/cargo_truck))
		return try_dispense(user, tool) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING
	return NONE

/obj/structure/delivery_dispenser/proc/try_dispense(mob/living/user, obj/item/vamp/keys/cargo_truck/truck_key)
	if(dispenser_in_use == 1)
		src.balloon_alert(user, "in use!")
		return
	if(truck_key.delivery == null)
		to_chat(user,span_warning("Error, delivery data missing. This is a bug."))
		return
	if(truck_key.delivery.delivery_dispensers.Find(src) == 0)
		src.balloon_alert(user, "no reaction!")
		return
	var/turf/user_turf = get_turf(user)
	for(var/obj/structure/delivery_crate/potential_crate in user_turf.contents)
		if(potential_crate)
			src.balloon_alert(user, "ground full!")
			return
	dispenser_in_use = 1
	playsound(src,'modular_vcg/modules/delivery/sounds/cargocrate_move.ogg',50,10)
	if(do_after(user, 2 SECONDS, src))
		dispense_cargo(truck_key,user_turf)
	dispenser_in_use = 0

/obj/structure/delivery_crate

	name = "APDS delivery crate"
	desc = "A securely sealed bulky crate with a built-in RFID chip that's part of the APDS system. A small tag on the side gives a generic description of its contents, but seems to contain only random strings of letters sand numbers otherwise. Likely heavier than its actual contents."
	anchored = 0
	density = 1
	icon = 'modular_darkpack/master_files/icons/obj/storage/crates32x32.dmi'
	icon_state = "crate"
	var/datum/delivery_datum/delivery
	var/obj/structure/delivery_dispenser/source_dispenser
	var/crate_type

/obj/structure/delivery_crate/Initialize()
	if(crate_type) name = initial(name) + " - [crate_type]"
	AddElement(/datum/element/climbable)
	. = ..()

/obj/structure/delivery_crate/Destroy()
	if(delivery)
		delivery.active_crates.Remove(src)
		delivery = null
	. = ..()

/obj/darkpack_car/delivery_truck
	name = "APDS delivery truck"
	desc = "A modified truck, with most of its storage occupied by special automated racks connected to a automated controller and an RFID reader system, all tied to the APDS system. Provided the truck is unlocked, crates can be fed and retrieved from the system with relative ease."
	icon_state = "track"
	max_passengers = 4
	var/delivery_capacity = 20
	var/datum/delivery_datum/delivery
	var/datum/delivery_storage/delivery_trunk

/obj/darkpack_car/delivery_truck/Destroy()
	if(delivery)
		if(delivery.active_truck == src) delivery.active_truck = null
		delivery = null
	qdel(delivery_trunk)
	. = ..()


/obj/darkpack_car/delivery_truck/Initialize()
	. = ..()
	delivery_trunk = new(src,delivery_capacity)

/obj/darkpack_car/delivery_truck/attack_hand(mob/user)
	. = ..()
	if(locked == TRUE)
		src.balloon_alert(user, "closed!")
		return
	if(user.pulling == null)
		check_rack(user)
		return
	else
		var/obj/structure/delivery_crate/pulled_crate = user.pulling
		if(!pulled_crate)
			src.balloon_alert(user, "no room!")
			return
		else
			playsound(src,'modular_vcg/modules/delivery/sounds/cargocrate_move.ogg',50,10)
			if(do_after(user, 2 SECONDS, pulled_crate))
				playsound(src,'modular_vcg/modules/delivery/sounds/cargocrate_load.ogg',50,10)
				delivery_trunk.add_to_storage(user,pulled_crate)

/obj/darkpack_car/delivery_truck/proc/check_rack(mob/user)
	if(delivery_trunk.storage.len == 0)
		src.balloon_alert(user, "empty!")
		return
	var/turf/user_turf = get_turf(user)
	for(var/obj/structure/delivery_crate/potential_crate in user_turf.contents)
		if(potential_crate)
			src.balloon_alert(user, "no room!")
			return
	delivery_trunk.retrieval_menu(user)

/obj/effect/landmark/delivery_truck_beacon
	name = "delivery truck spawner"
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "x4"
	invisibility = 101
	density = 0
	var/spawn_dir = NORTH
	var/delivery_employer_tag = "default"

/obj/effect/landmark/delivery_truck_beacon/proc/spawn_truck(datum/linked_datum)
	if(!linked_datum) return
	var/turf/local_turf = get_turf(src)
	var/obj/darkpack_car/delivery_truck/spawned_truck = new(local_turf)
	spawned_truck.dir = spawn_dir
	switch(spawn_dir)
		if(NORTH)
			spawned_truck.movement_vector = 0
		if(SOUTH)
			spawned_truck.movement_vector = 180
		if(EAST)
			spawned_truck.movement_vector = 90
		if(WEST)
			spawned_truck.movement_vector = 270
	spawned_truck.delivery = linked_datum
	spawned_truck.delivery.active_truck = spawned_truck
	spawned_truck.locked = TRUE
	spawned_truck.access = spawned_truck.delivery.delivery_employer_tag
	var/obj/item/vamp/keys/cargo_truck/spawned_keys = new(local_turf)
	spawned_keys.delivery = linked_datum
	spawned_keys.owner = spawned_keys.delivery.original_owner
	spawned_keys.accesslocks = list(spawned_truck.delivery.delivery_employer_tag)
	spawned_truck.delivery.spawned_keys.Add(spawned_keys)
	spawned_truck.delivery.original_owner.put_in_hands(spawned_keys)

/obj/effect/landmark/delivery_truck_beacon/Initialize()
	GLOB.delivery_available_veh_spawners.Add(src)
	. = ..()

/obj/effect/landmark/delivery_truck_beacon/Destroy()
	GLOB.delivery_available_veh_spawners.Remove(src)
	. = ..()

/obj/item/vamp/keys/cargo_truck
	name = "APDS delivery truck key"
	desc = "A somewhat bulky key with an embedded RFID chip."

	var/datum/delivery_datum/delivery
	var/mob/living/owner

/obj/item/vamp/keys/cargo_truck/Destroy()
	if(delivery)
		delivery.spawned_keys.Remove(src)
		delivery = null
	. = ..()

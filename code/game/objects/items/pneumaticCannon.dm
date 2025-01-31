
#define PCANNON_FIREALL 1
#define PCANNON_FILO 2
#define PCANNON_FIFO 3

/obj/item/pneumatic_cannon
	name = "pneumatic cannon"
	desc = "A gas-powered cannon that can fire any object loaded into it."
	w_class = WEIGHT_CLASS_BULKY
	item_flags = ISWEAPON
	force = 8 //Very heavy
	attack_verb_continuous = list("bludgeons", "smashes", "beats")
	attack_verb_simple = list("bludgeon", "smash", "beat")
	icon = 'icons/obj/pneumaticCannon.dmi'
	icon_state = "pneumaticCannon"
	item_state = "bulldog"
	lefthand_file = 'icons/mob/inhands/weapons/guns_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/weapons/guns_righthand.dmi'
	armor_type = /datum/armor/item_pneumatic_cannon
	var/maxWeightClass = 20 //The max weight of items that can fit into the cannon
	var/loadedWeightClass = 0 //The weight of items currently in the cannon
	var/obj/item/tank/internals/tank = null //The gas tank that is drawn from to fire things
	var/gasPerThrow = 3 //How much gas is drawn from a tank's pressure to fire
	var/list/loadedItems = list() //The items loaded into the cannon that will be fired out
	var/pressureSetting = 1 //How powerful the cannon is - higher pressure = more gas but more powerful throws
	var/checktank = TRUE
	var/range_multiplier = 1
	var/throw_amount = 20	//How many items to throw per fire
	var/fire_mode = PCANNON_FIREALL
	var/automatic = FALSE
	var/clumsyCheck = TRUE
	var/list/allowed_typecache		//Leave as null to allow all.
	var/charge_amount = 1
	var/charge_ticks = 1
	var/charge_tick = 0
	var/charge_type
	var/selfcharge = FALSE
	var/fire_sound = 'sound/weapons/sonic_jackhammer.ogg'
	var/spin_item = TRUE //Do the projectiles spin when launched?
	trigger_guard = TRIGGER_GUARD_NORMAL



/datum/armor/item_pneumatic_cannon
	fire = 60
	acid = 50

/obj/item/pneumatic_cannon/Initialize(mapload)
	. = ..()
	if(selfcharge)
		init_charge()

/obj/item/pneumatic_cannon/proc/init_charge()	//wrapper so it can be vv'd easier
	START_PROCESSING(SSobj, src)

/obj/item/pneumatic_cannon/process()
	if(++charge_tick >= charge_ticks && charge_type)
		fill_with_type(charge_type, charge_amount)

/obj/item/pneumatic_cannon/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/pneumatic_cannon/CanItemAutoclick()
	return automatic

/obj/item/pneumatic_cannon/examine(mob/user)
	. = ..()
	var/list/out = list()
	if(!in_range(user, src))
		out += span_notice("You'll need to get closer to see any more.")
		return
	for(var/obj/item/I in loadedItems)
		out += span_info("[icon2html(I, user)] It has \a [I] loaded.")
		CHECK_TICK
	if(tank)
		out += span_notice("[icon2html(tank, user)] It has \a [tank] mounted onto it.")
	. += out.Join("\n")

/obj/item/pneumatic_cannon/attackby(obj/item/W, mob/user, params)
	if(user.a_intent == INTENT_HARM)
		return ..()
	if(istype(W, /obj/item/tank/internals))
		if(!tank)
			var/obj/item/tank/internals/IT = W
			if(IT.volume <= 3)
				to_chat(user, span_warning("\The [IT] is too small for \the [src]."))
				return
			updateTank(W, 0, user)
	else if(W.type == type)
		to_chat(user, span_warning("You're fairly certain that putting a pneumatic cannon inside another pneumatic cannon would cause a spacetime disruption."))
	else if(W.tool_behaviour == TOOL_WRENCH)
		switch(pressureSetting)
			if(1)
				pressureSetting = 2
			if(2)
				pressureSetting = 3
			if(3)
				pressureSetting = 1
		to_chat(user, span_notice("You tweak \the [src]'s pressure output to [pressureSetting]."))
	else if(W.tool_behaviour == TOOL_SCREWDRIVER)
		if(tank)
			updateTank(tank, 1, user)
	else if(loadedWeightClass >= maxWeightClass)
		to_chat(user, span_warning("\The [src] can't hold any more items!"))
	else if(isitem(W))
		var/obj/item/IW = W
		load_item(IW, user)

/obj/item/pneumatic_cannon/proc/can_load_item(obj/item/I, mob/user)
	if(!istype(I))			//Players can't load non items, this allows for admin varedit inserts.
		return TRUE
	if(allowed_typecache && !is_type_in_typecache(I, allowed_typecache))
		if(user)
			to_chat(user, span_warning("[I] won't fit into [src]!"))
		return
	if((loadedWeightClass + I.w_class) > maxWeightClass)	//Only make messages if there's a user
		if(user)
			to_chat(user, span_warning("\The [I] won't fit into \the [src]!"))
		return FALSE
	if(I.w_class > w_class)
		if(user)
			to_chat(user, span_warning("\The [I] is too large to fit into \the [src]!"))
		return FALSE
	return TRUE

/obj/item/pneumatic_cannon/proc/load_item(obj/item/I, mob/user)
	if(!can_load_item(I, user))
		return FALSE
	if(user)		//Only use transfer proc if there's a user, otherwise just set loc.
		if(!user.transferItemToLoc(I, src))
			return FALSE
		to_chat(user, span_notice("You load \the [I] into \the [src]."))
	else
		I.forceMove(src)
	loadedItems += I
	loadedWeightClass += I.w_class
	return TRUE

/obj/item/pneumatic_cannon/afterattack(atom/target, mob/living/user, flag, params)
	. = ..()
	if(flag && user.a_intent == INTENT_HARM) //melee attack
		return
	if(!istype(user))
		return
	Fire(user, target)

/obj/item/pneumatic_cannon/proc/Fire(mob/living/user, var/atom/target)
	if(!istype(user) && !target)
		return
	var/discharge = 0
	if(!can_trigger_gun(user))
		return
	if(!loadedItems || !loadedWeightClass)
		to_chat(user, span_warning("\The [src] has nothing loaded."))
		return
	if(!tank && checktank)
		to_chat(user, span_warning("\The [src] can't fire without a source of gas."))
		return
	if(tank && !tank.remove_air(gasPerThrow * pressureSetting))
		to_chat(user, span_warning("\The [src] lets out a weak hiss and doesn't react!"))
		return
	if(HAS_TRAIT(user, TRAIT_CLUMSY) && prob(75) && clumsyCheck && iscarbon(user))
		var/mob/living/carbon/C = user
		C.visible_message(span_warning("[C] loses [C.p_their()] grip on [src], causing it to go off!"), span_userdanger("[src] slips out of your hands and goes off!"))
		C.dropItemToGround(src, TRUE)
		if(prob(10))
			target = get_turf(user)
		else
			target = pick(RANGE_TURFS(3,src))
		discharge = 1
	if(!discharge)
		user.visible_message(span_danger("[user] fires \the [src]!"), \
							span_danger("You fire \the [src]!"))
	log_combat(user, target, "fired at", src)
	var/turf/T = get_target(target, get_turf(src))
	playsound(src, fire_sound, 50, 1)
	fire_items(T, user)
	user.changeNext_move(CLICK_CD_MELEE)
	if(pressureSetting >= 3 && iscarbon(user))
		var/mob/living/carbon/C = user
		C.visible_message(span_warning("[C] is thrown down by the force of the cannon!"), span_userdanger("[src] slams into your shoulder, knocking you down!"))
		C.Paralyze(60)

/obj/item/pneumatic_cannon/proc/fire_items(turf/target, mob/user)
	if(fire_mode == PCANNON_FIREALL)
		for(var/obj/item/ITD in loadedItems) //Item To Discharge
			if(!throw_item(target, ITD, user))
				break
	else
		for(var/i in 1 to throw_amount)
			if(!loadedItems.len)
				break
			var/obj/item/I
			if(fire_mode == PCANNON_FILO)
				I = loadedItems[loadedItems.len]
			else
				I = loadedItems[1]
			if(!throw_item(target, I, user))
				break

/obj/item/pneumatic_cannon/proc/throw_item(turf/target, obj/item/I, mob/user)
	if(!istype(I))
		return FALSE
	loadedItems -= I
	loadedWeightClass -= I.w_class
	I.forceMove(get_turf(src))
	I.throw_at(target, pressureSetting * 10 * range_multiplier, pressureSetting * 2, user, spin_item)
	return TRUE

/obj/item/pneumatic_cannon/proc/get_target(turf/target, turf/starting)
	if(range_multiplier == 1)
		return target
	var/x_o = (target.x - starting.x)
	var/y_o = (target.y - starting.y)
	var/new_x = clamp((starting.x + (x_o * range_multiplier)), 0, world.maxx)
	var/new_y = clamp((starting.y + (y_o * range_multiplier)), 0, world.maxy)
	var/turf/newtarget = locate(new_x, new_y, starting.z)
	return newtarget

/obj/item/pneumatic_cannon/handle_atom_del(atom/A)
	. = ..()
	if (loadedItems.Remove(A))
		var/obj/item/I = A
		loadedWeightClass -= I.w_class
	else if (A == tank)
		tank = null
		update_icon()

/obj/item/pneumatic_cannon/ghetto //Obtainable by improvised methods; more gas per use, less capacity, but smaller
	name = "improvised pneumatic cannon"
	desc = "A gas-powered, object-firing cannon made out of common parts."
	force = 5
	w_class = WEIGHT_CLASS_LARGE
	maxWeightClass = 7
	gasPerThrow = 5
	fire_mode = PCANNON_FIFO

/obj/item/pneumatic_cannon/proc/updateTank(obj/item/tank/internals/thetank, removing = 0, mob/living/carbon/human/user)
	if(removing)
		if(!tank)
			return
		to_chat(user, span_notice("You detach \the [thetank] from \the [src]."))
		tank.forceMove(user.drop_location())
		user.put_in_hands(tank)
		tank = null
	if(!removing)
		if(tank)
			to_chat(user, span_warning("\The [src] already has a tank."))
			return
		if(!user.transferItemToLoc(thetank, src))
			return
		to_chat(user, span_notice("You hook \the [thetank] up to \the [src]."))
		tank = thetank
	update_icon()

/obj/item/pneumatic_cannon/update_overlays()
	. = ..()
	if(!tank)
		return
	. += tank.icon_state

/obj/item/pneumatic_cannon/proc/fill_with_type(type, amount)
	if(!ispath(type, /obj) && !ispath(type, /mob))
		return FALSE
	var/loaded = 0
	for(var/i in 1 to amount)
		var/obj/item/I = new type
		if(!load_item(I, null))
			qdel(I)
			return loaded
		loaded++
		CHECK_TICK

/obj/item/pneumatic_cannon/pie
	name = "pie cannon"
	desc = "Load cream pie for optimal results."
	force = 10
	icon_state = "piecannon"
	gasPerThrow = 0
	checktank = FALSE
	range_multiplier = 3
	fire_mode = PCANNON_FIFO
	throw_amount = 1
	maxWeightClass = 200	//50 pies. :^)
	clumsyCheck = FALSE
	var/static/list/pie_typecache = typecacheof(/obj/item/food/pie)

/obj/item/pneumatic_cannon/pie/Initialize(mapload)
	. = ..()
	allowed_typecache = pie_typecache

/obj/item/pneumatic_cannon/pie/selfcharge
	automatic = TRUE
	selfcharge = TRUE
	charge_type = /obj/item/food/pie/cream
	maxWeightClass = 80	//20 pies.

/obj/item/pneumatic_cannon/pie/selfcharge/compact
	name = "honkinator-4 compact pie cannon"
	desc = "A compact, self loading pie cannon for tactical pranking action."
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/pneumatic_cannon/pie/selfcharge/cyborg
	name = "low velocity pie cannon"
	automatic = FALSE
	charge_type = /obj/item/food/pie/cream/nostun
	maxWeightClass = 8		//2 pies
	charge_ticks = 2		//4 second/pie

/obj/item/pneumatic_cannon/speargun
	name = "magnetic speargun"
	desc = "A weapon favored by carp hunters. Fires specialized spears using magnetic energy. A savvy- or desperate- hunter may be able to find more esoteric payloads"
	icon = 'icons/obj/guns/projectile.dmi'
	icon_state = "speargun"
	item_state = "speargun"
	w_class = WEIGHT_CLASS_BULKY
	force = 10
	fire_sound = 'sound/weapons/grenadelaunch.ogg'
	gasPerThrow = 0
	checktank = FALSE
	pressureSetting = 2
	range_multiplier = 3
	throw_amount = 1
	maxWeightClass = WEIGHT_CLASS_BULKY //a single magspear or spear
	spin_item = FALSE
	var/static/list/magspear_typecache = typecacheof(list(/obj/item/throwing_star/magspear, /obj/item/spear, /obj/item/stack/rods/fifty, /obj/item/stack/rods, /obj/item/stack/rods/twenty, /obj/item/stack/rods/ten, /obj/item/katana, /obj/item/katana/cursed, /obj/item/toy/katana, /obj/item/spear/explosive, /obj/item/clockwork/weapon/brass_spear))

/obj/item/pneumatic_cannon/speargun/Initialize(mapload)
	. = ..()
	allowed_typecache = magspear_typecache

/obj/item/storage/backpack/magspear_quiver
	name = "quiver"
	desc = "A quiver for holding magspears."
	icon_state = "quiver"
	item_state = "quiver"

/obj/item/storage/backpack/magspear_quiver/ComponentInitialize()
	. = ..()
	var/datum/component/storage/STR = GetComponent(/datum/component/storage)
	STR.max_items = 30
	STR.max_w_class = WEIGHT_CLASS_BULKY
	STR.max_combined_w_class = STR.max_w_class*STR.max_items
	STR.display_numerical_stacking = TRUE
	STR.set_holdable(list(
		/obj/item/throwing_star/magspear
		))

/obj/item/storage/backpack/magspear_quiver/PopulateContents()
	for(var/i in 1 to 30)
		new /obj/item/throwing_star/magspear(src)

#undef PCANNON_FIREALL
#undef PCANNON_FILO
#undef PCANNON_FIFO

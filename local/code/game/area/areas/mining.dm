/**********************Taeloth Areas**************************/

/area/taeloth
	name = "Taeloth"
	icon = 'icons/area/areas_station.dmi'
	icon_state = "explored"
	always_unpowered = TRUE
	power_environ = FALSE
	power_equip = FALSE
	power_light = FALSE
	requires_power = TRUE
	has_gravity = STANDARD_GRAVITY
	flags_1 = NONE
	area_flags = VALID_TERRITORY | UNIQUE_AREA | FLORA_ALLOWED
	sound_environment = SOUND_AREA_TAELOTH
	ambience_index = AMBIENCE_HOLY
	outdoors = TRUE

/area/taeloth/Initialize(mapload)
	try_lighting()
	return ..()

/area/taeloth/proc/try_lighting()
	if(HAS_TRAIT(SSstation, STATION_TRAIT_BRIGHT_DAY))
		base_lighting_alpha = 125 // With all that canopy in the way and no snow to amplify, things are a smidge darker than Icebox.

/area/taeloth/unexplored // In theory, monsters spawn here. They do not in practice, unimplemented. Random Generation + Ruins work though.
	icon_state = "unexplored"
	area_flags = VALID_TERRITORY | UNIQUE_AREA | CAVES_ALLOWED | FLORA_ALLOWED | MOB_SPAWN_ALLOWED
	map_generator = /datum/map_generator/jungle_generator

/area/taeloth/unexplored/danger // Additional to said theory: megafauna.
	icon_state = "danger"
	area_flags = VALID_TERRITORY | UNIQUE_AREA | CAVES_ALLOWED | FLORA_ALLOWED | MOB_SPAWN_ALLOWED | MEGAFAUNA_SPAWN_ALLOWED

/area/taeloth/underground
	name = "Taeloth Caves"

/area/taeloth/underground/try_lighting()
	return

/area/taeloth/underground/unexplored
	icon_state = "unexplored"
	area_flags = VALID_TERRITORY | UNIQUE_AREA | CAVES_ALLOWED | FLORA_ALLOWED | MOB_SPAWN_ALLOWED
	map_generator = /datum/map_generator/cave_generator/jungle

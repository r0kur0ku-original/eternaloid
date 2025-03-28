package rlib

import rg "libs/gen"
import nl "libs/nlib"
import od "libs/odinium"
import odr "libs/odinium_cost"
import rsc "libs/resource"
import rl "vendor:raylib"

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:path/filepath"
import "core:strings"
import tim "core:time"

Game_State :: struct {
	global:    ^Global_Data,
	global_m:  Global_Resource,
	events:    Events,
	tab_state: i32,
	tab_1:     Game_Tab_1,
	slide:     bool,
	seed:      f64,
	frame:     i128,
}


Global_Data :: struct {
	entities:       []i32,
	total_entities: f64,
	oid:            od.bigfloat,
	oid_max:        od.bigfloat,
	wood:           od.bigfloat,
	food:           od.bigfloat,
	stone:          od.bigfloat,
	global_speed:   od.bigfloat,
	town_speed:     od.bigfloat,
}

Global_Resource :: struct {
	oid:   rsc.Resource_Manager,
	wood:  rsc.Resource_Manager,
	food:  rsc.Resource_Manager,
	stone: rsc.Resource_Manager,
}

Events :: struct {
	update_town: bool,
	update_fog:  bool,
}

Game_Tab_1 :: struct {
	camera:             nl.Coord,
	camera_real:        nl.Coord,
	camera_vel:         nl.Coord,
	camera_zoom:        f64,
	camera_zoom_speed:  f64,
	hold:               string,
	hold_t:             i32,
	tile_data:          []i32,
	buildings_data:     []i32,
	building_area_data: []i32,
	continent_sizes:    [dynamic]map[[2]i32][2]i32,
	fog_data:           []i32,
	test_data:          ^map[[2]i32]bool,
	map_mesh:           rg.mesh,
	dev_see:            bool,
	dev_elevation:      bool,
	selecting:          bool,
	selection_area:     [4]i32,
	built_tick:         i32,
	built_max:          i32,
	building_info:      string,
}

// settings tab

settings_tab :: proc(window: ^nl.Window_Data, mouse: nl.Mouse_Data, game: ^Game_State) {
	nl.draw_text(
		text = "Zoom Speed",
		position = nl.Coord{150, 35},
		spacing = 3,
		color = rl.Color{255, 255, 255, 255},
		fontSize = 16,
		window = window^,
	)

	nl.draw_slider(
		position = nl.Coord{150, 50},
		size = nl.Coord{130, 15},
		window = window^,
		mouse = mouse,
		slider_percentage = &game.tab_1.camera_zoom_speed,
		color = rl.Color{150, 150, 150, 255},
	)
}

animate_textures :: proc(window: ^nl.Window_Data, frame: i128) {
	grass := frame / 100 % 4
	if (grass ==
		   0) {nl.switch_texture(original_image_name = "grass.png", new_image_name = "grass1.png", image_cache_map = &window.image_cache_map)}
	if (grass ==
		   1) {nl.switch_texture(original_image_name = "grass.png", new_image_name = "grass2.png", image_cache_map = &window.image_cache_map)}
	if (grass ==
		   2) {nl.switch_texture(original_image_name = "grass.png", new_image_name = "grass3.png", image_cache_map = &window.image_cache_map)}
	if (grass ==
		   3) {nl.switch_texture(original_image_name = "grass.png", new_image_name = "grass1.png", image_cache_map = &window.image_cache_map)}
}

check_can_draw :: proc(
	position: nl.Coord,
	size: f64,
	offset: nl.Coord,
	window: nl.Window_Data,
) -> bool {
	draw := true
	if (f64(position.x) + f64(32 * size) < f64(295)) {
		draw = false}
	if (f64(position.y) + f64(32 * size) < f64(0)) {
		draw = false}
	if (position.x) > window.original_size.x {
		draw = false}
	if (position.y) > window.original_size.y {
		draw = false}
	return draw
}

global :: proc(game: ^Game_State) {


	buy_building :: proc(building_type: i32, game: ^Game_State, index: int) {
		cost_resources :: struct {
			oid:   od.bigfloat,
			wood:  od.bigfloat,
			food:  od.bigfloat,
			stone: od.bigfloat,
		}

		cost_building :: proc(
			building_type: i32,
			amount: i32,
			natural_tile: i32,
		) -> (
			cost: cost_resources,
			ok: bool,
		) {
			cost = cost_resources {
				od.bigfloat{0, 0},
				od.bigfloat{0, 0},
				od.bigfloat{0, 0},
				od.bigfloat{0, 0},
			}
			ok = true
			if (building_type == 1) {
				cost.wood = odr.linear_growth(
					od.normalize(od.bigfloat{f64(amount), 0}),
					od.bigfloat{2.5, 2},
					od.bigfloat{8, 0},
				)
			}
			if (building_type == 2) {
					cost.stone = odr.linear_growth(
						od.normalize(od.bigfloat{f64(amount), 0}),
						od.bigfloat{2.5, 2},
						od.bigfloat{5, 0},
					)
			}
			if (building_type == 3) {
				if 2 < natural_tile && natural_tile < 7 {
					cost.wood = odr.linear_growth(
						od.normalize(od.bigfloat{f64(amount), 0}),
						od.bigfloat{2.5, 2},
						od.bigfloat{5, 0},
					)
				} else {ok = false}
			}
			if (building_type == 4) {
				if natural_tile == 1 {
					cost.wood = odr.linear_growth(
						od.normalize(od.bigfloat{f64(amount), 0}),
						od.bigfloat{1, 3},
						od.bigfloat{5, 1},
					)
				} else {ok = false}
			}
			if (building_type == 5) {
				if natural_tile == 2 {
					cost.wood = odr.linear_growth(
						od.normalize(od.bigfloat{f64(amount), 0}),
						od.bigfloat{1, 2},
						od.bigfloat{5, 0},
					)
				} else {ok = false}
			}
			return
			/*
		"boulders.png",
			"grass.png",
			"tree1.png",
			"tree2.png",
			"tree3.png",
			"tree5.png",*
    */
		}

		compare_resources :: proc(r: Global_Data, c: cost_resources) -> (can_buy: bool) {
			can_buy = true
			if od.ls_than(r.oid, c.oid) {can_buy = false}
			if od.ls_than(r.wood, c.wood) {can_buy = false}
			if od.ls_than(r.stone, c.stone) {can_buy = false}
			if od.ls_than(r.food, c.food) {can_buy = false}
			return
		}
		deduct_resources :: proc(r: ^Global_Data, c: cost_resources) {
			r.oid = od.sub(r.oid, c.oid)
			r.wood = od.sub(r.wood, c.wood)
			r.stone = od.sub(r.stone, c.stone)
			r.food = od.sub(r.food, c.food)
		}

		cost, ok := cost_building(
			building_type,
			game.global.entities[building_type],
			game.tab_1.tile_data[index],
		)
		if compare_resources(game.global^, cost) && ok {
			game.tab_1.buildings_data[index] = building_type
			deduct_resources(game.global, cost)
			game.events.update_town = true
			game.tab_1.built_tick += 1
			game.global.entities[building_type] += 1
		}
		if !ok {
			game.tab_1.building_area_data[index] = 0
		}
	}

	update_building_area :: proc(game: ^Game_State) {
		if (game.frame % 10 == 0) {
			for building_type, index in game.tab_1.building_area_data {
				if game.tab_1.built_tick > game.tab_1.built_max {
					break
				}
				chance := (rg.random_num(&game.seed) + 1) / 2
				if building_type != 0 && chance < 0.5 {
					building := game.tab_1.buildings_data[index]

					if building != building_type {
						buy_building(building_type = building_type, game = game, index = index)
						if building_type == 2 {
							game.events.update_fog = true
						}
					} else {
						game.tab_1.building_area_data[index] = 0
					}

				}
			}
		}
		game.tab_1.built_tick = 0
	}

	count_entities :: proc(game: ^Game_State) -> ([]i32, f64) {
		list_entities := make_slice([]i32, 8)
		total: f64 = 0
		for i in game.tab_1.buildings_data {
			list_entities[i] += 1
			if i != 0 {
				total += 1

			}
		}
		return list_entities, total
	}

	if game.events.update_town {
		delete(game.global.entities)
		total: f64
		game.global.entities, total = count_entities(game)
		game.global.total_entities = total
		game.global.oid = od.normalize(od.bigfloat{f64(game.global.entities[1]), 0})


		rsc.update_resource(
			&game.global_m.stone,
			od.bigfloat{f64(game.global.entities[4]), -3},
			0,
			rsc.Boost_Type.base,
		)
		rsc.update_resource(
			&game.global_m.wood,
			od.bigfloat{f64(game.global.entities[3]), -1},
			0,
			rsc.Boost_Type.base,
		)
		rsc.update_resource(
			&game.global_m.food,
			od.bigfloat{f64(game.global.entities[5]), -1},
			0,
			rsc.Boost_Type.base,
		)
		game.events.update_town = false
	}

	game.global.town_speed = od.sqrt(
		od.div(
			od.mul(game.global.oid, od.add(od.sqrt(game.global.food), od.bigfloat{1, 0})),
			od.normalize(od.bigfloat{game.global.total_entities + 1, 0}),
		),
	)
	if od.ls_than(game.global.town_speed, od.bigfloat{1, -1}) {
		game.global.town_speed = od.bigfloat{1, -1}
	}
	update_building_area(game)
	rsc.run_resource_manager(&game.global_m.oid)
	rsc.run_resource_manager(&game.global_m.wood)
	rsc.run_resource_manager(&game.global_m.stone)
	rsc.run_resource_manager(&game.global_m.food)
}

generate_spawn :: proc(game: ^Game_State) {
	biggest_val := 0
	biggest_index := 0
	for continent, index in game.tab_1.continent_sizes {
		if len(continent) > biggest_val {
			biggest_val = len(continent)
			biggest_index = index
		}
	}
	run := true
	i := 1.5
	for run {
		x := i32(((rg.random_num(&i) + 1) / 2) * 300)
		y := i32(((rg.random_num(&i) + 1) / 2) * 300)
		val, ok := (game.tab_1.continent_sizes[biggest_index])[nl.Coord{x, y}]
		if ok {
			run = false
			game.tab_1.building_area_data[x + y * game.tab_1.map_mesh.size.x] = 2

			game.tab_1.camera_real -= nl.Coord{x * 32 - 320, y * 32 - 320}
			fmt.print(game.tab_1.camera)
		}
	}
	game.events.update_fog = true
}


// all town tab stuff
draw_all_tiles :: proc(
	tile_data: $T,
	altitude: $C,
	textures_natural: [$P]string,
	textures_buildings: [$L]string,
	tile_set: [8]rl.Color,
	buildings_a_set: [8]rl.Color,
	max: nl.Coord,
	offset: nl.Coord,
	tilesize: i32,
	window: ^nl.Window_Data,
	mouse: nl.Mouse_Data,
	size: f64 = 1,
	game: ^Game_State,
) -> nl.Coord {
	multiply_color :: proc(n: f64, x: rl.Color) -> rl.Color {
		return rl.Color{u8(n * f64(x.r)), u8(n * f64(x.g)), u8(n * f64(x.b)), u8(255)}}

	draw_background_tile :: proc(
		position: nl.Coord,
		size: nl.Coord,
		window: nl.Window_Data,
		color: rl.Color,
		mouse: nl.Mouse_Data,
		highlighted: ^nl.Coord,
		coord: nl.Coord,
	) {
		nl.draw_rectangle(position = position, size = size, window = window, color = color)
		if nl.in_hitbox(pos = position, size = size, mouse = mouse) {highlighted^ = coord}
	}

	draw_edge :: proc(
		valinfront: f64,
		val: f64,
		position: nl.Coord,
		size: f64,
		window: nl.Window_Data,
		color: rl.Color,
		mouse: nl.Mouse_Data,
		highlighted: ^nl.Coord,
		coord: nl.Coord,
	) {
		size_c := nl.Coord {
			i32(32 * size) + 2,
			i32(f64(i32(val * 8) - i32(valinfront * 8)) * 16 * size) + 6,
		}
		if i32(valinfront * 8) < i32(val * 8) {
			elevated_pos := position
			elevated_pos.y += i32(f64(32) * size)

			if nl.in_hitbox(
				pos = elevated_pos,
				mouse = mouse,
				size = size_c,
			) {highlighted^ = coord}

			nl.draw_rectangle(
				position = elevated_pos,
				size = nl.Coord {
					i32(32 * size) + 1,
					i32(f64(i32(val * 8) - i32(valinfront * 8)) * 16 * size) + 1,
				},
				window = window,
				color = color,
			)
		}
	}

	smooth_water :: proc(val: f64, color_tile: ^rl.Color, tile_set: [8]rl.Color) {
		val_f := f64(int(val * 40)) / 40
		if (int(val * 8) == 1) {
			color_tile2 := tile_set[0]
			color_tile^ =
				multiply_color(val_f * 4, color_tile^) +
				multiply_color((1 - val_f * 4), color_tile2)
		}
		if (int(val * 8) == 0) {
			color_tile2 := tile_set[1]
			color_tile^ =
				multiply_color(val_f * 4, color_tile2) +
				multiply_color((1 - val_f * 4), color_tile^)
		}
	}

	draw_single_tile :: proc(
		x, y: i32,
		game: ^Game_State,
		size_c: nl.Coord,
		altitude: $T,
		window: ^nl.Window_Data,
		mouse: nl.Mouse_Data,
		tilesize: i32,
		size: f64,
		offset: nl.Coord,
		max: nl.Coord,
		textures_natural: [$P]string,
		textures_buildings: [$L]string,
		tile_set: [8]rl.Color,
		buildings_a_set: [8]rl.Color,
		highlighted: ^nl.Coord,
	) {
		val := altitude[x + y * max.x]
		fog_tile := game.tab_1.fog_data[x + y * max.x]
		building_area := game.tab_1.building_area_data[x + y * max.x]
		raised := false
		valinfront: f64 = 100
		if (y + 1 < max.y) {
			valinfront = altitude[x + (y + 1) * max.x]
		}

		elevation := i32(val * 8) * 16
		if int(val * 8) < 1 {
			elevation += 1 * 16
		}
		if game.tab_1.dev_elevation {
			elevation = 1
		}
		position := nl.Coord {
			i32(f64(x * tilesize + offset.x) * size),
			i32((f64(y * tilesize + offset.y) - f64(elevation)) * size),
		}

		draw := check_can_draw(
			position = position,
			size = size,
			offset = {game.tab_1.camera.x, game.tab_1.camera.y},
			window = window^,
		)

		if draw {
			color_tile := tile_set[int(val * 8)]
			if building_area > 0 {
				color_tile += buildings_a_set[building_area]
			}
			color_edge := multiply_color(0.6, color_tile)

			smooth_water(val, &color_tile, tile_set)
			if (fog_tile == 0) {
				color_tile = multiply_color(0.5, color_tile)
				color_edge = multiply_color(0.5, color_tile)
			} else {
			}

			draw_background_tile(
				position = position,
				size = size_c,
				window = window^,
				color = color_tile,
				mouse = mouse,
				highlighted = highlighted,
				coord = nl.Coord{x, y},
			)
			draw_edge(
				valinfront = valinfront,
				val = val,
				position = position,
				size = size,
				window = window^,
				color = color_edge,
				mouse = mouse,
				highlighted = highlighted,
				coord = nl.Coord{x, y},
			)

			if (nl.Coord{x, y} == highlighted^) {
				nl.draw_rectangle(
					position = position,
					size = nl.Coord{i32(32 * size) + 1, i32(32 * size) + 1},
					window = window^,
					color = rl.Color{150, 150, 150, 100},
				)
			}
			if fog_tile != 0 {
				if i32(32 * size) > 4 {
					if (game.tab_1.buildings_data[y * max.x + x] == 0) {
						nl.draw_png(
							position = position,
							png_name = textures_natural[game.tab_1.tile_data[y * max.x + x]],
							window = window,
							size = f32(2 * size),
							color = rl.Color{255, 255, 255, 255},
						)} else {
						nl.draw_png(
							position = position,
							png_name = textures_buildings[game.tab_1.buildings_data[y * max.x + x]],
							window = window,
							size = f32(2 * size),
							color = rl.Color{255, 255, 255, 255},
						)
					}
				}

			}

		}
	}


	size_c := nl.Coord{i32(32 * size) + 2, i32(32 * size) + 2}

	highlighted := nl.Coord{-1, 0}
	pos := 0
	for y in 0 ..< max.y {
		for x in 0 ..< max.x {
			draw_single_tile(
				x = x,
				y = y,
				game = game,
				size_c = size_c,
				altitude = altitude,
				tilesize = 32,
				size = size,
				offset = offset,
				textures_natural = textures_natural,
				textures_buildings = textures_buildings,
				tile_set = tile_set,
				buildings_a_set = buildings_a_set,
				max = max,
				window = window,
				mouse = mouse,
				highlighted = &highlighted,
			)
		}
	}
	return highlighted
}

generate_objects :: proc(game: ^Game_State) {
	gen_seed: i64 = 15124
	rg.generate_objects_i32(
		mesh = game.tab_1.map_mesh,
		array = &game.tab_1.tile_data,
		percentage = 0.7,
		range = {0.15, 1},
		set = 2,
		seed = &gen_seed,
		target = nl.Coord{1, 8},
		zoom = 16,
	)
	rg.generate_objects_list_i32(
		mesh = game.tab_1.map_mesh,
		array = &game.tab_1.tile_data,
		percentage = 0.2,
		range = {0.25, 0.8},
		set = [?]i32{2, 3, 4, 5, 6},
		seed = &gen_seed,
		target = nl.Coord{1, 8},
		zoom = 8,
	)
	rg.generate_objects_i32(
		mesh = game.tab_1.map_mesh,
		array = &game.tab_1.tile_data,
		percentage = 0.6,
		range = {0.8, 1},
		set = 1,
		seed = &gen_seed,
		target = nl.Coord{1, 8},
	)
	rg.generate_objects_i32(
		mesh = game.tab_1.map_mesh,
		array = &game.tab_1.tile_data,
		percentage = 0.2,
		range = {0.25, 1},
		set = 1,
		seed = &gen_seed,
		target = nl.Coord{1, 8},
	)

}
// yes i do want a sepeate function for this
set_icon :: proc() {
	icon_filepath := filepath.join([]string{"assets", "ball.png"})
	icon_filepath_c: cstring = strings.clone_to_cstring(icon_filepath)
	rl.SetWindowIcon(rl.LoadImage(icon_filepath_c))
	delete(icon_filepath)
	delete(icon_filepath_c)
}

display_icon_text :: proc(
	png: string,
	text: string,
	position: nl.Coord,
	offset: nl.Coord,
	font_size: f32,
	window: ^nl.Window_Data,
) {
	nl.draw_png(position = position, png_name = png, window = window, size = 2)
	nl.draw_text(
		text = text,
		position = position + offset,
		spacing = 3,
		color = rl.Color{200, 200, 200, 240},
		fontSize = font_size,
		window = window^,
	)
}

building_select_tab :: proc(game: ^Game_State, window: ^nl.Window_Data, mouse: nl.Mouse_Data) {
	building_button :: proc(
		position: nl.Coord,
		png_name, hold_png, hover_info: string,
		set_hold: i32,
		game: ^Game_State,
		mouse: nl.Mouse_Data,
		window: ^nl.Window_Data,
	) {
		clicked, hover := nl.button_png_auto(
			position = position,
			hitbox = nl.Coord{32, 32},
			png_name = png_name,
			window = window,
			mouse = mouse,
			size = 2,
		)
		if clicked {game.tab_1.hold = hold_png;game.tab_1.hold_t = set_hold}
		if hover {game.tab_1.building_info = hover_info}

	}
	building_button(
		position = nl.Coord{10, 200},
		png_name = "house_bt_",
		hold_png = "house_lv0.png",
		set_hold = 1,
		game = game,
		mouse = mouse,
		window = window,
		hover_info = "House",
	)
	building_button(
		position = nl.Coord{42, 200},
		png_name = "tower_bt_",
		hold_png = "tower.png",
		set_hold = 2,
		game = game,
		mouse = mouse,
		window = window,
		hover_info = "Watch Tower",
	)
	building_button(
		position = nl.Coord{74, 200},
		png_name = "woodmill_bt_",
		hold_png = "woodmill.png",
		set_hold = 3,
		game = game,
		mouse = mouse,
		window = window,
		hover_info = "Woodmill",
	)
	building_button(
		position = nl.Coord{106, 200},
		png_name = "mine_bt_",
		hold_png = "mine_lv0.png",
		set_hold = 4,
		game = game,
		mouse = mouse,
		window = window,
		hover_info = "Mine",
	)
	building_button(
		position = nl.Coord{138, 200},
		png_name = "field_bt_",
		hold_png = "field.png",
		set_hold = 5,
		game = game,
		mouse = mouse,
		window = window,
		hover_info = "Field",
	)
	nl.draw_text(
		game.tab_1.building_info,
		nl.Coord{10, 300},
		1,
		rl.Color{255, 255, 255, 255},
		10,
		window^,
	)
}


town_tab :: proc(
	game: ^Game_State,
	window: ^nl.Window_Data,
	mouse: nl.Mouse_Data,
	shader: rl.Shader,
) {

	set_town :: proc(game: ^Game_State, tile: nl.Coord) {
		ok := bool(game.tab_1.fog_data[tile.x + tile.y * game.tab_1.map_mesh.size.x])
		if (game.tab_1.hold != "") && ok {
			tile_index: i32 = game.tab_1.map_mesh.size.x * tile.y + tile.x
			game.tab_1.building_area_data[tile_index] = game.tab_1.hold_t
			game.events.update_fog = true
		}
	}

	set_selecton :: proc(game: ^Game_State) {
		selection := game.tab_1.selection_area
		if selection.y > selection.w {selection.yw = selection.wy}
		if selection.x > selection.z {selection.xz = selection.zx}
		for y in selection.y ..= selection.w {
			for x in selection.x ..= selection.z {
				set_town(game, nl.Coord{x, y})
			}
		}
		game.tab_1.hold = ""
		game.tab_1.hold_t = 0
	}

	update_fog :: proc(game: ^Game_State) {
		fog_kernel :: proc(
			min: nl.Coord,
			max: nl.Coord,
			size: nl.Coord,
			array: ^[]i32,
			max_dist: i32,
			set: i32,
		) {
			delta := max - min
			center := (delta) / nl.Coord{2, 2}
			for y in 0 ..< delta.y {
				for x in 0 ..< delta.x {
					pos := x + min.x + (y + min.y) * size.x
					if pos > 0 && pos < size.x * size.y {
						distance :=
							(center.x - x) * (center.x - x) + (center.y - y) * (center.y - y)
						if math.sqrt(f64(distance)) < f64(max_dist) {
							array[pos] = set
						}

					}
				}
			}
		}
		if game.events.update_fog {
			game.events.update_fog = false
			mesh_max := game.tab_1.map_mesh.size
			for y in 0 ..< mesh_max.y {
				for x in 0 ..< mesh_max.x {
					building := game.tab_1.buildings_data[x + y * mesh_max.x]
					if building == 2 {
						s: i32 = 10
						min := nl.Coord{x - s, y - s}
						max := nl.Coord{x + s, y + s}
						fog_kernel(
							min = min,
							max = max,
							size = mesh_max,
							array = &game.tab_1.fog_data,
							max_dist = s,
							set = 1,
						)
					}
				}
			}

		}
	}


	print_coord_mouse :: proc(on_tile_pos: nl.Coord, window: nl.Window_Data) {

		buffer: [16]u8
		temp_string := fmt.bprintf(buffer[:], "X %d, Y %d", on_tile_pos.x, on_tile_pos.y)
		nl.draw_text(
			text = temp_string,
			position = nl.Coord{300, 380},
			spacing = 5,
			color = rl.Color{50, 50, 50, 255},
			fontSize = 20,
			window = window,
		)

	}

	display_stats :: proc(game: Game_State, window: ^nl.Window_Data) {
		buffer: [16]u8
		temp_string := od.print(&buffer, game.global.oid)
		display_icon_text(
			png = "oid.png",
			text = temp_string,
			position = nl.Coord{70, 8},
			offset = nl.Coord{35, 8},
			font_size = 16,
			window = window,
		)
		temp_string = od.print(&buffer, game.global.wood)
		display_icon_text(
			png = "wood.png",
			text = temp_string,
			position = nl.Coord{70, 48},
			offset = nl.Coord{35, 8},
			font_size = 16,
			window = window,
		)
		temp_string = od.print(&buffer, game.global.stone)
		display_icon_text(
			png = "stone.png",
			text = temp_string,
			position = nl.Coord{70, 88},
			offset = nl.Coord{35, 8},
			font_size = 16,
			window = window,
		)
		temp_string = od.print(&buffer, game.global.food)
		display_icon_text(
			png = "food.png",
			text = temp_string,
			position = nl.Coord{70, 128},
			offset = nl.Coord{35, 8},
			font_size = 16,
			window = window,
		)
	}

	buildings_manager :: proc(
		on_tile_pos: nl.Coord,
		game: ^Game_State,
		window: ^nl.Window_Data,
		mouse: nl.Mouse_Data,
	) {
		valid_tile := false
		if on_tile_pos.x >= 0 {
			if on_tile_pos.y >= 0 {
				if on_tile_pos.x < game.tab_1.map_mesh.size.x {
					if on_tile_pos.y < game.tab_1.map_mesh.size.y {
						valid_tile = true
					}}}}
		nl.draw_png(position = mouse.pos, png_name = game.tab_1.hold, window = window, size = 2)
		if (valid_tile) {
			if (mouse.clicking && !game.tab_1.selecting) {
				game.tab_1.selection_area.xy = on_tile_pos
				game.tab_1.selecting = true
			}
			if (mouse.hold && game.tab_1.selecting) {
				game.tab_1.selection_area.zw = on_tile_pos
			}
			if (!mouse.hold && game.tab_1.selecting) {
				game.tab_1.selection_area.zw = on_tile_pos
				set_selecton(game)
				game.tab_1.selecting = false
			}
		}

		building_select_tab(game = game, window = window, mouse = mouse)
	}

	display_tiles :: proc(
		game: ^Game_State,
		on_tile_pos: ^nl.Coord,
		shader: rl.Shader,
		window: ^nl.Window_Data,
		mouse: nl.Mouse_Data,
	) {
		tile_set_natural := [?]string {
			"",
			"boulders.png",
			"grass.png",
			"tree1.png",
			"tree2.png",
			"tree3.png",
			"tree5.png",
		}
		tile_set_buildings := [?]string {
			"",
			"house_lv0.png",
			"tower.png",
			"woodmill.png",
			"mine_lv0.png",
			"field.png",
		}
		offset_tiles := nl.Coord{295, 0} + game.tab_1.camera
		if !game.tab_1.dev_see {
			nl.begin_draw_area(nl.Coord{295, 0}, nl.Coord{19, 13} * nl.Coord{32, 32}, window^)
			rl.BeginShaderMode(shader)
			on_tile_pos^ = draw_all_tiles(
				tile_data = game.tab_1.tile_data,
				altitude = game.tab_1.map_mesh.array,
				tile_set = {
					rl.Color{25, 25, 35, 255},
					rl.Color{25, 25, 125, 255},
					rl.Color{25, 65, 25, 255},
					rl.Color{25, 75, 45, 255},
					rl.Color{85, 125, 85, 255},
					rl.Color{105, 105, 85, 255},
					rl.Color{125, 125, 125, 255},
					rl.Color{165, 165, 165, 255},
				},
				buildings_a_set = {
					rl.Color{25, 25, 35, 255},
					rl.Color{25, 25, 125, 255},
					rl.Color{25, 65, 25, 255},
					rl.Color{25, 75, 45, 255},
					rl.Color{85, 125, 85, 255},
					rl.Color{105, 105, 85, 255},
					rl.Color{125, 125, 125, 255},
					rl.Color{165, 165, 165, 255},
				},
				textures_natural = tile_set_natural,
				textures_buildings = tile_set_buildings,
				max = nl.Coord{300, 300},
				offset = offset_tiles,
				tilesize = 32,
				window = window,
				size = game.tab_1.camera_zoom,
				mouse = mouse,
				game = game,
			)
			rl.EndShaderMode()
			rl.EndScissorMode()
		}
	}

	camera_manager :: proc(game: ^Game_State) {
		sum_velocity :=
			game.tab_1.camera_vel.x * game.tab_1.camera_vel.x +
			game.tab_1.camera_vel.y * game.tab_1.camera_vel.y
		if (sum_velocity > 1) {
			game.tab_1.camera_real += nl.Coord {
				i32(f64(game.tab_1.camera_vel.x) * game.tab_1.camera_zoom),
				i32(f64(game.tab_1.camera_vel.y) * game.tab_1.camera_zoom),
			}
			if !game.slide {
				game.tab_1.camera_vel.x = i32(f64(game.tab_1.camera_vel.x) * 0.999)
				game.tab_1.camera_vel.y = i32(f64(game.tab_1.camera_vel.y) * 0.999)
			}
		}
		game.tab_1.camera = nl.Coord {
			i32(f64(game.tab_1.camera_real.x) - (605.0 - 605.0 / game.tab_1.camera_zoom)),
			i32(f64(game.tab_1.camera_real.y) - (400.0 - 400.0 / game.tab_1.camera_zoom) / 2),
		}
	}

	draw_town_background :: proc(window: nl.Window_Data) {
		nl.draw_rectangle(nl.Coord{285, 0}, nl.Coord{10, 400}, window, rl.Color{33, 31, 50, 255})
		rl.BeginBlendMode(rl.BlendMode.SUBTRACT_COLORS)
		nl.draw_rectangle(
			nl.Coord{295, 0},
			nl.Coord{19, 13} * nl.Coord{32, 32},
			window,
			rl.Color{10, 10, 10, 255},
		)
		rl.EndBlendMode()

	}

	on_tile_pos: nl.Coord
	camera_manager(game = game)
	update_fog(game)
	draw_town_background(window = window^)
	display_tiles(game, &on_tile_pos, shader, window, mouse)
	display_stats(game^, window)
	buildings_manager(on_tile_pos = on_tile_pos, game = game, window = window, mouse = mouse)
	print_coord_mouse(on_tile_pos, window^)
	// display resources


}

side_bar_tab :: proc(window: ^nl.Window_Data, mouse: nl.Mouse_Data, game: ^Game_State) {
	if nl.button_png_t(
		position = nl.Coord{0, 0},
		hitbox = nl.Coord{64, 64},
		png_name = [3]string{"tab_setting_1.png", "tab_setting_2.png", "tab_setting_3.png"},
		window = window,
		mouse = mouse,
		size = 2,
	) {game.tab_state = 0}
	if nl.button_png_t(
		position = nl.Coord{0, 64},
		hitbox = nl.Coord{64, 64},
		png_name = [3]string{"tab_town_1.png", "tab_town_2.png", "tab_town_3.png"},
		window = window,
		mouse = mouse,
		size = 2,
	) {game.tab_state = 1}

}

process_inputs :: proc(game: ^Game_State) {
	if (game.tab_state == 0) {
		if rl.IsKeyPressed((rl.KeyboardKey.M)) {
			game.tab_1.dev_see = game.tab_1.dev_see != true
			fmt.println("dev seek: map")
		}
		if rl.IsKeyPressed((rl.KeyboardKey.E)) {
			game.tab_1.dev_see = game.tab_1.dev_see != true
			fmt.println("dev seek: elevation")
		}
	} else if (game.tab_state == 1) {
			// odinfmt: disable
		if rl.IsKeyDown(
			rl.KeyboardKey.A,
		) 
    {game.tab_1.camera_vel.x += 1;game.slide = true} else if rl.IsKeyDown(rl.KeyboardKey.D) 
    {game.tab_1.camera_vel.x -= 1;game.slide = true} else if rl.IsKeyDown(rl.KeyboardKey.W) 
    {game.tab_1.camera_vel.y += 1;game.slide = true} else if rl.IsKeyDown(rl.KeyboardKey.S) 
    {game.tab_1.camera_vel.y -= 1;game.slide = true} else {game.slide = false}
		// odinfmt: enable
		resize := f64(rl.GetMouseWheelMove())
		if resize != 0 {
			resize = resize * 0.05 * game.tab_1.camera_zoom_speed * 3
			old_z: f64
			if (resize < 0) {
				game.tab_1.camera_zoom *= (-resize) + 1
				// zoom_a := game.tab_1.camera_zoom
				// margin: [2]f64 = {605.0, 400.0} / {4, 4} * {zoom_a, zoom_a}
				// game.tab_1.camera -= {i32(margin.x), i32(margin.y)}
			} else {
				game.tab_1.camera_zoom /= resize + 1
				// zoom_a := game.tab_1.camera_zoom
				// margin: [2]f64 = {605.0, 400.0} / {2, 2} * {zoom_a, zoom_a}
				// game.tab_1.camera += {i32(margin.x), i32(margin.y)}
			}
		}}
}

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	Screen_Width :: 900
	Screen_Height :: 400

	rl.InitWindow(Screen_Width, Screen_Height, "ETERNALOID")
	rl.SetTargetFPS(60)
	rl.SetWindowState(rl.ConfigFlags{.WINDOW_RESIZABLE})
	// rl.SetWindowState(rl.ConfigFlags{.WINDOW_ALWAYS_RUN})
	set_icon()
	window := nl.Window_Data {
		original_size   = nl.Coord{Screen_Width, Screen_Height},
		present_size    = nl.Coord{Screen_Width, Screen_Height},
		image_cache_map = make(map[string]rl.Texture),
		font            = rl.LoadFont("assets\\BigBlueTerm437NerdFont-Regular.ttf"),
	}
	mouse := nl.Mouse_Data {
		pos         = nl.Coord{0, 0},
		virtual_pos = nl.Coord{0, 0},
		clicking    = false,
	}


	global_resources := Global_Data {
		oid          = od.bigfloat{0, 0},
		oid_max      = od.bigfloat{0, 0},
		wood         = od.bigfloat{5, 3},
		stone        = od.bigfloat{0, 0},
		food         = od.bigfloat{0, 0},
		global_speed = od.bigfloat{1, 0},
		town_speed   = od.bigfloat{0, 0},
	}
	global_resource_managers := Global_Resource {
		oid = rsc.Resource_Manager {
			output = &global_resources.oid,
			base = make_slice([]od.bigfloat, 1),
			multiplier = make_slice([]od.bigfloat, 0),
			exponent = make_slice([]od.bigfloat, 0),
			cached_income = od.bigfloat{0, 0},
			external_multiplier = &global_resources.town_speed,
		},
		wood = rsc.Resource_Manager {
			output = &global_resources.wood,
			base = make_slice([]od.bigfloat, 1),
			multiplier = make_slice([]od.bigfloat, 0),
			exponent = make_slice([]od.bigfloat, 0),
			cached_income = od.bigfloat{0, 0},
			external_multiplier = &global_resources.town_speed,
		},
		stone = rsc.Resource_Manager {
			output = &global_resources.stone,
			base = make_slice([]od.bigfloat, 1),
			multiplier = make_slice([]od.bigfloat, 0),
			exponent = make_slice([]od.bigfloat, 0),
			cached_income = od.bigfloat{0, 0},
			external_multiplier = &global_resources.town_speed,
		},
		food = rsc.Resource_Manager {
			output = &global_resources.food,
			base = make_slice([]od.bigfloat, 1),
			multiplier = make_slice([]od.bigfloat, 0),
			exponent = make_slice([]od.bigfloat, 0),
			cached_income = od.bigfloat{0, 0},
			external_multiplier = &od.bigfloat{1, 0},
		},
	}

	seed: i64
	buf: [32]u8
	rg.hash_string(tim.time_to_string_hms(tim.now(), buf[:]), &seed)

	game := Game_State {
		global = &global_resources,
		global_m = global_resource_managers,
		seed = f64(seed),
		tab_state = 1,
		tab_1 = Game_Tab_1 {
			hold = "",
			tile_data = make_slice([]i32, 300 * 300),
			fog_data = make_slice([]i32, 300 * 300),
			buildings_data = make_slice([]i32, 300 * 300),
			building_area_data = make_slice([]i32, 300 * 300),
			map_mesh = rg.create_mesh_custom({300, 300}, 300, seed),
			continent_sizes = make([dynamic]map[[2]i32][2]i32),
			camera_zoom = 1,
			camera_zoom_speed = 0.3,
			built_max = 2,
		},
	}
	generate_objects(&game)

	global_map := make(map[[2]i32]bool)
	for y in 0 ..< game.tab_1.map_mesh.size.y {
		for x in 0 ..< game.tab_1.map_mesh.size.x {
			valid, ok := global_map[nl.Coord{x, y}]
			if !ok {
				highlighted_bfd, okm := rg.bfd(
					&global_map,
					nl.Coord{x, y},
					game.tab_1.map_mesh,
					0.25,
				)
				if okm {
					append(&game.tab_1.continent_sizes, highlighted_bfd)
				}
			}

		}

	}

	generate_spawn(&game)

	game.tab_1.test_data = &global_map
	shader := rl.LoadShader("", "shaders/pixel_filter.glsl")
	defer rl.UnloadShader(shader)
	game.events.update_town = true
	for !rl.WindowShouldClose() {


		if rl.IsWindowResized() {
			window.present_size = nl.Coord{rl.GetScreenWidth(), rl.GetScreenHeight()}
		}
		process_inputs(&game)
		nl.update_mouse(&mouse, window)

		rl.BeginDrawing()
		rl.ClearBackground(rl.Color{49, 36, 58, 255})

		side_bar_tab(&window, mouse, &game)
		if (game.tab_state == 0) {
			settings_tab(window = &window, mouse = mouse, game = &game)
		} else if (game.tab_state == 1) {
			town_tab(game = &game, window = &window, mouse = mouse, shader = shader)
		}
		nl.draw_borders(window)
		rl.EndDrawing()
		animate_textures(window = &window, frame = game.frame)
		global(&game)
		game.frame += 1
	}
	delete(window.image_cache_map)
	delete(game.tab_1.tile_data)
	delete(game.tab_1.buildings_data)
	delete(game.tab_1.building_area_data)
	delete(game.tab_1.fog_data)
	delete(game.tab_1.map_mesh.array)
	delete(game.global.entities)
	for continent in game.tab_1.continent_sizes {
		delete(continent)
	}
	delete(game.tab_1.continent_sizes)
	delete(global_map)

	delete(global_resource_managers.oid.base)
	delete(global_resource_managers.oid.multiplier)
	delete(global_resource_managers.oid.exponent)
	delete(global_resource_managers.wood.base)
	delete(global_resource_managers.wood.multiplier)
	delete(global_resource_managers.wood.exponent)
	delete(global_resource_managers.food.base)
	delete(global_resource_managers.food.multiplier)
	delete(global_resource_managers.food.exponent)
	delete(global_resource_managers.stone.base)
	delete(global_resource_managers.stone.multiplier)
	delete(global_resource_managers.stone.exponent)
}

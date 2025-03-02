package nlib

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

window_data :: struct {
	original_width:  i32,
	original_height: i32,
	present_width:   i32,
	present_height:  i32,
	image_cache_map: map[image_key]rl.Texture,
}

image_key :: struct {
	string_key: string,
	size_key:   f32,
}

get_virtual_window :: proc(window: ^window_data) -> (i32, i32, f64) {
	width_ratio := f64(window.present_width) / f64(window.original_width)
	height_ratio := f64(window.present_height) / f64(window.original_height)

	ratio: f64
	ratio = min(height_ratio, width_ratio)

	v_width := i32(f64(window.original_width) * ratio)
	v_height := i32(f64(window.original_height) * ratio)

	return v_width, v_height, ratio
}

get_virtual_x_y_ratio :: proc(x: i32, y:i32, window: ^window_data) -> (i32, i32, f64){
	virtual_width, virtual_height, virtual_ratio := get_virtual_window(window)
	padding_x := (window.present_width - virtual_width) / 2
	padding_y := (window.present_height - virtual_height) / 2
	virtual_x := i32(f64(x) * virtual_ratio) + padding_x
	virtual_y := i32(f64(y) * virtual_ratio) + padding_y

  return virtual_x, virtual_y, virtual_ratio
}

acquire_texture :: proc(image_name: string) -> rl.Texture {
	image_name_C: cstring = strings.clone_to_cstring(image_name)
	texture: rl.Texture = rl.LoadTexture(image_name_C)
	delete(image_name_C)
	return texture
}

pull_texture :: proc(
	image_name: string,
	image_cache_map: ^map[image_key]rl.Texture,
	size: f32,
) -> rl.Texture {
	cache_key := image_key {
		string_key = image_name,
		size_key   = size,
	}
	cached_texture, ok := image_cache_map[cache_key]
	if ok {
		return cached_texture

	} else {
		texture := acquire_texture(image_name)
		image_cache_map[cache_key] = texture
		return texture
	}
}

draw_png :: proc(x: i32, y: i32, png_name: string, window: ^window_data, size: f32 = 1) {
	texture: rl.Texture = pull_texture(png_name, &window.image_cache_map, size)
  virtual_x, virtual_y, virtual_ratio = get_virtual_x_y_ratio()
	rl.DrawTextureEx(
		texture,
		rl.Vector2{f32(virtual_x), f32(virtual_y)},
		0,
		size * f32(virtual_ratio),
		rl.Color{255, 255, 255, 255},
	)
}


draw_rectangle :: proc(
	x: i32,
	y: i32,
	width: i32,
	height: i32,
	window: ^window_data,
	color: rl.Color,
) {
	virtual_width, virtual_height, virtual_ratio := get_virtual_window(window)
	padding_x := (window.present_width - virtual_width) / 2
	padding_y := (window.present_height - virtual_height) / 2
	virtual_x := i32(f64(x) * virtual_ratio) + padding_x
	virtual_y := i32(f64(y) * virtual_ratio) + padding_y
	rl.DrawRectangle(
		i32(virtual_x),
		i32(virtual_y),
		i32(f64(width) * virtual_ratio),
		i32(f64(height) * virtual_ratio),
		color,
	)
}


draw_borders :: proc(window: ^window_data) {
	virtual_width, virtual_height, virtual_ratio := get_virtual_window(window)
	padding_x := (window.present_width - virtual_width) / 2
	padding_y := (window.present_height - virtual_height) / 2
	rl.DrawRectangle(
		i32(0),
		i32(0),
		i32(padding_x),
		i32(window.present_height),
		rl.Color{0, 0, 0, 255},
	)
	rl.DrawRectangle(
		i32(padding_x + virtual_width),
		i32(0),
		i32(padding_x),
		i32(window.present_height),
		rl.Color{0, 0, 0, 255},
	)
	rl.DrawRectangle(
		i32(0),
		i32(0),
		i32(window.present_width),
		i32(padding_y),
		rl.Color{0, 0, 0, 255},
	)
	rl.DrawRectangle(
		i32(0),
		i32(padding_y + virtual_height),
		i32(window.present_width),
		i32(padding_y),
		rl.Color{0, 0, 0, 255},
	)


}

button_png_static :: proc(x: i32, y: i32, png_name: string, window: ^window_data, size: f32 = 1) -> {
	texture: rl.Texture = pull_texture(png_name, &window.image_cache_map, size)
	virtual_width, virtual_height, virtual_ratio := get_virtual_window(window)
	padding_x := (window.present_width - virtual_width) / 2
	padding_y := (window.present_height - virtual_height) / 2
	virtual_x := i32(f64(x) * virtual_ratio) + padding_x
	virtual_y := i32(f64(y) * virtual_ratio) + padding_y
	rl.DrawTextureEx(
		texture,
		rl.Vector2{f32(virtual_x), f32(virtual_y)},
		0,
		size * f32(virtual_ratio),
		rl.Color{255, 255, 255, 255},
	)
}

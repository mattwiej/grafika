package main

import "core:fmt"
import "core:math"


Dodawanie_punktowe :: proc(data: ^ImageBuffer_models, val: i32, state: ^State_models) {

	switch array in &data.maxVal {
	case [dynamic]u8:
		for &pixel in array {
			temp := i32(pixel) + val
			pixel = u8(math.clamp(temp, 0, 255))
		}

	case [dynamic]u16:
		for &pixel in array {
			temp := i32(pixel) + val
			pixel = u16(math.clamp(temp, 0, 65535))
		}

	}
	state.loadNewTexture = true
}

Odejmowanie_Punktowe :: proc(data: ^ImageBuffer_models, val: i32, state: ^State_models) {

	switch array in &data.maxVal {
	case [dynamic]u8:
		for &pixel in array {
			temp := i32(pixel) - val
			pixel = u8(math.clamp(temp, 0, 255))
		}

	case [dynamic]u16:
		for &pixel in array {
			temp := i32(pixel) - val
			pixel = u16(math.clamp(temp, 0, 65535))
		}

	}
	state.loadNewTexture = true
}
Mnozenie_Punktowe :: proc(data: ^ImageBuffer_models, val: i32, state: ^State_models) {

	switch array in &data.maxVal {
	case [dynamic]u8:
		for &pixel in array {
			temp := i32(pixel) * val
			pixel = u8(math.clamp(temp, 0, 255))
		}

	case [dynamic]u16:
		for &pixel in array {
			temp := i32(pixel) * val
			pixel = u16(math.clamp(temp, 0, 65535))
		}

	}
	state.loadNewTexture = true
}

Dzielenie_Punktowe :: proc(data: ^ImageBuffer_models, val: i32, state: ^State_models) {

	if val == 0 {
		return
	}
	switch array in &data.maxVal {
	case [dynamic]u8:
		for &pixel in array {
			temp := i32(pixel) / val
			pixel = u8(math.clamp(temp, 0, 255))
		}

	case [dynamic]u16:
		for &pixel in array {
			temp := i32(pixel) / val
			pixel = u16(math.clamp(temp, 0, 65535))
		}

	}
	state.loadNewTexture = true
}
ConvertToGrayscale :: proc(img: ^ImageBuffer_models, weighted: bool = true) {
	if img.channelCount == 1 {
		fmt.println("Image is already grayscale")
		return
	}

	switch old_pixels in &img.maxVal {
	case [dynamic]u8:
		length := len(old_pixels)
		new_length := length / 3

		new_pixels := make([dynamic]u8, new_length)

		write_idx := 0
		for i := 0; i < length; i += 3 {
			r := f32(old_pixels[i])
			g := f32(old_pixels[i + 1])
			b := f32(old_pixels[i + 2])

			gray_val: u8
			if weighted {
				gray_val = u8(math.clamp(0.299 * r + 0.587 * g + 0.114 * b, 0, 255))
			} else {
				gray_val = u8(math.clamp((r + g + b) / 3.0, 0, 255))
			}

			new_pixels[write_idx] = gray_val
			write_idx += 1
		}

		delete(old_pixels)

		img.maxVal = new_pixels
		img.channelCount = 1

		img.hist = nil

	case [dynamic]u16:
		// Analogicznie dla u16...
		return
	}
}

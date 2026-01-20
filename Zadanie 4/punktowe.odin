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

SzaroscSrednia_Punktowe :: proc(data: ^ImageBuffer_models, state: ^State_models) {
	switch array in &data.maxVal {
	case [dynamic]u8:
		ptr := raw_data(array)
		length := len(array)

		gray := make([dynamic]u8, length / 3)
		grayPtr := raw_data(gray)
		grayIdx: i64 = 0
		for i := 0; i <= length - 3; i += 3 {
			grayPixel := u8((i32(ptr[i]) + i32(ptr[i + 1]) + i32(ptr[i + 2])) / 3)
			grayPtr[grayIdx] = grayPixel
			grayIdx += 1
		}
		state.grayScale8 = gray
	case [dynamic]u16:
		ptr := raw_data(array)
		length := len(array)

		gray := make([dynamic]u16, length / 3)
		grayPtr := raw_data(gray)
		grayIdx: i64 = 0
		for i := 0; i <= length - 3; i += 3 {
			grayPixel := u16((i64(ptr[i]) + i64(ptr[i + 1]) + i64(ptr[i + 2])) / 3)
			grayPtr[grayIdx] = grayPixel
			grayIdx += 1
		}
		state.grayScale16 = gray
	}
}

SzaroscSredniaWazona_Punktowe :: proc(data: ^ImageBuffer_models, state: ^State_models) {
	switch array in &data.maxVal {
	case [dynamic]u8:
		ptr := raw_data(array)
		length := len(array)

		gray := make([dynamic]u8, length / 3)
		grayPtr := raw_data(gray)
		grayIdx: i64 = 0
		for i := 0; i <= length - 3; i += 3 {
			grayPixel := u8(
				0.2126 * f32(ptr[i]) + 0.7152 * f32(ptr[i + 1]) + 0.0722 * f32(ptr[i + 2]),
			)
			grayPtr[grayIdx] = grayPixel
			grayIdx += 1
		}
		state.grayScale8 = gray
	case [dynamic]u16:
		ptr := raw_data(array)
		length := len(array)

		gray := make([dynamic]u16, length / 3)
		grayPtr := raw_data(gray)
		grayIdx: i64 = 0
		for i := 0; i <= length - 3; i += 3 {
			grayPixel := u16(
				0.2126 * f32(ptr[i]) + 0.7152 * f32(ptr[i + 1]) + 0.0722 * f32(ptr[i + 2]),
			)
			grayPtr[grayIdx] = grayPixel
			grayIdx += 1
		}
		state.grayScale16 = gray
	}
}

package main

import rl "vendor:raylib"

RGB_models :: struct {
	r: f32,
	g: f32,
	b: f32,
}

CMYK_models :: struct {
	C: f32,
	M: f32,
	Y: f32,
	K: f32,
}


State_models :: struct {
	buffer:        [32]u8,
	bufferLen:     int,
	showModes:     bool,
	activeInputId: u32,
	///
	rgb:           RGB_models,
	cmyk:          CMYK_models,
	rgbFlag:       bool,
	cmykFlag:      bool,
}

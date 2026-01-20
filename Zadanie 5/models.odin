package main

import rl "vendor:raylib"


State_models :: struct {
	buffer:        [32]u8,
	bufferLen:     int,
	showModes:     bool,
	activeInputId: u32,
}

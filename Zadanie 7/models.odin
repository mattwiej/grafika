package main

import rl "vendor:raylib"

Mode :: enum {
	select,
	draw,
}

PolygonManipulation :: enum {
	move,
	rotate,
	scale,
}

Polygon_models :: struct {
	vertices: [dynamic]rl.Vector2,
	color:    rl.Color,
}


State :: struct {
	selectedIdx:   int,
	shapes:        [dynamic]Polygon_models,
	isDragging:    bool,
	currentMode:   Mode,
	showModes:     bool,
	//
	activeInputId: u32,
	buffer:        [32]u8,
	bufferLen:     int,
	//
	isDrawing:     bool,
	//
}

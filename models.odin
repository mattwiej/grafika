package main

Mode :: enum {
	select,
	drawRect,
	drawLine,
	drawCircle,
}

LineData :: struct {
	start, end: [2]f32,
}
RectData :: struct {
	start, size: [2]f32,
}
CircleData :: struct {
	center: [2]f32,
	radius: f32,
}

Shape :: struct {
	id:    u32,
	color: [4]u8,
	kind:  union {
		LineData,
		RectData,
		CircleData,
	},
}

State :: struct {
	shapes:          [dynamic]Shape,
	nextId:          u32,
	selectedIdx:     int,
	currentMode:     Mode,
	showModes:       bool,
	showShapeInfo:   bool,
	//
	bufX:            [64]u8,
	bufY:            [64]u8,
	bufW:            [64]u8,
	bufH:            [64]u8,
	bufColor:        [4]u8,
	specialPoints:   [8]f32,
	//
	isDrawing:       bool,
	drawingStartPos: [2]f32,
}

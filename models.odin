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
	shapes:             [dynamic]Shape,
	nextId:             u32,
	selectedIdx:        int,
	currentMode:        Mode,
	showModes:          bool,
	showShapeInfo:      bool,
	//
	activeInputId:      u32,
	buffer:             [32]u8,
	bufferLen:          int,
	bufColor:           [4]u8,
	specialPoints:      [8]f32,
	specialPointsCount: u8,
	//
	isDrawing:          bool,
	drawingStartPos:    [2]f32,
	editBuffer:         [64]u8, // Bufor na tekst edycji
	editLen:            int, // Długość tekstu w buforze
}

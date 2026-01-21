package main

Mode :: enum {
	select,
	draw,
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

Point :: struct {
	x, y: f32,
}


State :: struct {
	bezierOrder:        int,
	controlPointsCount: int,
	controlPoints:      [dynamic]Point,
	selectedIdx:        int,
	isDragging:         bool,
	currentMode:        Mode,
	showModes:          bool,
	//
	activeInputId:      u32,
	buffer:             [32]u8,
	bufferLen:          int,
	//
	isDrawing:          bool,
	//
}

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
HandleType :: enum {
	None,
	// Dla Linii
	LineStart,
	LineEnd,
	// Dla Prostokąta (P1=Góra, P2=Prawo, P3=Dół, P4=Lewo)
	RectTop, // P1
	RectRight, // P2
	RectBottom, // P3
	RectLeft, // P4
	// Dla Koła
	CircleRadius,
}

State :: struct {
	shapes:                  [dynamic]Shape,
	nextId:                  u32,
	selectedIdx:             int,
	draggedHandle:           HandleType, // Który punkt aktualnie trzymamy
	isDragging:              bool,
	currentMode:             Mode,
	showModes:               bool,
	showShapeInfo:           bool,
	//
	activeInputId:           u32,
	buffer:                  [32]u8,
	bufferLen:               int,
	bufColor:                [4]u8,
	//
	isDrawing:               bool,
	drawingStartPos:         [2]f32,
	editBuffer:              [64]u8, // Bufor na tekst edycji
	editLen:                 int, // Długość tekstu w buforze
	tempX:                   f32,
	tempY:                   f32,
	tempW:                   f32, // Szerokość lub X końcowe
	tempH:                   f32, // Wysokość lub Y końcowe
	tempR:                   f32, // Promień
	//
	showUnsavedChangesModal: bool,
	pendingLoad:             bool,
}

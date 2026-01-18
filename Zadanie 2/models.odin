package main

import rl "vendor:raylib"


State_models :: struct {
	currentImage:       ImageBuffer_models,
	texture:            rl.Texture2D,
	zoom:               f32,
	panOffset:          rl.Vector2,
	compressionQuality: int,
	errorState:         ImageError_models,
}

ImageBuffer_models :: struct {
	width:      i32,
	height:     i32,
	format:     FileFormat_models,
	maxVal:     MaxVal_models,
	maxValFlag: i32,
}

MaxVal_models :: union {
	[dynamic]u8,
	[dynamic]u16,
}

FileFormat_models :: enum {
	PPM_P3,
	PPM_P6,
	JPG,
}

ImageError_models :: enum {
	None,
	FileNotFound,
	InvalidFormat,
	CorruptedData,
	UnsupportedDimensions,
}

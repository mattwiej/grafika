package main

import rl "vendor:raylib"


State_models :: struct {
	currentImage:        ImageBuffer_models,
	editedImage:         ImageBuffer_models,
	texture:             rl.Texture2D,
	zoom:                f32,
	panOffset:           rl.Vector2,
	compressionQuality:  int,
	errorState:          ImageError_models,
	buffer:              [32]u8,
	bufferLen:           int,
	activeInputId:       u32,
	showModes:           bool,
	loadNewTexture:      bool,
	grayScale8:          [dynamic]u8,
	grayScale16:         [dynamic]u16,
	pointOperationValue: int, // Wartość do dodawania/mnożenia itp.
	filterSigma:         f32,
}

ImageBuffer_models :: struct {
	width:      i32,
	height:     i32,
	format:     FileFormat_models,
	maxVal:     union {
		[dynamic]u8,
		[dynamic]u16,
	},
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

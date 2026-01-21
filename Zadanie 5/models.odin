package main

import rl "vendor:raylib"


State_models :: struct {
	currentImage:       ImageBuffer_models,
	EditingImage:       ImageBuffer_models,
	texture:            rl.Texture2D,
	zoom:               f32,
	panOffset:          rl.Vector2,
	compressionQuality: int,
	errorState:         ImageError_models,
	buffer:             [32]u8,
	bufferLen:          int,
	activeInputId:      u32,
	showModes:          bool,
	loadNewTexture:     bool,
	selectedMethod:     BinarizationMethod,
	thresholdManual:    int,
	thresholdPercent:   f32,
	previewTexture:     rl.Texture2D,
	hasPreview:         bool,
	updatePreview:      bool,
}
BinarizationMethod :: enum {
	None,
	Manual, // Ręczny próg
	PercentBlack, // Procentowa selekcja czarnego
	MeanIterative, // Selekcja iteratywna średniej
	Entropy, // Selekcja entropii
	MinError, // Błąd minimalny
	FuzzyMinError, // Metoda rozmytego błędu minimalnego
}
HistogramOneChannel_models :: struct {
	data: [256]i64,
}
HistogramThreeChannels_models :: struct {
	dataR: [256]i64,
	dataG: [256]i64,
	dataB: [256]i64,
}

ImageBuffer_models :: struct {
	width:        i32,
	height:       i32,
	channelCount: i32,
	format:       FileFormat_models,
	maxVal:       union {
		[dynamic]u8,
		[dynamic]u16,
	},
	maxValFlag:   i32,
	hist:         rawptr,
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

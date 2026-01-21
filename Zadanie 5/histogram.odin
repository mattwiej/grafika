package main

import "core:fmt"
import "core:math"

CreateHistogram :: proc(state: ^State_models, img: ^ImageBuffer_models) {
	// To jest brzydkie bo nie mogę użyć len bo nie znam rozmiaru obiektu w tablicy, trzeba znowu przez switcha a mi sie nie chce wiec zakładam że zapisze to przy ładowaniu obrazu
	//	if state.currentImage.channelCount == 0 {
	//		state.currentImage.channelCount =
	//			len(rawptr(&state.currentImage.maxVal)) /
	//			(state.currentImage.width * state.currentImage.height)
	//	}

	switch pixel in img.maxVal {

	case [dynamic]u8:
		switch img.channelCount {
		case 1:
			temp := new(HistogramOneChannel_models)
			for i := 0; i < len(pixel); i += 1 {
				temp.data[pixel[i]] += 1
			}
			img.hist = temp

		case 3:
			temp := new(HistogramThreeChannels_models)
			for i := 0; i < len(pixel); i += 3 {
				temp.dataR[pixel[i]] += 1
				temp.dataG[pixel[i + 1]] += 1
				temp.dataB[pixel[i + 2]] += 1
			}
			img.hist = temp
		}
	case [dynamic]u16:
		return //fuck that

	}
}
StretchHistogramChannel :: proc(img: ^ImageBuffer_models, channelIdx: int, state: ^State_models) {
	if img.hist == nil {return}

	histData: ^[256]i64 = nil

	switch img.channelCount {
	case 1:
		h := cast(^HistogramOneChannel_models)img.hist
		if channelIdx == 0 do histData = &h.data
	case 3:
		h := cast(^HistogramThreeChannels_models)img.hist
		switch channelIdx {
		case 0:
			histData = &h.dataR
		case 1:
			histData = &h.dataG
		case 2:
			histData = &h.dataB
		}
	}

	if histData == nil {return}

	min_val, max_val, diff: i64

	for min_val = 0; min_val < 256; min_val += 1 {
		if histData[min_val] != 0 {break}
	}
	for max_val = 255; max_val >= 0; max_val -= 1 {
		if histData[max_val] != 0 {break}
	}

	diff = max_val - min_val
	if diff <= 0 {return}
	fmt.printfln("Channel: %d | Min: %d | Max: %d | Diff: %d", channelIdx, min_val, max_val, diff)
	switch pixels in &img.maxVal {
	case [dynamic]u8:
		step := int(img.channelCount) // Dla Grayscale = 1, dla RGB = 3
		start_index := channelIdx // 0 dla R, 1 dla G, 2 dla B

		for i := start_index; i < len(pixels); i += step {
			val := i64(pixels[i])

			newVal := (val - min_val) * 255 / diff

			if newVal < 0 {newVal = 0}
			if newVal > 255 {newVal = 255}

			pixels[i] = u8(newVal)
		}

		CreateHistogram(state, img)
		state.loadNewTexture = true

	case [dynamic]u16:
		return // TODO: Obsługa 16-bit
	}
}


EqualizeHistogramChannel :: proc(img: ^ImageBuffer_models, channelIdx: int, state: ^State_models) {
	if img.hist == nil {return}

	histData: ^[256]i64 = nil

	switch img.channelCount {
	case 1:
		h := cast(^HistogramOneChannel_models)img.hist
		if channelIdx == 0 do histData = &h.data
	case 3:
		h := cast(^HistogramThreeChannels_models)img.hist
		switch channelIdx {
		case 0:
			histData = &h.dataR
		case 1:
			histData = &h.dataG
		case 2:
			histData = &h.dataB
		}
	}

	if histData == nil {return}

	cdf: [256]i64
	sum: i64 = 0

	for i in 0 ..< 256 {
		sum += histData[i]
		cdf[i] = sum
	}

	cdf_min: i64 = 0
	total_pixels := cdf[255]

	for val in cdf {
		if val > 0 {
			cdf_min = val
			break
		}
	}

	divisor := total_pixels - cdf_min
	if divisor <= 0 {return}

	lut: [256]u8

	for i in 0 ..< 256 {

		if cdf[i] <= cdf_min {
			lut[i] = 0
		} else {
			val := (cdf[i] - cdf_min) * 255 / divisor

			if val > 255 {val = 255} 	// Clamp
			lut[i] = u8(val)
		}
	}

	switch pixels in &img.maxVal {
	case [dynamic]u8:
		step := int(img.channelCount)
		start_index := channelIdx

		for i := start_index; i < len(pixels); i += step {
			original_val := pixels[i]
			pixels[i] = lut[original_val]
		}

		CreateHistogram(state, img)
		state.loadNewTexture = true

	case [dynamic]u16:
		return // TODO
	}
}

//problem z ta funkcja jest taki ze nie uwzgledniam step kiedy mam wiecej niz jeden kanal shiiiijet
StretchHistogram :: proc(data: ^[256]i64, img: ^ImageBuffer_models, state: ^State_models) {

	min, max, diff: i64

	for min = 0; min < 256; min += 1 {
		if (data[min] != 0) {
			break
		}
	}
	for max = 255; max >= 0; max -= 1 {

		if data[max] != 0 {
			break
		}
	}
	diff = max - min
	if diff <= 0 {
		return
	}

	switch pixel in &img.maxVal {

	case [dynamic]u8:
		for i := 0; i < len(pixel); i += 1 {
			val := i64(pixel[i])
			newVal := (val - min) * 255 / diff

			pixel[i] = u8(newVal)
		}
		CreateHistogram(state, img)

	case [dynamic]u16:
		return //fuck that

	}


}

package main

import clay "clay-odin"
import "core:fmt"
import "core:strconv"
import rl "vendor:raylib"

COLOR_WINDOW_BG :: clay.Color{43, 43, 43, 240}
COLOR_BORDER :: clay.Color{100, 100, 100, 255}
COLOR_TEXT :: clay.Color{255, 255, 255, 255}
COLOR_DEBUG_PINK :: clay.Color{60, 60, 60, 240}
COLOR_MODE_BUTTON :: clay.Color{60, 60, 60, 255}
COLOR_MODE_BUTTON_HOVER :: clay.Color{120, 120, 120, 255}
COLOR_MODE_BUTTON_ACTIVE :: clay.Color{30, 120, 90, 255}
COLOR_PROPERTY_INPUT_BG :: clay.Color{200, 200, 200, 255}
COLOR_PROPERTY_INPUT_BG_HOVER :: clay.Color{220, 220, 220, 255}
COLOR_PROPERTY_INPUT_BG_ACTIVE :: clay.Color{250, 250, 250, 255}

HandleTextInput :: proc(state: ^State_models) {
	key := rl.GetCharPressed()
	for key > 0 {
		if key >= 32 && key <= 125 && state.bufferLen < len(state.buffer) {
			state.buffer[state.bufferLen] = u8(key)
			state.bufferLen += 1
		}
		key = rl.GetCharPressed()
	}

	if rl.IsKeyPressed(.BACKSPACE) || rl.IsKeyPressedRepeat(.BACKSPACE) {
		if state.bufferLen > 0 {
			state.bufferLen -= 1
		}
	}
}


spacer :: proc() {
	if clay.UI()(
	{layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})}}},
	) {}

}


PropertyInput :: proc(label: string, value: ^$T, id: u32, state: ^State_models) {

	isActive := (state.activeInputId == id)

	borderCol := isActive ? clay.Color{100, 140, 255, 255} : COLOR_BORDER
	bgCol := isActive ? clay.Color{255, 255, 255, 255} : COLOR_PROPERTY_INPUT_BG

	if clay.UI(clay.ID(label, id))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(30)},
			childGap = 5,
			layoutDirection = .LeftToRight,
			childAlignment = {y = .Center},
		},
	},
	) {
		clay.TextDynamic(
			label,
			clay.TextConfig({fontSize = 16, fontId = FONT_ID_BODY_16, textColor = COLOR_TEXT}),
		)

		if clay.UI(clay.ID("InputBg", id))(
		{
			layout = {
				sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
				padding = {left = 5, right = 5},
				childAlignment = {y = .Center}, // Wyśrodkowanie tekstu w pionie
			},
			backgroundColor = bgCol,
			cornerRadius = clay.CornerRadiusAll(5),
			border = {width = clay.BorderAll(1), color = borderCol},
		},
		) {

			textToDisplay: string

			if isActive {
				HandleTextInput(state)

				textToDisplay = string(state.buffer[:state.bufferLen])

				if rl.IsKeyPressed(.ENTER) {
					valStr := textToDisplay

					when T == f32 {
						if res, ok := strconv.parse_f32(valStr); ok {
							value^ = res
						}
					} else when T == u8 {
						// strconv.parse_uint zwraca u64, rzutujemy na u8
						if res, ok := strconv.parse_uint(valStr); ok {
							value^ = u8(res)
						}
					} else when T == int {
						if res, ok := strconv.parse_int(valStr); ok {
							value^ = res
							fmt.printfln("\n\n\n\n\n compres: %v", state.compressionQuality)
						}
					}
					state.activeInputId = 0 // Wyjście z edycji
				}

				// Anulowanie (ESCAPE)
				if rl.IsKeyPressed(.ESCAPE) {
					state.activeInputId = 0
				}

			} else {
				textToDisplay = fmt.tprint(value^)

				if clay.PointerOver(clay.ID("InputBg", id)) && rl.IsMouseButtonPressed(.LEFT) {
					state.activeInputId = id

					valStr := fmt.tprint(value^)
					state.bufferLen = len(valStr)
					if state.bufferLen > len(state.buffer) do state.bufferLen = len(state.buffer)
					copy(state.buffer[:], valStr)
				}
			}

			displayFinal := isActive ? fmt.tprint(textToDisplay, "|") : textToDisplay

			clay.TextDynamic(
				displayFinal,
				clay.TextConfig(
					{fontSize = 16, fontId = FONT_ID_BODY_16, textColor = {0, 0, 0, 255}},
				),
			)
		}
	}
}

RowVector2 :: proc(label: string, vec: ^[2]f32, baseId: u32, state: ^State_models) {
	clay.TextDynamic(
		label,
		clay.TextConfig({fontSize = 18, fontId = FONT_ID_BODY_16, textColor = COLOR_TEXT}),
	)

	if clay.UI(clay.ID("Row", baseId))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({})},
			childGap = 10,
			layoutDirection = .LeftToRight,
		},
	},
	) {
		PropertyInput("X", &vec.x, baseId, state)
		PropertyInput("Y", &vec.y, baseId + 1, state)
	}
}


modeButon :: proc(id, text: string, isActive: bool) -> bool {

	bgColor := isActive ? COLOR_MODE_BUTTON_ACTIVE : COLOR_MODE_BUTTON
	clicked := false

	if clay.UI(clay.ID(id))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(40)},
			padding = clay.PaddingAll(10),
		},
		backgroundColor = clay.Hovered() ? COLOR_MODE_BUTTON_HOVER : bgColor,
		cornerRadius = clay.CornerRadiusAll(5),
	},
	) {
		clay.TextDynamic(
			text,
			clay.TextConfig({fontSize = 24, fontId = FONT_ID_BODY_24, textColor = COLOR_TEXT}),
		)
	}
	if clay.PointerOver(clay.ID(id)) && rl.IsMouseButtonPressed(.LEFT) {
		clicked = true
		//fmt.printfln("klikej %s", id)
	}
	return clicked
}

//////////////


inputField :: proc(label: string, value: string) {
	if clay.UI(clay.ID(label))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFit({})},
			layoutDirection = .TopToBottom,
			childGap = 5,
		},
	},
	) {
		clay.TextDynamic(label, clay.TextConfig({fontSize = 16, textColor = COLOR_TEXT}))

		if clay.UI(clay.ID(fmt.tprintf("%s_Input", label)))(
		{
			layout = {
				sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(30)},
				padding = clay.Padding{left = 5, right = 5, top = 5, bottom = 5}, // adjust as needed
			},
			backgroundColor = {255, 255, 255, 255}, // White background for input
			cornerRadius = clay.CornerRadiusAll(5),
			border = {width = clay.BorderAll(1), color = COLOR_BORDER},
		},
		) {
			clay.TextDynamic(value, clay.TextConfig({fontSize = 16, textColor = {0, 0, 0, 255}}))
		}
	}
}

actionButton :: proc(text: string) -> bool {
	clicked := false
	if clay.UI(clay.ID(text))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(40)},
			padding = clay.PaddingAll(10),
		},
		backgroundColor = {50, 200, 50, 255},
		cornerRadius = clay.CornerRadiusAll(8),
	},
	) {
		clay.TextDynamic(text, clay.TextConfig({fontSize = 20, textColor = {255, 255, 255, 255}}))
		if clay.PointerOver(clay.GetElementId(clay.MakeString(text))) &&
		   rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
			//fmt.println("rysowanie")
			clicked = true
		}
	}
	return clicked
}

modesOverlay :: proc(state: ^State_models) {
	if clay.UI(clay.ID("ToolsWindow"))(
	{
		layout = {
			sizing = {width = clay.SizingFixed(280), height = clay.SizingGrow({})}, // Nieco szerszy panel
			layoutDirection = .TopToBottom,
			padding = clay.PaddingAll(15),
			childGap = 15,
		},
		backgroundColor = COLOR_DEBUG_PINK,
		//border = {right = {width = 2, color = COLOR_BORDER}},
	},
	) {
		clay.Text("Image Ops", clay.TextConfig({fontSize = 32, textColor = COLOR_TEXT}))

		sectionHeader("File Operations")
		if clay.UI(clay.ID("FileOps"))(
		{
			layout = {
				layoutDirection = .LeftToRight,
				childGap = 10,
				sizing = {width = clay.SizingGrow({})},
			},
		},
		) {
			if actionButton("Save") {
				if path, ok := save_file_dialog(); ok {
					SaveToJpeg(state.currentImage, path, state.compressionQuality)
				}
			}
			if actionButton("Load") {
				if path, ok := open_file_dialog(); ok {
					data, load := LoadFile_parser_fast(path, state)
					if load {
						state.loadNewTexture = true
						state.currentImage = data
						state.currentImage.hist = nil
						state.hasPreview = false
						RecalculateChannelCount(&state.currentImage)
					}
				}
			}
		}
		PropertyInput("JPEG Quality", &state.compressionQuality, 999, state)

		// --- SEKCJA 3: BINARYZACJA ---
		sectionHeader("Binarization")

		// Lista metod (Radio Buttons)
		if radioButton("None (Original)", state.selectedMethod == .None, "None") {
			state.selectedMethod = .None
		}

		if radioButton("Manual Threshold", state.selectedMethod == .Manual, "Manual") {
			state.selectedMethod = .Manual
		}
		if state.selectedMethod == .Manual {
			oldTh := state.thresholdManual
			PropertyInput("Threshold (0-255)", &state.thresholdManual, 1001, state)
			if oldTh != state.thresholdManual {
				fmt.printfln("czy wchodzi tutej")
				ManualBinarization(&state.currentImage, state)
			}
		}

		if radioButton("Percent Black", state.selectedMethod == .PercentBlack, "Perc") {
			state.selectedMethod = .PercentBlack
		}
		if state.selectedMethod == .PercentBlack {
			PropertyInput("Percent (0.0-1.0)", &state.thresholdPercent, 1002, state)
		}

		if radioButton("Iterative Mean", state.selectedMethod == .MeanIterative, "Mean") {
			state.selectedMethod = .MeanIterative
		}

		if radioButton("Entropy Selection", state.selectedMethod == .Entropy, "Entropy") {
			state.selectedMethod = .Entropy
		}

		if radioButton("Minimum Error", state.selectedMethod == .MinError, "MinErr") {
			state.selectedMethod = .MinError
		}

		if radioButton("Fuzzy Min Error", state.selectedMethod == .FuzzyMinError, "Fuzzy") {
			state.selectedMethod = .FuzzyMinError
		}

		if state.selectedMethod != .None {
			if actionButton("APPLY BINARIZATION") {
				fmt.printfln("Applying Method: %v", state.selectedMethod)
				ApplyAutoBinarization(state)
			}
		}
		clay.Text("Grayscale", clay.TextConfig({fontSize = 16, textColor = COLOR_TEXT}))
		if clay.UI(clay.ID("Gray_Grid"))(
		{layout = {layoutDirection = .LeftToRight, childGap = 5}},
		) {
			if actionButton("Avg Gray") {
				ConvertToGrayscale(&state.currentImage, false)
				state.loadNewTexture = true
				CreateHistogram(state, &state.currentImage)
			}
			if actionButton("Wgt Gray") {
				ConvertToGrayscale(&state.currentImage, true)
				state.loadNewTexture = true
				CreateHistogram(state, &state.currentImage)
			}
		}
		spacer()
	}
}

sectionHeader :: proc(text: string) {
	if clay.UI(clay.ID(fmt.tprintf("Header_%s", text)))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFit({})},
			padding = {top = 10, bottom = 5},
		},
	},
	) {
		clay.TextDynamic(text, clay.TextConfig({fontSize = 18, textColor = {150, 150, 150, 255}}))
		// Linia oddzielająca
		if clay.UI(clay.ID(fmt.tprintf("Line_%s", text)))(
		{
			layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(1)}},
			backgroundColor = {80, 80, 80, 255},
		},
		) {}
	}
}
/////////EKSPERYMENTY
radioButton :: proc(text: string, isActive: bool, id_suffix: string) -> bool {
	clicked := false

	// Kolory
	bgCol := isActive ? clay.Color{30, 120, 90, 255} : clay.Color{60, 60, 60, 255}
	borderCol := isActive ? clay.Color{100, 255, 100, 255} : clay.Color{80, 80, 80, 255}

	if clay.UI(clay.ID(fmt.tprintf("Radio_%s", id_suffix)))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(35)},
			padding = clay.PaddingAll(8),
			childAlignment = {y = .Center},
		},
		backgroundColor = clay.Hovered() ? clay.Color{80, 80, 80, 255} : bgCol,
		cornerRadius = clay.CornerRadiusAll(5),
		border = {width = clay.BorderAll(1), color = borderCol},
	},
	) {
		clay.TextDynamic(text, clay.TextConfig({fontSize = 16, textColor = COLOR_TEXT}))

		// Obsługa kliknięcia
		if clay.PointerOver(
			   clay.GetElementId(clay.MakeString(fmt.tprintf("Radio_%s", id_suffix))),
		   ) &&
		   rl.IsMouseButtonPressed(.LEFT) {
			clicked = true
		}
	}
	return clicked
}
histogramOverlay :: proc(state: ^State_models) {
	if clay.UI(clay.ID("RightPanel"))(
	{
		layout = {
			sizing = {width = clay.SizingFixed(320), height = clay.SizingGrow({})}, // Trochę szerzej
			layoutDirection = .TopToBottom,
			padding = clay.PaddingAll(10),
			childGap = 10,
		},
		backgroundColor = COLOR_WINDOW_BG,
		//border = {left = {width = 2, color = COLOR_BORDER}}, // Linia oddzielająca od obrazka
	},
	) {
		clay.Text("Histograms", clay.TextConfig({fontSize = 24, textColor = COLOR_TEXT}))

		img := &state.currentImage

		switch img.channelCount {
		case 1:
			// --- KANAŁ GRAY ---
			renderChannelControls("Gray", "Hist_Gray", state, 0) // 0 to umowny ID kanału

		case 3:
			// --- KANAŁ RED ---
			renderChannelControls("Red Channel", "Hist_Red", state, 0)

			// --- KANAŁ GREEN ---
			renderChannelControls("Green Channel", "Hist_Green", state, 1)

			// --- KANAŁ BLUE ---
			renderChannelControls("Blue Channel", "Hist_Blue", state, 2)

		case:
			clay.Text(
				"Unsupported channel count",
				clay.TextConfig({fontSize = 16, textColor = {255, 0, 0, 255}}),
			)
		}
	}
}

renderChannelControls :: proc(
	label: string,
	canvasId: string,
	state: ^State_models,
	channelIdx: int,
) {
	clay.TextDynamic(label, clay.TextConfig({fontSize = 16, textColor = COLOR_TEXT}))

	if clay.UI(clay.ID(canvasId))(
	{
		layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(120)}},
		backgroundColor = {20, 20, 20, 255}, // Ciemne tło pod wykresem
		cornerRadius = clay.CornerRadiusAll(5),
		border = {width = clay.BorderAll(1), color = COLOR_BORDER},
	},
	) {}

	if clay.UI(clay.ID(fmt.tprintf("Btns_%s", canvasId)))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFit({})},
			layoutDirection = .LeftToRight,
			childGap = 5,
		},
	},
	) {
		btnStretchId := fmt.tprintf("Stretch_%s", canvasId)
		btnEqId := fmt.tprintf("Eq_%s", canvasId)

		if actionButtonWithId(btnStretchId, "Stretch") {
			fmt.printf("Stretching channel %d\n", channelIdx)
			// Tutaj wywołaj swoją logikę:
			StretchHistogramChannel(&state.currentImage, channelIdx, state)
		}

		if actionButtonWithId(btnEqId, "Equalize") {
			fmt.printf("Equalizing channel %d\n", channelIdx)
			EqualizeHistogramChannel(&state.currentImage, channelIdx, state)
		}
	}

	// Mały odstęp po sekcji
	spacerFixed(10)
}

actionButtonWithId :: proc(id: string, text: string) -> bool {
	clicked := false
	if clay.UI(clay.ID(id))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(30)},
			padding = clay.PaddingAll(5),
			childAlignment = {x = .Center, y = .Center},
		},
		backgroundColor = {60, 60, 60, 255},
		cornerRadius = clay.CornerRadiusAll(4),
	},
	) {
		clay.TextDynamic(text, clay.TextConfig({fontSize = 16, textColor = COLOR_TEXT}))
		if clay.PointerOver(clay.GetElementId(clay.MakeString(id))) &&
		   rl.IsMouseButtonPressed(.LEFT) {
			clicked = true
		}
	}
	return clicked
}

spacerFixed :: proc(h: f32) {
	if clay.UI(clay.ID(fmt.tprintf("spacer_%f", h)))(
	{layout = {sizing = {height = clay.SizingFixed(h)}}},
	) {}
}

GetClayRect :: proc(idStr: string) -> (rl.Rectangle, bool) {
	id := clay.GetElementId(clay.MakeString(idStr))
	data := clay.GetElementData(id)

	if data.found {
		return rl.Rectangle {
				x = data.boundingBox.x,
				y = data.boundingBox.y,
				width = data.boundingBox.width,
				height = data.boundingBox.height,
			},
			true
	}
	return {}, false
}

createLayout :: proc(state: ^State_models) -> clay.ClayArray(clay.RenderCommand) {


	clay.BeginLayout()

	if clay.UI(clay.ID("OverlayRoot"))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
			padding = clay.PaddingAll(20),
			childGap = 20,
			layoutDirection = .LeftToRight,
		},
	},
	) {
		if state.showModes {
			modesOverlay(state)
		}
		spacer()

		if state.showModes {
			histogramOverlay(state)
		}
	}

	return clay.EndLayout()

}

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
			sizing = {width = clay.SizingFixed(250), height = clay.SizingGrow({})},
			layoutDirection = .TopToBottom,
			padding = clay.PaddingAll(10),
			childGap = 10,
		},
		backgroundColor = COLOR_DEBUG_PINK,
		cornerRadius = clay.CornerRadiusAll(10),
		border = {width = clay.BorderAll(1), color = COLOR_BORDER},
	},
	) {
		if clay.UI(clay.ID("ToolsWindowHeadder"))(
		{
			layout = {
				sizing = {width = clay.SizingGrow({}), height = clay.SizingFit({})},
				layoutDirection = clay.LayoutDirection.LeftToRight,
				padding = clay.PaddingAll(10),
				childGap = 10,
			},
			backgroundColor = COLOR_WINDOW_BG,
		},
		) {
			spacer()
			clay.Text(
				"Tools",
				clay.TextConfig(
					{fontSize = 36, fontId = FONT_ID_TITLE_36, textColor = COLOR_TEXT},
				),
			)
			spacer()
		}
		if clay.UI(clay.ID("Saving_Loading"))(
		{
			layout = {
				sizing = {width = clay.SizingGrow({}), height = clay.SizingFit({})},
				layoutDirection = .LeftToRight,
				padding = clay.PaddingAll(10),
				childGap = 10,
			},
			backgroundColor = COLOR_WINDOW_BG,
			cornerRadius = clay.CornerRadiusAll(8),
		},
		) {
			if actionButton("Save") {
				if path, ok := save_file_dialog(); ok {
					SaveToJpeg(state.currentImage, path, state.compressionQuality)
				}
				fmt.println("zapisane")}

			if actionButton("Load") {
				if path, ok := open_file_dialog(); ok {
					data, load := LoadFile_parser_fast(path, state)
					if load {
						state.loadNewTexture = true
						state.currentImage = data
					}
				}
				fmt.println("wczytane")


			}}


		spacer()

	}
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
	}

	return clay.EndLayout()

}

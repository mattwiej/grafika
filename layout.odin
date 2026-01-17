package main

import clay "clay-odin"
import "core:fmt"
import "core:strconv"
import rl "vendor:raylib"

COLOR_WINDOW_BG :: clay.Color{43, 43, 43, 240}
COLOR_BORDER :: clay.Color{100, 100, 100, 255}
COLOR_TEXT :: clay.Color{255, 255, 255, 255}
COLOR_DEBUG_PINK :: clay.Color{255, 192, 203, 240}
COLOR_MODE_BUTTON :: clay.Color{60, 60, 60, 255}
COLOR_MODE_BUTTON_HOVER :: clay.Color{120, 120, 120, 255}
COLOR_MODE_BUTTON_ACTIVE :: clay.Color{30, 120, 90, 255}
COLOR_PROPERTY_INPUT_BG :: clay.Color{200, 200, 200, 255}
COLOR_PROPERTY_INPUT_BG_HOVER :: clay.Color{220, 220, 220, 255}
COLOR_PROPERTY_INPUT_BG_ACTIVE :: clay.Color{250, 250, 250, 255}

ToolDef :: struct {
	mode:  Mode,
	label: string,
}

TOOLS_UI_CONFIG :: [?]ToolDef {
	{.select, "Select"},
	{.drawLine, "Line"},
	{.drawRect, "Rect"},
	{.drawCircle, "Circle"},
}

HandleTextInput :: proc(state: ^State) {
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

propertyInput2 :: proc(label, id: string, value: ^f32, isActive: bool, state: ^State) -> bool {
	bgColor := isActive ? COLOR_PROPERTY_INPUT_BG_ACTIVE : COLOR_PROPERTY_INPUT_BG
	clicked := false

	if clay.UI(clay.ID(id))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(30)},
			padding = clay.PaddingAll(10),
		},
		backgroundColor = clay.Hovered() ? COLOR_PROPERTY_INPUT_BG_HOVER : bgColor,
		cornerRadius = clay.CornerRadiusAll(5),
	},
	) {
		clay.TextDynamic(
			label,
			clay.TextConfig({fontSize = 16, fontId = FONT_ID_BODY_16, textColor = COLOR_TEXT}),
		)

		if clay.UI(clay.ID(id, 1))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				padding = {left = 5, right = 5},
			},
			backgroundColor = {255, 255, 255, 255},
			cornerRadius = clay.CornerRadiusAll(5),
			border = {width = clay.BorderAll(1), color = COLOR_BORDER},
		},
		) {
			valueText := fmt.tprint(value)
			clay.TextDynamic(
				valueText,
				clay.TextConfig({fontSize = 16, fontId = FONT_ID_BODY_16, textColor = COLOR_TEXT}),
			)
		}
	}
	if clay.PointerOver(clay.ID(id)) && rl.IsMouseButtonPressed(.LEFT) {
		clicked = true
		//fmt.printfln("klikej %s", id)
	}
	return clicked
}


PropertyInput :: proc(label: string, value: ^$T, id: u32, state: ^State) {

	isActive := (state.activeInputId == id)

	// Style zależne od stanu
	borderCol := isActive ? clay.Color{100, 140, 255, 255} : COLOR_BORDER
	bgCol := isActive ? clay.Color{255, 255, 255, 255} : COLOR_PROPERTY_INPUT_BG

	// Kontener Główny (Label + Input)
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
		// Etykieta (np. "X")
		clay.TextDynamic(
			label,
			clay.TextConfig({fontSize = 16, fontId = FONT_ID_BODY_16, textColor = COLOR_TEXT}),
		)

		// Pole Tekstowe (Tło + Wartość)
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
				// --- TRYB EDYCJI ---
				HandleTextInput(state) // Twoja funkcja do obsługi klawiatury

				// Tworzymy string z bufora (tylko do długości bufferLen)
				textToDisplay = string(state.buffer[:state.bufferLen])

				// Zatwierdzenie (ENTER)
				if rl.IsKeyPressed(.ENTER) {
					// Parsowanie w zależności od typu T
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
					}
					state.activeInputId = 0 // Wyjście z edycji
				}

				// Anulowanie (ESCAPE)
				if rl.IsKeyPressed(.ESCAPE) {
					state.activeInputId = 0
				}

			} else {
				// --- TRYB PODGLĄDU ---
				textToDisplay = fmt.tprint(value^)

				// Aktywacja kliknięciem
				if clay.PointerOver(clay.ID("InputBg", id)) && rl.IsMouseButtonPressed(.LEFT) {
					state.activeInputId = id

					// Kopiujemy obecną wartość do bufora edycji, żeby zacząć edycję od starej wartości
					valStr := fmt.tprint(value^)
					state.bufferLen = len(valStr)
					if state.bufferLen > len(state.buffer) do state.bufferLen = len(state.buffer)
					copy(state.buffer[:], valStr)
				}
			}

			// Wyświetlamy tekst (dodajemy kursor "|" jeśli aktywny)
			displayFinal := isActive ? fmt.tprint(textToDisplay, "|") : textToDisplay

			// Tekst wartości (czarny, bo tło jasne)
			clay.TextDynamic(
				displayFinal,
				clay.TextConfig(
					{fontSize = 16, fontId = FONT_ID_BODY_16, textColor = {0, 0, 0, 255}},
				),
			)
		}
	}
}

// Helper do rysowania wiersza wektora (X, Y)
// baseId: u32 -> Baza dla ID. X dostanie baseId, Y dostanie baseId + 1
RowVector2 :: proc(label: string, vec: ^[2]f32, baseId: u32, state: ^State) {
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
		// Przekazujemy adresy konkretnych pól wektora (.x i .y)
		PropertyInput("X", &vec.x, baseId, state)
		PropertyInput("Y", &vec.y, baseId + 1, state)
	}
}

shapeLinePositionInfo :: proc(shape: ^Shape, state: ^State) {
	// Pobieramy wskaźnik do danych wewnątrz unii!
	// switch &v in shape.kind pozwala modyfikować dane
	switch &data in shape.kind {
	case LineData:
		// ID 100-101
		RowVector2("Start Point", &data.start, 100, state)
		spacer()
		// ID 110-111
		RowVector2("End Point", &data.end, 110, state)
	case RectData:
	case CircleData:
	}
}

shapeRectPositionInfo :: proc(shape: ^Shape, state: ^State) {
	switch &data in shape.kind {
	case RectData:
		// ID 200-201
		RowVector2("Position (Top-Left)", &data.start, 200, state)
		spacer()

		clay.TextDynamic(
			"Size",
			clay.TextConfig({fontSize = 18, fontId = FONT_ID_BODY_16, textColor = COLOR_TEXT}),
		)
		// ID 210
		if clay.UI(clay.ID("RectSizeRow", 210))(
		{
			layout = {
				sizing = {width = clay.SizingGrow({})},
				childGap = 10,
				layoutDirection = .LeftToRight,
			},
		},
		) {
			// ID 211, 212
			PropertyInput("W", &data.size.x, 211, state)
			PropertyInput("H", &data.size.y, 212, state)
		}
	case LineData:
	case CircleData:
	}
}

shapeCirclePositionInfo :: proc(shape: ^Shape, state: ^State) {
	switch &data in shape.kind {
	case CircleData:
		// ID 300-301
		RowVector2("Center", &data.center, 300, state)
		spacer()

		clay.TextDynamic(
			"Dimensions",
			clay.TextConfig({fontSize = 18, fontId = FONT_ID_BODY_16, textColor = COLOR_TEXT}),
		)
		// ID 310
		PropertyInput("Radius", &data.radius, 310, state)
	case LineData:
	case RectData:
	}
}

shapePositionInfo :: proc(shape: ^Shape, state: ^State) {
	switch v in shape.kind {
	case LineData:
		shapeLinePositionInfo(shape, state)
	case RectData:
		shapeRectPositionInfo(shape, state)
	case CircleData:
		shapeCirclePositionInfo(shape, state)
	}
}

shapeColorInfo :: proc(shape: ^Shape, state: ^State) {
	clay.TextDynamic(
		"Color (RGBA)",
		clay.TextConfig({fontSize = 18, fontId = FONT_ID_BODY_16, textColor = COLOR_TEXT}),
	)

	// Wiersz pól: ID 400
	if clay.UI(clay.ID("ColorRow", 400))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({})},
			childGap = 5,
			layoutDirection = .LeftToRight,
		},
	},
	) {
		// ID 401-404
		PropertyInput("R", &shape.color[0], 401, state)
		PropertyInput("G", &shape.color[1], 402, state)
		PropertyInput("B", &shape.color[2], 403, state)
		PropertyInput("A", &shape.color[3], 404, state)
	}

	// Podgląd: ID 405
	if clay.UI(clay.ID("ColorPreview", 405))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(20)},
			padding = {top = 5},
		},
		backgroundColor = {
			f32(shape.color[0]),
			f32(shape.color[1]),
			f32(shape.color[2]),
			f32(shape.color[3]),
		},
		cornerRadius = clay.CornerRadiusAll(5),
		border = {width = clay.BorderAll(1), color = {255, 255, 255, 255}},
	},
	) {}
}

shapeInfoOverlay :: proc(state: ^State) {
	if state.selectedIdx < 0 || state.selectedIdx >= len(state.shapes) {
		return
	}

	// Pobieramy WSKAŹNIK do kształtu, żeby móc go edytować
	selectedShape := &state.shapes[state.selectedIdx]

	if clay.UI(clay.ID("EditWindow"))(
	{
		layout = {
			sizing = {width = clay.SizingFixed(300), height = clay.SizingFit({})}, // Trochę szersze
			layoutDirection = .TopToBottom,
			padding = clay.PaddingAll(15),
			childGap = 10,
		},
		backgroundColor = COLOR_WINDOW_BG, // Spójny kolor tła (ciemny)
		cornerRadius = clay.CornerRadiusAll(10),
		border = {width = clay.BorderAll(1), color = COLOR_BORDER},
	},
	) {

		// Header
		if clay.UI(clay.ID("EditWindowHeader"))(
		{
			layout = {sizing = {width = clay.SizingGrow({})}, childAlignment = {x = .Center}},
			backgroundColor = {0, 0, 0, 0}, // Przezroczysty
		},
		) {
			clay.TextDynamic(
				"Properties",
				clay.TextConfig(
					{fontSize = 30, fontId = FONT_ID_TITLE_36, textColor = COLOR_TEXT},
				),
			)
		}

		// Separator
		if clay.UI(clay.ID("Sep1"))(
		{
			layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(1)}},
			backgroundColor = COLOR_BORDER,
		},
		) {}

		spacer()

		// 1. ID (u32) - używamy tego samego helpera (polimorfizm)
		// Uwaga: PropertyInput obsługuje u8 i f32, dla u32 trzeba by dodać 'when T == u32' w PropertyInput
		// Na razie wyświetlmy to jako tekst statyczny
		clay.TextDynamic(
			fmt.tprint("ID:", selectedShape.id),
			clay.TextConfig(
				{fontSize = 16, fontId = FONT_ID_BODY_16, textColor = {150, 150, 150, 255}},
			),
		)

		spacer()

		// 2. Pozycja i Wymiary
		shapePositionInfo(selectedShape, state)

		spacer()

		// 3. Kolor
		shapeColorInfo(selectedShape, state)
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
		// Label
		clay.TextDynamic(label, clay.TextConfig({fontSize = 16, textColor = COLOR_TEXT}))

		// Input Box (Visual only - logic requires event handling)
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

// A distinct button for the "Draw" action
actionButton :: proc(text: string) -> bool {
	clicked := false
	if clay.UI(clay.ID(text))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(40)},
			padding = clay.PaddingAll(10),
			//layoutDirection = .Row, // Center text
			//alignChild = .Center, // Center text
		},
		backgroundColor = {50, 200, 50, 255}, // Green color for action
		cornerRadius = clay.CornerRadiusAll(8),
	},
	) {
		clay.TextDynamic(text, clay.TextConfig({fontSize = 20, textColor = {255, 255, 255, 255}}))

		// Simple interaction logic
		// Note: You need to pass standard input state here usually
		// keeping it simple for this snippet:
		//if clay.PointerOver(clay.ID(id)) && rl.IsMouseButtonPressed(.LEFT)
		if clay.PointerOver(clay.GetElementId(clay.MakeString(text))) &&
		   rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
			//fmt.println("rysowanie")
			clicked = true
		}
	}
	return clicked
}


modesOverlay :: proc(state: ^State) {
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
		for item in TOOLS_UI_CONFIG {
			isSelected: bool = (state.currentMode == item.mode)
			if modeButon(item.label, item.label, isSelected) {
				state.currentMode = item.mode
				state.selectedIdx = -1
				fmt.printfln("mode: %d", state.currentMode)
			}
		}
		//modeButon("select", "Select")
		//modeButon("line", "Line")
		//modeButon("rect", "Rect")
		//modeButon("circle", "Circle")
		spacer()

		if state.currentMode != .select {
			if clay.UI(clay.ID("PropertiesPanel"))(
			{
				layout = {
					sizing = {width = clay.SizingGrow({}), height = clay.SizingFit({})},
					layoutDirection = .TopToBottom,
					padding = clay.PaddingAll(10),
					childGap = 10,
				},
				backgroundColor = COLOR_WINDOW_BG, // Or a slightly different shade
				cornerRadius = clay.CornerRadiusAll(8),
			},
			) {
				// 1. Title
				clay.Text("Parameters", clay.TextConfig({fontSize = 24, textColor = COLOR_TEXT}))

				// 2. Dynamic Inputs based on Mode
				switch state.currentMode {
				case .drawLine:
					// Assuming enum names based on your comments
					inputField("X Start", "0")
					inputField("Y Start", "0")
					inputField("X End", "100")
					inputField("Y End", "100")

				case .drawRect:
					inputField("X Pos", "50")
					inputField("Y Pos", "50")
					inputField("Width", "200")
					inputField("Height", "150")

				case .drawCircle:
					inputField("Center X", "100")
					inputField("Center Y", "100")
					inputField("Radius", "50")

				case .select:
					clay.Text(
						"Select an object to edit",
						clay.TextConfig({fontSize = 16, textColor = COLOR_TEXT}),
					)
				}

				spacer()

				// 3. Draw / Action Button
				// Only show this button if we are in a creation mode
				if actionButton("Draw Shape") {
					// TODO: Add logic here to take values from inputs 
					// and push the new shape to your entities list
					fmt.println("Draw button clicked for mode:", state.currentMode)
				}
			}
		}
	}
}


createLayout :: proc(state: ^State) -> clay.ClayArray(clay.RenderCommand) {


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

		if state.selectedIdx != -1 {
			shapeInfoOverlay(state)
		}
	}

	return clay.EndLayout()

}

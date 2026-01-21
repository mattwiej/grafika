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

//ToolDef :: struct {
//	mode:  Mode,
//	label: string,
//}
//
//TOOLS_UI_CONFIG :: [?]ToolDef {
//	{.select, "Select"},
//	{.drawLine, "Line"},
//	{.drawRect, "Rect"},
//	{.drawCircle, "Circle"},
//}

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

clay_button :: proc(text: string, color: clay.Color) -> bool {
	clicked := false
	if clay.UI(clay.ID(text))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(40)},
			padding = clay.PaddingAll(10),
		},
		backgroundColor = color,
		cornerRadius = clay.CornerRadiusAll(8),
	},
	) {
		clay.TextDynamic(text, clay.TextConfig({fontSize = 18, textColor = {255, 255, 255, 255}}))
		if clay.PointerOver(clay.GetElementId(clay.MakeString(text))) &&
		   rl.IsMouseButtonPressed(.LEFT) {
			clicked = true
		}
	}
	return clicked
}

PropertyInput :: proc(label: string, value: ^$T, id: u32, state: ^State) {

	HEIGHT :: 30

	isActive := (state.activeInputId == id)

	bgCol := isActive ? clay.Color{255, 255, 255, 255} : clay.Color{230, 230, 230, 255}
	textCol := isActive ? clay.Color{0, 0, 0, 255} : clay.Color{50, 50, 50, 255}
	borderCol := isActive ? clay.Color{70, 130, 180, 255} : clay.Color{180, 180, 180, 255}

	if clay.UI(clay.ID(label, id))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(HEIGHT)},
			childGap = 5,
			layoutDirection = .LeftToRight,
			childAlignment = {y = .Center},
		},
	},
	) {
		clay.TextDynamic(
			label,
			clay.TextConfig(
				{fontSize = 16, fontId = FONT_ID_BODY_16, textColor = {200, 200, 200, 255}},
			),
		)

		elementId := clay.ID("InputBg", id)

		if clay.UI(elementId)(
		{
			layout = {
				sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
				padding = {left = 8, right = 8},
				childAlignment = {y = .Center},
			},
			backgroundColor = bgCol,
			cornerRadius = clay.CornerRadiusAll(4),
			border = {width = clay.BorderAll(1), color = borderCol},
		},
		) {

			isHovered := clay.PointerOver(elementId)

			if isActive {
				key := rl.GetCharPressed()
				for key > 0 {
					valid := false

					when T == f32 {
						valid = (key >= '0' && key <= '9') || key == '.' || key == '-'
					} else when T == int || T == u8 || T == i32 {
						valid = (key >= '0' && key <= '9') || key == '-'
					} else {
						valid = true
					}

					if valid && state.bufferLen < len(state.buffer) {
						state.buffer[state.bufferLen] = u8(key)
						state.bufferLen += 1
					}
					key = rl.GetCharPressed()
				}

				if (rl.IsKeyPressed(.BACKSPACE) || rl.IsKeyPressedRepeat(.BACKSPACE)) &&
				   state.bufferLen > 0 {
					state.bufferLen -= 1
				}

				shouldCommit := rl.IsKeyPressed(.ENTER)
				if !isHovered && rl.IsMouseButtonPressed(.LEFT) {
					shouldCommit = true
				}

				if shouldCommit {
					valStr := string(state.buffer[:state.bufferLen])

					when T == f32 {
						if res, ok := strconv.parse_f32(valStr); ok {
							value^ = res
						}
					} else when T == int {
						if res, ok := strconv.parse_int(valStr); ok {
							value^ = res
						}
					} else when T == u8 {
						if res, ok := strconv.parse_uint(valStr); ok {
							value^ = u8(res)
						}
					}

					state.activeInputId = 0
				}

				if rl.IsKeyPressed(.ESCAPE) {
					state.activeInputId = 0
				}

				displayStr := fmt.tprint(string(state.buffer[:state.bufferLen]), "|")
				clay.TextDynamic(
					displayStr,
					clay.TextConfig(
						{fontSize = 16, fontId = FONT_ID_BODY_16, textColor = textCol},
					),
				)

			} else {

				if isHovered {
					rl.SetMouseCursor(.IBEAM)

					if rl.IsMouseButtonPressed(.LEFT) {
						state.activeInputId = id

						valStr := fmt.tprint(value^)

						count := len(valStr)
						if count > len(state.buffer) do count = len(state.buffer)

						copy(state.buffer[:], valStr[:count])
						state.bufferLen = count
					}
				}
				rl.SetMouseCursor(.DEFAULT)
				displayStr := ""
				when T == f32 {
					displayStr = fmt.tprintf("%.2f", value^)
				} else {
					displayStr = fmt.tprint(value^)
				}

				clay.TextDynamic(
					displayStr,
					clay.TextConfig(
						{fontSize = 16, fontId = FONT_ID_BODY_16, textColor = textCol},
					),
				)
			}
		}
	}
}

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
		PropertyInput("X", &vec.x, baseId, state)
		PropertyInput("Y", &vec.y, baseId + 1, state)
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
		clay.TextDynamic(
			"Ustawienia",
			clay.TextConfig({fontSize = 24, fontId = FONT_ID_BODY_24, textColor = COLOR_TEXT}),
		)

		PropertyInput("Stopien (N)", &state.bezierOrder, 99999, state)
		if actionButton("Reset") {
			clear(&state.controlPoints)
			state.controlPointsCount = 0
		}
		clay.TextDynamic(
			"Punkty Kontrolne",
			clay.TextConfig({fontSize = 20, fontId = FONT_ID_BODY_24, textColor = COLOR_TEXT}),
		)

		for &p, idx in state.controlPoints {
			id_base := u32(1000 + idx * 100)

			label := fmt.tprint("P", idx)

			vec: [2]f32 = {p.x, p.y}
			RowVector2(label, &vec, id_base, state)

			p.x = vec.x
			p.y = vec.y
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
		}
	}

	return clay.EndLayout()

}

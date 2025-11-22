package main

import clay "clay-odin"
import "core:fmt"
import rl "vendor:raylib"

COLOR_WINDOW_BG :: clay.Color{43, 43, 43, 240}
COLOR_BORDER :: clay.Color{100, 100, 100, 255}
COLOR_TEXT :: clay.Color{255, 255, 255, 255}
COLOR_DEBUG_PINK :: clay.Color{255, 192, 203, 240}
COLOR_MODE_BUTTON :: clay.Color{60, 60, 60, 255}
COLOR_MODE_BUTTON_HOVER :: clay.Color{120, 120, 120, 255}
COLOR_MODE_BUTTON_ACTIVE :: clay.Color{30, 120, 90, 255}

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

spacer :: proc() {
	if clay.UI()(
	{layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})}}},
	) {}

}


PropertyInput :: proc(label: string, value: $T, index: u32) {

	if clay.UI(clay.ID(label, index))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(30)},
			childGap = 5,
			layoutDirection = .LeftToRight,
			childAlignment = {y = .Center},
		},
	},
	) {
		clay.TextDynamic(label, clay.TextConfig({fontSize = 16, textColor = COLOR_TEXT}))

		if clay.UI(clay.ID("InputBg", index))(
		{
			layout = {
				sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
				padding = {left = 5, right = 5},
				childAlignment = {y = .Center},
			},
			backgroundColor = {255, 255, 255, 255},
			cornerRadius = clay.CornerRadiusAll(5),
			border = {width = clay.BorderAll(1), color = COLOR_BORDER},
		},
		) {
			val_str := fmt.tprint(value)
			clay.TextDynamic(val_str, clay.TextConfig({fontSize = 16, textColor = {0, 0, 0, 255}}))
		}
	}
}

RowVector2 :: proc(label: string, vec: [2]f32, base_index: u32) {
	clay.TextDynamic(label, clay.TextConfig({fontSize = 18, textColor = COLOR_TEXT}))

	if clay.UI(clay.ID("Row", base_index))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({})},
			childGap = 10,
			layoutDirection = .LeftToRight,
		},
	},
	) {
		PropertyInput("X", vec.x, base_index)
		PropertyInput("Y", vec.y, base_index + 1)
	}
}
shapeLinePositionInfo :: proc(shape: Shape) {
	data := shape.kind.(LineData)
	RowVector2("Start Point", data.start, 100)
	RowVector2("End Point", data.end, 110)}

shapeRectPositionInfo :: proc(shape: Shape) {
	data := shape.kind.(RectData)

	RowVector2("Position", data.start, 200)


	clay.Text("Size", clay.TextConfig({fontSize = 18, textColor = COLOR_TEXT}))
	if clay.UI(clay.ID("RectSizeRow", 210))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({})},
			childGap = 10,
			layoutDirection = .LeftToRight,
		},
	},
	) {
		PropertyInput("W", data.size.x, 211)
		PropertyInput("H", data.size.y, 212)
	}
}

shapeCirclePositionInfo :: proc(shape: Shape) {
	data := shape.kind.(CircleData)

	RowVector2("Center", data.center, 300)
	clay.Text("Dimensions", clay.TextConfig({fontSize = 18, textColor = COLOR_TEXT}))
	PropertyInput("Radius", data.radius, 310)
}

shapePositionInfo :: proc(shape: Shape) {
	switch v in shape.kind {
	case LineData:
		shapeLinePositionInfo(shape)
	case RectData:
		shapeRectPositionInfo(shape)
	case CircleData:
		shapeCirclePositionInfo(shape)
	}
}

shapeColorInfo :: proc(shape: Shape) {
	clay.Text("Color (RGBA)", clay.TextConfig({fontSize = 18, textColor = COLOR_TEXT}))

	if clay.UI(clay.ID("ColorRow", 400))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({})},
			childGap = 5,
			layoutDirection = .LeftToRight,
		},
	},
	) {
		PropertyInput("R", shape.color[0], 401)
		PropertyInput("G", shape.color[1], 402)
		PropertyInput("B", shape.color[2], 403)
		PropertyInput("A", shape.color[3], 404)
	}

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

	selectedShape := state.shapes[state.selectedIdx]
	if clay.UI(clay.ID("EditWindow"))(
	{
		layout = {
			sizing = {width = clay.SizingFixed(250), height = clay.SizingFit({})},
			layoutDirection = .TopToBottom,
			padding = clay.PaddingAll(10),
			childGap = 10,
		},
		backgroundColor = COLOR_DEBUG_PINK,
		cornerRadius = clay.CornerRadiusAll(10),
		border = {width = clay.BorderAll(1), color = COLOR_BORDER},
	},
	) {
		if clay.UI(clay.ID("EditWindowHeadder"))(
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
				"Properties",
				clay.TextConfig(
					{fontSize = 36, fontId = FONT_ID_TITLE_36, textColor = COLOR_TEXT},
				),
			)
			spacer()
			// 1. ID
		}
		PropertyInput("ID", selectedShape.id, 500)

		// 2. Pozycja i Wymiary (Zależne od typu)
		shapePositionInfo(selectedShape)

		spacer()

		// 3. Kolor (Wspólne dla wszystkich)
		shapeColorInfo(selectedShape)

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
		fmt.printfln("klikej %s", id)
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

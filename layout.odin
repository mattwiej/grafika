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
	{.select, "select"},
	{.drawLine, "Line"},
	{.drawRect, "Rect"},
	{.drawCircle, "Circle"},
}

spacer :: proc() {
	if clay.UI()(
	{layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})}}},
	) {}

}

shapeInfoOverlay :: proc(state: ^State) {
	if clay.UI(clay.ID("EditWindow"))(
	{
		layout = {
			sizing = {width = clay.SizingFixed(250), height = clay.SizingFit({})},
			layoutDirection = .TopToBottom,
			padding = clay.PaddingAll(10),
			childGap = 10,
		},
		backgroundColor = COLOR_WINDOW_BG,
		cornerRadius = clay.CornerRadiusAll(10),
		border = {width = clay.BorderAll(1), color = COLOR_BORDER},
	},
	) {
		clay.Text("Properties", clay.TextConfig({fontSize = 24, textColor = COLOR_TEXT}))
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

	mobileScreen := windowWidth < 750

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

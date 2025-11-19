package main

import clay "clay-odin"
import "core:c"
import "core:fmt"
import rl "vendor:raylib"


windowWidth: i32 = 1024
windowHeight: i32 = 768
FONT_ID_BODY_16 :: 0
FONT_ID_TITLE_56 :: 9
FONT_ID_TITLE_52 :: 1
FONT_ID_TITLE_48 :: 2
FONT_ID_TITLE_36 :: 3
FONT_ID_TITLE_32 :: 4
FONT_ID_BODY_36 :: 5
FONT_ID_BODY_30 :: 6
FONT_ID_BODY_28 :: 7
FONT_ID_BODY_24 :: 8

errorHandler :: proc "c" (errorData: clay.ErrorData) {
	if (errorData.errorType == clay.ErrorType.DuplicateId) {
		// etc
	}
}

loadFont :: proc(fontId: u16, fontSize: u16, path: cstring) {
	assign_at(
		&raylib_fonts,
		fontId,
		Raylib_Font {
			font = rl.LoadFontEx(path, cast(i32)fontSize * 2, nil, 0),
			fontId = cast(u16)fontId,
		},
	)
	rl.SetTextureFilter(raylib_fonts[fontId].font.texture, rl.TextureFilter.TRILINEAR)
}

main :: proc() {


	minMemorySize: c.size_t = cast(c.size_t)clay.MinMemorySize()
	memory := make([^]u8, minMemorySize)
	arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(minMemorySize, memory)
	clay.Initialize(
		arena,
		{cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()},
		{handler = errorHandler},
	)
	clay.SetMeasureTextFunction(measure_text, nil)

	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(windowWidth, windowHeight, "Grafika_1")
	rl.SetTargetFPS(rl.GetMonitorRefreshRate(0))


	loadFont(FONT_ID_TITLE_56, 56, "resources/Calistoga-Regular.ttf")
	loadFont(FONT_ID_TITLE_52, 52, "resources/Calistoga-Regular.ttf")
	loadFont(FONT_ID_TITLE_48, 48, "resources/Calistoga-Regular.ttf")
	loadFont(FONT_ID_TITLE_36, 36, "resources/Calistoga-Regular.ttf")
	loadFont(FONT_ID_TITLE_32, 32, "resources/Calistoga-Regular.ttf")
	loadFont(FONT_ID_BODY_36, 36, "resources/Quicksand-Semibold.ttf")
	loadFont(FONT_ID_BODY_30, 30, "resources/Quicksand-Semibold.ttf")
	loadFont(FONT_ID_BODY_28, 28, "resources/Quicksand-Semibold.ttf")
	loadFont(FONT_ID_BODY_24, 24, "resources/Quicksand-Semibold.ttf")
	loadFont(FONT_ID_BODY_16, 16, "resources/Quicksand-Semibold.ttf")


	debugModeEnabled: bool = false
	state: State
	state.showModes = false
	state.selectedIdx = -1
	finish := false
	for !rl.WindowShouldClose() {
		defer free_all(context.temp_allocator)

		windowWidth = rl.GetScreenWidth()
		windowHeight = rl.GetScreenHeight()
		if (rl.IsKeyPressed(.D)) {
			debugModeEnabled = !debugModeEnabled
			clay.SetDebugModeEnabled(debugModeEnabled)
		}
		if (rl.IsKeyPressed(.I)) {
			state.showModes = !state.showModes
			//state.isDrawing = false
			//finish = false
		}
		clay.SetPointerState(
			transmute(clay.Vector2)rl.GetMousePosition(),
			rl.IsMouseButtonDown(rl.MouseButton.LEFT),
		)
		clay.UpdateScrollContainers(
			false,
			transmute(clay.Vector2)rl.GetMouseWheelMoveV(),
			rl.GetFrameTime(),
		)
		clay.SetLayoutDimensions({cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()})
		renderCommands: clay.ClayArray(clay.RenderCommand) = createLayout(&state)
		rl.BeginDrawing()
		rl.ClearBackground(rl.WHITE)
		if (state.currentMode != .select && state.isDrawing == false) {

			state.isDrawing = true
			//state.drawingStartPos = rl.GetMousePosition()
		}
		if (state.isDrawing) {
			#partial switch state.currentMode {
			case .select:
				state.isDrawing = false
			case .drawLine:
				if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) && !state.showModes {
					state.drawingStartPos = rl.GetMousePosition()
					finish = true
				}
				if (finish) {
					rl.DrawLineV(state.drawingStartPos, rl.GetMousePosition(), rl.BLACK)
				}
			}}

		clay_raylib_render(&renderCommands)
		//fmt.printfln("mode: %d", state.currentMode)
		rl.EndDrawing()
	}
}

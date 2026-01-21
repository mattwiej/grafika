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
	state.bezierOrder = 3
	for !rl.WindowShouldClose() {
		defer free_all(context.temp_allocator)

		windowWidth = rl.GetScreenWidth()
		windowHeight = rl.GetScreenHeight()
		if (rl.IsKeyPressed(.SPACE)) {
			fmt.printfln("tablica ControlPoints: %V", state.controlPoints)
		}
		if (rl.IsKeyPressed(.D)) {
			debugModeEnabled = !debugModeEnabled
			clay.SetDebugModeEnabled(debugModeEnabled)
		}
		if (rl.IsKeyPressed(.I)) {
			state.showModes = !state.showModes
			state.isDrawing = false
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


		mousePos := rl.GetMousePosition()
		mousePoint := Point{mousePos.x, mousePos.y}

		isMouseOverUI := clay.PointerOver(clay.GetElementId(clay.MakeString("ToolsWindow")))

		if state.isDragging && state.selectedIdx != -1 {
			if rl.IsMouseButtonReleased(.LEFT) {
				state.isDragging = false
			} else {
				state.controlPoints[state.selectedIdx] = mousePoint
			}
		} else if rl.IsMouseButtonPressed(.LEFT) && !isMouseOverUI {
			found := false
			for p, idx in state.controlPoints {
				if distance_sq(p, mousePoint) < 400 {
					state.selectedIdx = idx
					state.isDragging = true
					found = true
					break
				}
			}

			if !found {
				if state.controlPointsCount < state.bezierOrder + 1 {
					append(&state.controlPoints, mousePoint)
					state.controlPointsCount += 1
				}
			}
		}


		renderCommands: clay.ClayArray(clay.RenderCommand) = createLayout(&state)
		rl.BeginDrawing()

		if len(state.controlPoints) > 1 {
			for i in 0 ..< len(state.controlPoints) - 1 {
				p1 := state.controlPoints[i]
				p2 := state.controlPoints[i + 1]
				rl.DrawLineV({p1.x, p1.y}, {p2.x, p2.y}, rl.LIGHTGRAY)
			}
		}
		segments := 400
		if len(state.controlPoints) >= 2 {
			prevP := state.controlPoints[0]
			for i in 1 ..= segments {
				t := f32(i) / f32(segments)

				currP := evaluate_bezier(state.controlPoints[:], t)

				rl.DrawLineEx({prevP.x, prevP.y}, {currP.x, currP.y}, 3.0, rl.RED)
				prevP = currP
			}
		}

		for p, idx in state.controlPoints {
			color := (idx == state.selectedIdx) ? rl.ORANGE : rl.BLUE
			rl.DrawCircleV({p.x, p.y}, 8, color)
			rl.DrawText(fmt.ctprint(idx), i32(p.x) + 10, i32(p.y) - 10, 20, rl.BLACK)
		}

		rl.ClearBackground(rl.WHITE)
		clay_raylib_render(&renderCommands)
		//fmt.printfln("mode: %d", state.currentMode)
		rl.EndDrawing()
	}
}

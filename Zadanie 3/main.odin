package main

import clay "clay-odin"
import "core:c"
import "core:fmt"
import "core:math"
import "core:time"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"


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

gen_hsv_cone_mesh :: proc(slices: i32, radius: f32, height: f32) -> rl.Mesh {
	mesh := rl.Mesh{}

	vertexCount := 2 + slices + 1

	triangleCount := slices * 2

	mesh.vertexCount = cast(i32)vertexCount
	mesh.triangleCount = cast(i32)triangleCount

	vertices := make([]f32, vertexCount * 3)
	colors := make([]u8, vertexCount * 4)
	indices := make([]u16, triangleCount * 3)


	// Index 0: Czubek (Dół) - Czarny (0,0,0)
	vertices[0] = 0;vertices[1] = 0;vertices[2] = 0
	colors[0] = 0;colors[1] = 0;colors[2] = 0;colors[3] = 255

	// Index 1: Środek Podstawy (Góra) - Biały (255,255,255)
	vertices[3] = 0;vertices[4] = height;vertices[5] = 0
	colors[4] = 255;colors[5] = 255;colors[6] = 255;colors[7] = 255

	for i in 0 ..= slices {
		angle := (cast(f32)i / cast(f32)slices) * 360.0
		rad := (cast(f32)i / cast(f32)slices) * 2.0 * math.PI

		x := math.cos(rad) * radius
		z := math.sin(rad) * radius

		vIndex := 2 + i
		baseV := vIndex * 3
		baseC := vIndex * 4

		vertices[baseV] = x
		vertices[baseV + 1] = height
		vertices[baseV + 2] = z

		// Kolor: Raylib ColorFromHSV oczekuje (Hue, Sat, Val)
		// Hue = angle, Sat = 1.0, Val = 1.0 (bo jesteśmy na górze i na krawędzi)
		col := rl.ColorFromHSV(angle, 1.0, 1.0)

		colors[baseC] = col.r
		colors[baseC + 1] = col.g
		colors[baseC + 2] = col.b
		colors[baseC + 3] = 255
	}

	idx := 0

	for i in 0 ..< slices {
		current_rim := cast(u16)(2 + i)
		next_rim := cast(u16)(2 + i + 1)
		center_tip := cast(u16)0
		center_base := cast(u16)1

		indices[idx] = center_tip
		indices[idx + 1] = next_rim
		indices[idx + 2] = current_rim
		idx += 3

		indices[idx] = center_base
		indices[idx + 1] = current_rim
		indices[idx + 2] = next_rim
		idx += 3
	}

	mesh.vertices = raw_data(vertices)
	mesh.colors = raw_data(colors)
	mesh.indices = raw_data(indices)

	rl.UploadMesh(&mesh, false)

	delete(vertices)
	delete(colors)
	delete(indices)

	return mesh
}

draw_hsv_slice :: proc(val: f32, posX: i32, posY: i32) {
	radius: f32 = 80.0 //* val
	center := rl.Vector2{cast(f32)posX, cast(f32)posY}

	rl.DrawText("Przekrój (Poziom V)", posX - 60, posY - 110, 20, rl.BLACK)

	rlgl.PushMatrix()
	rlgl.Translatef(center.x, center.y, 0)

	rlgl.Begin(rlgl.TRIANGLES)
	segments := 72
	for i in 0 ..< segments {
		angle1 := (cast(f32)i / cast(f32)segments) * 360.0
		angle2 := (cast(f32)(i + 1) / cast(f32)segments) * 360.0

		centerCol := rl.ColorFromHSV(0, 0.0, val)
		edgeCol1 := rl.ColorFromHSV(angle1, 1.0, val)
		edgeCol2 := rl.ColorFromHSV(angle2, 1.0, val)

		rlgl.Color4ub(centerCol.r, centerCol.g, centerCol.b, 255)
		rlgl.Vertex2f(0, 0)

		rlgl.Color4ub(edgeCol1.r, edgeCol1.g, edgeCol1.b, 255)
		rlgl.Vertex2f(
			math.cos(rl.DEG2RAD * angle1) * radius,
			math.sin(rl.DEG2RAD * angle1) * radius,
		)

		rlgl.Color4ub(edgeCol2.r, edgeCol2.g, edgeCol2.b, 255)
		rlgl.Vertex2f(
			math.cos(rl.DEG2RAD * angle2) * radius,
			math.sin(rl.DEG2RAD * angle2) * radius,
		)
	}
	rlgl.End()
	rlgl.PopMatrix()

	rl.DrawCircleLines(posX, posY, radius, rl.BLACK)
	rl.DrawText(
		fmt.ctprintf("V: %.2f", val),
		posX - 20,
		posY + cast(i32)radius + 10,
		20,
		rl.DARKGRAY,
	)
}

draw_hsv_triangle_slice :: proc(hue: f32, posX: i32, posY: i32) {
	width: f32 = 150.0
	height: f32 = 200.0

	startPos := rl.Vector2{cast(f32)posX, cast(f32)posY}

	vTip := rl.Vector2{startPos.x, startPos.y}
	vTopCenter := rl.Vector2{startPos.x, startPos.y - height}
	vTopEdge := rl.Vector2{startPos.x + width, startPos.y - height}

	cTip := rl.BLACK
	cTopCenter := rl.WHITE
	cTopEdge := rl.ColorFromHSV(hue, 1.0, 1.0)

	rl.DrawText("Przekrój", posX, posY - cast(i32)height - 30, 20, rl.BLACK)

	rlgl.DrawRenderBatchActive()

	rlgl.DisableBackfaceCulling()
	rlgl.DisableDepthTest()

	rlgl.SetTexture(0)

	rlgl.Begin(rlgl.TRIANGLES)

	// Wierzchołek 1: Czubek (Czarny)
	rlgl.Color4ub(cTip.r, cTip.g, cTip.b, cTip.a)
	rlgl.Vertex2f(vTip.x, vTip.y)

	// Wierzchołek 2: Góra-Środek (Biały)
	rlgl.Color4ub(cTopCenter.r, cTopCenter.g, cTopCenter.b, cTopCenter.a)
	rlgl.Vertex2f(vTopCenter.x, vTopCenter.y)

	// Wierzchołek 3: Góra-Krawędź (Kolor)
	rlgl.Color4ub(cTopEdge.r, cTopEdge.g, cTopEdge.b, cTopEdge.a)
	rlgl.Vertex2f(vTopEdge.x, vTopEdge.y)

	rlgl.End()

	rlgl.SetTexture(0)

	rl.DrawLineEx(vTip, vTopCenter, 2.0, rl.BLACK)
	rl.DrawLineEx(vTopCenter, vTopEdge, 2.0, rl.BLACK)
	rl.DrawLineEx(vTopEdge, vTip, 2.0, rl.BLACK)

	rl.DrawText("Sat ->", posX + 60, posY + 10, 16, rl.DARKGRAY)
	rl.DrawText("Val ^", posX - 40, posY - 100, 16, rl.DARKGRAY)
	rl.DrawText(fmt.ctprintf("Hue: %.0f", hue), posX, posY + 30, 20, rl.BLACK)
}
SliceMode :: enum {
	Horizontal,
	Vertical,
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
	rl.SetExitKey(.KEY_NULL)

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
	state: State_models
	state.rgb = {
		r = 100,
		g = 70,
		b = 135,
	}
	state.rgbFlag = true
	camera := rl.Camera3D{}
	camera.position = {4.0, 4.0, 4.0}
	camera.target = {0.0, 0.5, 0.0}
	camera.up = {0.0, 1.0, 0.0}
	camera.fovy = 45.0
	camera.projection = .PERSPECTIVE


	coneMesh := gen_hsv_cone_mesh(144, 1.0, 2.0)
	coneModel := rl.LoadModelFromMesh(coneMesh)

	sliceHeight: f32 = 0.5
	sliceMode := SliceMode.Horizontal
	sliceAngle: f32 = 0.0

	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		defer free_all(context.temp_allocator)

		if state.rgbFlag {

			state.cmyk = RGB_To_CMYK(state.rgb)
			state.rgbFlag = false

		}

		if state.cmykFlag {

			state.rgb = CMYK_To_RGB(state.cmyk)
			state.cmykFlag = false

		}

		windowWidth = rl.GetScreenWidth()
		windowHeight = rl.GetScreenHeight()
		if (rl.IsKeyPressed(.D)) {
			debugModeEnabled = !debugModeEnabled
			clay.SetDebugModeEnabled(debugModeEnabled)
		}
		if (rl.IsKeyPressed(.I)) {
			state.showModes = !state.showModes
		}
		if rl.IsKeyPressed(.SPACE) {
			if sliceMode == .Horizontal {
				sliceMode = .Vertical
			} else {
				sliceMode = .Horizontal
			}
		}
		if sliceMode == .Horizontal {
			if rl.IsKeyDown(.UP) {sliceHeight = min(1.0, sliceHeight + 0.01)}
			if rl.IsKeyDown(.DOWN) {sliceHeight = max(0.0, sliceHeight - 0.01)}
		} else {
			if rl.IsKeyDown(.LEFT) {sliceAngle -= 2.0}
			if rl.IsKeyDown(.RIGHT) {sliceAngle += 2.0}

			if sliceAngle < 0 do sliceAngle += 360
			if sliceAngle > 360 do sliceAngle -= 360
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

		if rl.IsMouseButtonDown(.RIGHT) {
			rl.UpdateCamera(&camera, .ORBITAL)
		}

		rl.BeginDrawing()

		rl.ClearBackground(rl.RAYWHITE)
		rl.BeginMode3D(camera)
		rlgl.DisableBackfaceCulling()

		rl.DrawModel(coneModel, {0, 0, 0}, 1.0, rl.WHITE)

		if sliceMode == .Horizontal {
			cutY := sliceHeight * 2.0
			rl.DrawCube({0, cutY, 0}, 2.5, 0.01, 2.5, {0, 0, 0, 50})
			rl.DrawCubeWires({0, cutY, 0}, 2.5, 0.01, 2.5, rl.BLACK)
		} else {
			// 1. Obliczamy kąt w radianach (tak samo jak przy generowaniu siatki)
			// Musimy upewnić się, że konwersja jest identyczna
			rad := cast(f32)rl.DEG2RAD * sliceAngle

			// 2. Obliczamy punkt na krawędzi stożka (promień = 1.0)
			// Używamy tych samych cos/sin co w gen_hsv_cone_mesh
			rimX := math.cos(rad) * 1.0
			rimZ := math.sin(rad) * 1.0

			// 3. Rysujemy Trójkąt Cięcia w 3D (Zamiast Cube)
			// Fizycznie przekrój stożka przechodzący przez środek to trójkąt.
			// Wierzchołki: (0,0,0) -> (0, 2.0, 0) -> (rimX, 2.0, rimZ)

			rlgl.DisableBackfaceCulling() // Żeby było widać z obu stron
			rlgl.Begin(rlgl.TRIANGLES)

			// Kolor półprzezroczysty szary
			rlgl.Color4ub(50, 50, 50, 150)

			// V1: Dół stożka (Czubek)
			rlgl.Vertex3f(0, 0, 0)
			// V2: Góra środek
			rlgl.Vertex3f(0, 2.0, 0)
			// V3: Góra krawędź (tam gdzie jest kolor)
			rlgl.Vertex3f(rimX, 2.0, rimZ)

			// Drugi trójkąt, żeby zamknąć kształt w prostokąt (opcjonalnie, jak "drzwi")
			// Jeśli chcesz, żeby cięcie wyglądało jak prostokątna karta:
			rlgl.Vertex3f(0, 0, 0)
			rlgl.Vertex3f(rimX, 2.0, rimZ)
			rlgl.Vertex3f(rimX, 0, rimZ)

			rlgl.End()
			rlgl.EnableBackfaceCulling()

			// 4. Rysujemy ramkę (linię), żeby wyraźnie widzieć krawędź
			rl.DrawLine3D({0, 2.0, 0}, {rimX, 2.0, rimZ}, rl.BLACK) // Góra
			rl.DrawLine3D({rimX, 2.0, rimZ}, {rimX, 0, rimZ}, rl.BLACK) // Bok zewnętrzny
			rl.DrawLine3D({rimX, 0, rimZ}, {0, 0, 0}, rl.BLACK) // Dół
		}
		rl.DrawGrid(10, 1.0)

		rl.EndMode3D()
		if sliceMode == .Horizontal {
			draw_hsv_slice(sliceHeight, 150, 600)
		} else {
			draw_hsv_triangle_slice(sliceAngle, 100, 700)
		}
		clay_raylib_render(&renderCommands)

		rl.EndDrawing()
	}
}

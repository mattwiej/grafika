package main

import "core:fmt"
import "core:time"
import rl "vendor:raylib"
//import "vendor:stb"


main :: proc() {

	state: State_models

	rl.InitWindow(800, 600, "Odin PPM Viewer - Faza 1")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	// 1. Wczytaj obraz do RAM
	start := time.now()
	my_image, loaded := LoadFile_parser("img/ppm-test-07-p3-big.ppm", &state)

	duration := time.since(start)
	fmt.printfln("wszystko i kopiowanie danych: %v", duration)
	// Zmienna na teksturę (GPU)
	texture: rl.Texture2D


	if loaded {
		// 2. Konwersja RAM -> Raylib Image
		// UWAGA: Używamy raw_data() aby przekazać wskaźnik C
		rl_image := rl.Image {
			data    = raw_data(my_image.maxVal.([dynamic]u8)),
			width   = my_image.width,
			height  = my_image.height,
			mipmaps = 1,
			format  = .UNCOMPRESSED_R8G8B8, // Format PPM to zazwyczaj czyste RGB
		}

		// 3. Upload do GPU
		texture = rl.LoadTextureFromImage(rl_image)

		// Nie zwalniamy my_image.maxValue.([dynamic]u8), bo będziesz go potrzebował później 
		// do odczytywania wartości pikseli pod myszką!
	}

	camera := rl.Camera2D {
		offset   = rl.Vector2{400, 300}, // Środek ekranu (punkt skupienia)
		target   = rl.Vector2{f32(my_image.width) / 2, f32(my_image.height) / 2}, // Środek obrazka
		rotation = 0,
		zoom     = 1.0,
	}

	// Główna pętla renderowania
	for !rl.WindowShouldClose() {
		if rl.IsMouseButtonDown(.RIGHT) {
			delta := rl.GetMouseDelta()
			delta = rl.Vector2Scale(delta, -1.0 / camera.zoom) // Skalujemy ruch odwrotnie do zoomu
			camera.target = rl.Vector2Add(camera.target, delta)
		}

		// 2. Przybliżanie (Zoom) - Kółko Myszy
		wheel := rl.GetMouseWheelMove()
		if wheel != 0 {
			// Magia zoomowania w stronę kursora:
			mouse_world_pos := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)

			camera.offset = rl.GetMousePosition()
			camera.target = mouse_world_pos

			scale_factor := 1.0 + (0.1 * abs(wheel))
			if wheel < 0 {scale_factor = 1.0 / scale_factor}

			camera.zoom = rl.Clamp(camera.zoom * scale_factor, 0.1, 50.0) // Limit zoomu 0.1x - 50x
		}
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		if loaded {
			rl.BeginMode2D(camera)
			rl.DrawTexture(texture, 0, 0, rl.WHITE)

			if camera.zoom > 5.0 {
				// Rysuj siatkę
				rl.DrawRectangleLinesEx(
					rl.Rectangle{0, 0, f32(my_image.width), f32(my_image.height)},
					1.0 / camera.zoom,
					rl.GRAY,
				)

				// Rysuj linie siatki dla każdego piksela (opcjonalne, może być wolne przy wielkich obrazach)
				// Optymalizacja: Rysuj tylko widoczne linie (culling), tu wersja prosta:


				//start_col := i32(
				//	max(0, camera.target.x - (rl.GetScreenWidth() / 2 / i32(camera.zoom))),
				//)
				//end_col := i32(
				//	min(
				//		f32(my_image.width),
				//		camera.target.x + (rl.GetScreenWidth() / 2 / i32(camera.zoom)) + 1,
				//	),
				//)
				//start_row := i32(
				//	max(0, camera.target.y - (rl.GetScreenHeight() / 2 / i32(camera.zoom))),
				//)
				//end_row := i32(
				//	min(
				//		f32(my_image.height),
				//		camera.target.y + (rl.GetScreenHeight() / 2 / i32(camera.zoom)) + 1,
				//	),
				//)

				//for y := start_row; y < end_row; y += 1 {
				//	for x := start_col; x < end_col; x += 1 {
				//		// Rysuj ramkę piksela
				//		rl.DrawRectangleLines(x, y, 1, 1, rl.Color{50, 50, 50, 100})

				//		// Wyświetl wartości RGB (tylko przy BARDZO dużym zoomie > 15)
				//		if camera.zoom > 15.0 {
				//			idx := (y * my_image.width + x) * 3
				//			r := my_image.maxVal.([dynamic]u8)[idx]
				//			g := my_image.maxVal.([dynamic]u8)[idx + 1]
				//			b := my_image.maxVal.([dynamic]u8)[idx + 2]

				//			// Kolor tekstu (kontrastowy do piksela)
				//			text_color := rl.WHITE
				//			if (int(r) + int(g) + int(b)) / 3 > 128 {
				//				text_color = rl.BLACK
				//			}

				//			font_size := f32(0.2) // Mała czcionka w świecie gry
				//			rl.DrawTextEx(
				//				rl.GetFontDefault(),
				//				fmt.ctprintf("%d", r),
				//				{f32(x) + 0.1, f32(y) + 0.1},
				//				font_size,
				//				0,
				//				rl.RED,
				//			)
				//			rl.DrawTextEx(
				//				rl.GetFontDefault(),
				//				fmt.ctprintf("%d", g),
				//				{f32(x) + 0.1, f32(y) + 0.4},
				//				font_size,
				//				0,
				//				rl.GREEN,
				//			)
				//			rl.DrawTextEx(
				//				rl.GetFontDefault(),
				//				fmt.ctprintf("%d", b),
				//				{f32(x) + 0.1, f32(y) + 0.7},
				//				font_size,
				//				0,
				//				rl.BLUE,
				//			)
				//		}
				//	}
				//}
			}

			rl.EndMode2D()
		} else {
			rl.DrawText("Błąd wczytywania", 10, 10, 20, rl.RED)
		}

		// UI Info
		rl.DrawText(fmt.ctprintf("Zoom: %.2fx", camera.zoom), 10, 570, 20, rl.LIGHTGRAY)
		rl.DrawText("PPM Drag: Pan | Scroll: Zoom", 10, 10, 20, rl.RAYWHITE)

		rl.EndDrawing()
	}

	// Sprzątanie
	if loaded {
		rl.UnloadTexture(texture)
		delete(my_image.maxVal.([dynamic]u8))
	}
}

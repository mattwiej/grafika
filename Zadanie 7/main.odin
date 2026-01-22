package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// --- STRUKTURY ---

Polygon :: struct {
	vertices:  [dynamic]rl.Vector2,
	triangles: [dynamic]rl.Vector2, // Płaska lista wierzchołków trójkątów (3 * N)
	color:     rl.Color,
}

// --- ALGORYTM TRIANGULACJI (EAR CLIPPING) ---

// Oblicza pole (ze znakiem), by sprawdzić czy figura jest "lewa" czy "prawa"
signed_area :: proc(points: []rl.Vector2) -> f32 {
	area: f32 = 0
	for i in 0 ..< len(points) {
		j := (i + 1) % len(points)
		area += (points[j].x - points[i].x) * (points[j].y + points[i].y)
	}
	return area
}

// Sprawdza, czy wierzchołek 'i' jest "uchem" (można go odciąć)
is_ear :: proc(poly: []rl.Vector2, i: int, indices: []int) -> bool {
	count := len(indices)

	// Pobieramy indeksy sąsiadów w aktualnym wielokącie
	prev_idx := indices[(i - 1 + count) % count]
	curr_idx := indices[i]
	next_idx := indices[(i + 1) % count]

	p_prev := poly[prev_idx]
	p_curr := poly[curr_idx]
	p_next := poly[next_idx]

	// 1. Sprawdź czy kąt jest wypukły (Convex)
	// W Raylib (Y-down): Dla CCW, kąt wypukły ma ujemny iloczyn wektorowy
	edge1 := rl.Vector2{p_curr.x - p_prev.x, p_curr.y - p_prev.y}
	edge2 := rl.Vector2{p_next.x - p_curr.x, p_next.y - p_curr.y}
	cross := edge1.x * edge2.y - edge1.y * edge2.x

	// Jeśli cross >= 0, to jest to wierzchołek wklęsły (Reflex) - nie możemy go odciąć
	if cross >= 0 {
		return false
	}

	// 2. Sprawdź czy ŻADEN inny punkt wielokąta nie leży wewnątrz tego trójkąta
	// To jest kluczowe dla figur wklęsłych (żeby nie zamalować "zatoki")
	for k in 0 ..< count {
		idx := indices[k]
		// Pomiń punkty tworzące ten trójkąt
		if idx == prev_idx || idx == curr_idx || idx == next_idx do continue

		p_check := poly[idx]

		// Używamy funkcji Rayliba - jest robust
		if rl.CheckCollisionPointTriangle(p_check, p_prev, p_curr, p_next) {
			return false // Inny punkt jest w środku - to nie jest ucho
		}
	}

	return true
}

triangulate :: proc(original_points: []rl.Vector2) -> [dynamic]rl.Vector2 {
	result := make([dynamic]rl.Vector2)
	n := len(original_points)
	if n < 3 do return result

	// Pracujemy na indeksach, żeby nie kopiować ciągle wektorów
	indices := make([dynamic]int, n)
	defer delete(indices)
	for i in 0 ..< n do indices[i] = i

	// A. Wymuszamy orientację CCW (Counter-Clockwise)
	// W Raylib (Y w dół), CCW ma ujemne "signed area" wg wzoru Shoelace
	// Jeśli pole jest dodatnie, to znaczy że jest Clockwise -> odwracamy
	if signed_area(original_points) > 0 {
		for i in 0 ..< n / 2 {
			indices[i], indices[n - 1 - i] = indices[n - 1 - i], indices[i]
		}
	}

	// B. Główna pętla
	count := n
	fails_safe := 0 // Bezpiecznik

	for count > 2 {
		ear_found := false

		for i in 0 ..< count {
			if is_ear(original_points, i, indices[:]) {
				// Znaleziono ucho
				idx_prev := indices[(i - 1 + count) % count]
				idx_curr := indices[i]
				idx_next := indices[(i + 1) % count]

				// Dodaj trójkąt do wyniku
				append(&result, original_points[idx_prev])
				append(&result, original_points[idx_curr])
				append(&result, original_points[idx_next])

				// Usuń wierzchołek 'i' z listy indeksów
				ordered_remove(&indices, i)
				count -= 1
				ear_found = true
				break
			}
		}

		if !ear_found {
			// Jeśli nie znaleziono ucha, wielokąt może być zdegenerowany
			break
		}

		fails_safe += 1
		if fails_safe > n * n {break} 	// Panic break
	}

	return result
}

// --- LOGIKA PROGRAMU ---

main :: proc() {
	rl.InitWindow(1000, 700, "Odin: Wklęsłe Figury (Final Fix)")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	polygons := make([dynamic]Polygon)
	defer {
		for p in polygons {delete(p.vertices);delete(p.triangles)}
		delete(polygons)
	}

	current_drawing_points := make([dynamic]rl.Vector2)
	defer delete(current_drawing_points)

	selected_poly_index := -1

	for !rl.WindowShouldClose() {
		mouse_pos := rl.GetMousePosition()
		is_drawing_active := len(current_drawing_points) > 0

		// INPUT
		if rl.IsMouseButtonPressed(.LEFT) {
			if is_drawing_active {
				append(&current_drawing_points, mouse_pos)
			} else {
				clicked_on := false
				for i := len(polygons) - 1; i >= 0; i -= 1 {
					p := &polygons[i]
					if rl.CheckCollisionPointPoly(
						mouse_pos,
						raw_data(p.vertices),
						i32(len(p.vertices)),
					) {
						selected_poly_index = i
						clicked_on = true
						break
					}
				}
				if !clicked_on {
					selected_poly_index = -1
					append(&current_drawing_points, mouse_pos)
				}
			}
		}

		if rl.IsMouseButtonPressed(.RIGHT) {
			if is_drawing_active {
				if len(current_drawing_points) >= 3 {
					// Generuj trójkąty nową metodą
					tris := triangulate(current_drawing_points[:])

					new_poly := Polygon {
						vertices  = make([dynamic]rl.Vector2, len(current_drawing_points)),
						triangles = tris,
						color     = rl.RED,
					}
					copy(new_poly.vertices[:], current_drawing_points[:])
					append(&polygons, new_poly)
					selected_poly_index = len(polygons) - 1
				}
				clear(&current_drawing_points)
			} else {
				selected_poly_index = -1
			}
		}

		// DRAW
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		for i in 0 ..< len(polygons) {
			poly := &polygons[i]
			base_color := poly.color
			if i == selected_poly_index do base_color = rl.GREEN

			// Rysuj wypełnienie (trójkąty)
			fill_color := rl.Fade(base_color, 0.4)
			for t := 0; t < len(poly.triangles); t += 3 {
				if t + 2 < len(poly.triangles) {
					// Rysujemy dwustronnie dla pewności
					p1, p2, p3 := poly.triangles[t], poly.triangles[t + 1], poly.triangles[t + 2]
					rl.DrawTriangle(p1, p2, p3, fill_color)
					rl.DrawTriangle(p3, p2, p1, fill_color)

					// Linie podziału (opcjonalne, do debugowania)
					// rl.DrawTriangleLines(p1, p2, p3, rl.Fade(rl.BLACK, 0.2)) 
				}
			}

			// Obrys
			rl.DrawLineStrip(raw_data(poly.vertices), i32(len(poly.vertices)), base_color)
			rl.DrawLineV(poly.vertices[0], poly.vertices[len(poly.vertices) - 1], base_color)

			if i == selected_poly_index {
				for v in poly.vertices do rl.DrawCircleV(v, 4, rl.YELLOW)
			}
		}

		if is_drawing_active {
			rl.DrawLineStrip(
				raw_data(current_drawing_points),
				i32(len(current_drawing_points)),
				rl.BLUE,
			)
			rl.DrawLineV(
				current_drawing_points[len(current_drawing_points) - 1],
				mouse_pos,
				rl.GRAY,
			)
		}

		rl.DrawText(
			rl.TextFormat(
				"Liczba trójkątów ost. figury: %d",
				len(polygons) > 0 ? len(polygons[len(polygons) - 1].triangles) / 3 : 0,
			),
			10,
			10,
			20,
			rl.GRAY,
		)

		rl.EndDrawing()
	}
}

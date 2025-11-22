package main

import "core:math/linalg"
import rl "vendor:raylib"

Check_Collision_Point_Rec :: proc(point, start, size: [2]f32) -> bool {
	//mamy dwie mozliwosci albo przeciagnlem myszka w prawy dolny albo w lewy gorny, jezeli w prawy dolny to size dodatni a jak w lewy gorny to size ujemny
	if (size.x > 0) {
		if point.x <= start.x + size.x &&
		   point.x >= start.x &&
		   point.y >= start.y &&
		   point.y <= start.y + size.y {
			return true
		}
	} else {
		if point.x >= start.x + size.x &&
		   point.x <= start.x &&
		   point.y <= start.y &&
		   point.y >= start.y + size.y {
			return true

		}
	}
	return false

}

Check_Collision :: proc(s: Shape, p: [2]f32) -> bool {
	switch v in s.kind {
	case LineData:
		return rl.CheckCollisionPointLine(p, v.start, v.end, 3)
	case RectData:
		//rect := rl.Rectangle{v.start.x, v.start.y, v.size.x, v.size.y}
		//return rl.CheckCollisionPointRec(p, rect)
		return Check_Collision_Point_Rec(p, v.start, v.size)
	case CircleData:
		return rl.CheckCollisionPointCircle(p, v.center, v.radius)
	}
	return false
}

Handle_Selection :: proc(state: ^State) {
	if state.currentMode == .select &&
	   rl.IsMouseButtonPressed(rl.MouseButton.LEFT) &&
	   !state.showModes {
		mousePos := rl.GetMousePosition()
		foundIdx := -1

		for i := len(state.shapes) - 1; i >= 0; i -= 1 {
			if Check_Collision(state.shapes[i], mousePos) {
				foundIdx = i
				break
			}
		}
		state.selectedIdx = foundIdx
	}
}

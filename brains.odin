package main

import "core:math"
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

shapes_Draging :: proc(state: ^State) {
	if state.selectedIdx == -1 ||
	   state.isDragging  /*troche niefortunnie nazwane ale state.isDragging odnosi sie do edycji figury poprzez ciaganie punktów specjalnych */{
		return
	}
	shape := &state.shapes[state.selectedIdx]
	if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
		delta := rl.GetMouseDelta()
		switch &v in shape.kind {
		case LineData:
			v.start += delta
			v.end += delta
		case RectData:
			v.start += delta
		case CircleData:
			v.center += delta
		}
	}
}

update_shape_edit :: proc(state: ^State) {
	if state.selectedIdx < 0 || state.selectedIdx >= len(state.shapes) {
		return
	}

	shape := &state.shapes[state.selectedIdx]
	mousePos := rl.GetMousePosition()
	HANDLE_RADIUS :: 25.0

	if !state.isDragging {
		state.draggedHandle = .None

		switch &v in shape.kind {
		case LineData:
			if rl.CheckCollisionPointCircle(mousePos, v.start, HANDLE_RADIUS) do state.draggedHandle = .LineStart
			else if rl.CheckCollisionPointCircle(mousePos, v.end, HANDLE_RADIUS) do state.draggedHandle = .LineEnd

		case RectData:
			pos, sz := v.start, v.size
			realPos := pos
			realSz := sz
			if realSz.x < 0 {realPos.x += realSz.x;realSz.x *= -1}
			if realSz.y < 0 {realPos.y += realSz.y;realSz.y *= -1}

			p1 := [2]f32{realPos.x + (realSz.x / 2), realPos.y} // Góra
			p2 := [2]f32{realPos.x + realSz.x, realPos.y + (realSz.y / 2)} // Prawo
			p3 := [2]f32{realPos.x + (realSz.x / 2), realPos.y + realSz.y} // Dół
			p4 := [2]f32{realPos.x, realPos.y + (realSz.y / 2)} // Lewo

			if rl.CheckCollisionPointCircle(mousePos, p1, HANDLE_RADIUS) do state.draggedHandle = .RectTop
			else if rl.CheckCollisionPointCircle(mousePos, p2, HANDLE_RADIUS) do state.draggedHandle = .RectRight
			else if rl.CheckCollisionPointCircle(mousePos, p3, HANDLE_RADIUS) do state.draggedHandle = .RectBottom
			else if rl.CheckCollisionPointCircle(mousePos, p4, HANDLE_RADIUS) do state.draggedHandle = .RectLeft

		case CircleData:
			p1 := [2]f32{v.center.x, v.center.y - v.radius}
			p2 := [2]f32{v.center.x + v.radius, v.center.y}
			p3 := [2]f32{v.center.x, v.center.y + v.radius}
			p4 := [2]f32{v.center.x - v.radius, v.center.y}

			if rl.CheckCollisionPointCircle(mousePos, p1, HANDLE_RADIUS) ||
			   rl.CheckCollisionPointCircle(mousePos, p2, HANDLE_RADIUS) ||
			   rl.CheckCollisionPointCircle(mousePos, p3, HANDLE_RADIUS) ||
			   rl.CheckCollisionPointCircle(mousePos, p4, HANDLE_RADIUS) {
				state.draggedHandle = .CircleRadius
			}
		}

		if state.draggedHandle != .None && rl.IsMouseButtonPressed(.LEFT) {
			state.isDragging = true
		}
	}

	if state.isDragging {
		if rl.IsMouseButtonReleased(.LEFT) {
			state.isDragging = false
			state.draggedHandle = .None
			return
		}

		switch &v in shape.kind {
		case LineData:
			if state.draggedHandle == .LineStart {
				v.start = mousePos
			} else if state.draggedHandle == .LineEnd {
				v.end = mousePos
			}

		case RectData:
			#partial switch state.draggedHandle {
			case .RectTop:
				bottomY := v.start.y + v.size.y
				v.start.y = mousePos.y
				v.size.y = bottomY - v.start.y
			case .RectBottom:
				v.size.y = mousePos.y - v.start.y
			case .RectLeft:
				rightX := v.start.x + v.size.x
				v.start.x = mousePos.x
				v.size.x = rightX - v.start.x
			case .RectRight:
				v.size.x = mousePos.x - v.start.x
			case:
			}

		case CircleData:
			if state.draggedHandle == .CircleRadius {
				dx := mousePos.x - v.center.x
				dy := mousePos.y - v.center.y
				v.radius = math.sqrt(dx * dx + dy * dy)
			}
		}
	}
}

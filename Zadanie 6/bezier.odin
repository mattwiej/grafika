package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

lerp_custom :: proc(start, end: Point, t: f32) -> Point {
	return Point{x = start.x + (end.x - start.x) * t, y = start.y + (end.y - start.y) * t}
}

allocateSpace :: proc(state: ^State) {
	if state.controlPoints != nil {
		delete(state.controlPoints)
	}
	state.controlPoints = make([dynamic]Point, state.bezierOrder + 1)
}

evaluate_bezier :: proc(points: []Point, t: f32, allocator := context.temp_allocator) -> Point {
	if len(points) == 0 do return {0, 0}
	if len(points) == 1 do return points[0]

	temp_points := make([dynamic]Point, 0, len(points), allocator)
	for p in points {
		append(&temp_points, p)
	}

	n := len(temp_points)

	for k := 1; k < n; k += 1 {
		for i := 0; i < (n - k); i += 1 {
			p0 := temp_points[i]
			p1 := temp_points[i + 1]
			p0.x = p0.x * (1 - t) + p1.x * t
			p0.y = p0.y * (1 - t) + p1.y * t
			temp_points[i] = p0
			//temp_points[i] = temp_points[i] * (1 - t) + temp_points[i + 1] * t //lerp_custom(temp_points[i], temp_points[i + 1], t)
		}
	}

	return temp_points[0]
}


distance_sq :: proc(a, b: Point) -> f32 {
	dx := a.x - b.x
	dy := a.y - b.y
	return dx * dx + dy * dy
}

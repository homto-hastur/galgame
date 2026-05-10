extends Node2D

# 用 Godot 內建繪圖功能繪製連接箭頭
# 由 map.gd 呼叫，傳入起點和終點座標

var lines: Array = []  # 每個元素: { "from": Vector2, "to": Vector2 }


func set_lines(data: Array) -> void:
	lines = data
	queue_redraw()


func clear_lines() -> void:
	lines.clear()
	queue_redraw()


func _draw() -> void:
	for entry in lines:
		var from: Vector2 = entry["from"]
		var to: Vector2 = entry["to"]
		_draw_arrow_line(from, to)


func _draw_arrow_line(from: Vector2, to: Vector2) -> void:
	var dir := to - from
	var angle := atan2(dir.y, dir.x)
	
	# 兩端偏移，避開按鈕位置（加大偏移讓線條更短，減少雜亂感）
	var offset := 75.0
	var start_pos := from + Vector2(cos(angle), sin(angle)) * offset
	var end_pos := to - Vector2(cos(angle), sin(angle)) * offset
	
	# 黑色、加粗、虛線
	var line_color := Color(0.0, 0.0, 0.0, 0.7)
	var line_width := 5.0
	
	# 繪製虛線連接線（使用 Godot 內建虛線繪圖）
	draw_dashed_line(start_pos, end_pos, line_color, line_width, 12.0, 8.0, true)
	
	# 繪製箭頭頭部（三角形）- 黑色
	var arrow_size := 16.0
	var arrow_angle := 0.45  # 約 25 度
	
	# 箭頭尖端在 end_pos
	var tip := end_pos
	var left := tip + Vector2(
		- cos(angle - arrow_angle) * arrow_size,
		- sin(angle - arrow_angle) * arrow_size
	)
	var right := tip + Vector2(
		- cos(angle + arrow_angle) * arrow_size,
		- sin(angle + arrow_angle) * arrow_size
	)
	
	var arrow_head := PackedVector2Array([tip, left, right])
	draw_polygon(arrow_head, PackedColorArray([line_color]))

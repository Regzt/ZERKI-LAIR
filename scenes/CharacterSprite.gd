extends Node2D

@onready var tail = $Tail
@onready var torso = $Torso
@onready var clothes = $Clothes
@onready var head = $Head
@onready var hair = $Hair
@onready var hats = $Hats
@onready var eye_left = $EyeLeft
@onready var eye_right = $EyeRight

func _ready() -> void:
	apply_skin(GameState.skin)

func _get_texture(category: String, index: int):
	if not GameState.parts_db.has(category): return null
	var parts = GameState.parts_db[category]
	if index < 0 or index >= parts.size(): return null
	var path = parts[index]["path"]
	if path == "" or not ResourceLoader.exists(path): return null
	return load(path)

func apply_skin(skin: Dictionary) -> void:
	if GameState.parts_db.is_empty():
		return

	var body_idx = skin.get("body_index", 0)
	var body_tex = _get_texture("body", body_idx)
	
	# Позиции
	var h_pos = [0, 0]
	var e_pos = [0, 0]
	var c_pos = [0, 0]
	var hair_p = [0, 0]
	var hats_p = [0, 0]
	var t_pos = [0, 0]

	# Если у выбранного тела есть координаты в базе, берем их!
	if GameState.parts_db.has("body") and body_idx < GameState.parts_db["body"].size():
		var body_data = GameState.parts_db["body"][body_idx]
		h_pos = body_data.get("head_pos", [0, 0])
		e_pos = body_data.get("eyes_pos", [0, 0])
		c_pos = body_data.get("clothes_pos", [0, 0])
		hair_p = body_data.get("hair_pos", [0, 0])
		hats_p = body_data.get("hats_pos", [0, 0])
		t_pos = body_data.get("tail_pos", [0, 0])

	# ТЭКСТУРРЕН
	
	# Тело
	if body_tex: torso.texture = body_tex
	else: torso.texture = null

	# Голова
	head.position = Vector2(h_pos[0], h_pos[1])
	var head_tex = _get_texture("head", skin.get("head_index", 0))
	if head_tex: head.texture = head_tex
	else: head.texture = null

	# Глаза
	eye_left.position = Vector2(e_pos[0], e_pos[1])
	eye_right.position = Vector2(-e_pos[0], e_pos[1]) 
	var eyes_tex = _get_texture("eyes", skin.get("eyes_index", 0))
	if eyes_tex: 
		eye_left.texture = eyes_tex
		eye_right.texture = eyes_tex
	else:
		eye_left.texture = null
		eye_right.texture = null

	# Одежда
	clothes.position = Vector2(c_pos[0], c_pos[1])
	var clothes_tex = _get_texture("clothes", skin.get("clothes_index", 0))
	if clothes_tex: clothes.texture = clothes_tex
	else: clothes.texture = null

	# Волосы
	hair.position = Vector2(hair_p[0], hair_p[1])
	var hair_tex = _get_texture("hair", skin.get("hair_index", 0))
	if hair_tex: hair.texture = hair_tex
	else: hair.texture = null

	# Шляпа
	hats.position = Vector2(hats_p[0], hats_p[1])
	var hats_tex = _get_texture("hats", skin.get("hats_index", 0))
	if hats_tex: hats.texture = hats_tex
	else: hats.texture = null

	# Хвост
	tail.position = Vector2(t_pos[0], t_pos[1])
	var tail_tex = _get_texture("tail", skin.get("tail_index", 0))
	if tail_tex:
		tail.texture = tail_tex
		tail.visible = true
	else:
		tail.visible = false

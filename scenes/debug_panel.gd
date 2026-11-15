extends Panel

@onready var part_selector = $VBoxContainer/PartSelector
@onready var spin_x = $VBoxContainer/SpinX
@onready var spin_y = $VBoxContainer/SpinY
@onready var save_button = $VBoxContainer/SaveJsonButton

var current_player: Node = null
var current_part: Node = null

func _ready() -> void:
	current_player = get_tree().get_first_node_in_group("local_player")
	
	spin_x.value_changed.connect(_on_value_changed)
	spin_y.value_changed.connect(_on_value_changed)
	part_selector.item_selected.connect(_on_part_selected)
	save_button.pressed.connect(_on_save_pressed)

func _on_part_selected(index: int) -> void:
	if not current_player: return
	match index:
		0: current_part = current_player.find_child("Hats", true, false)
		1: current_part = current_player.find_child("Head", true, false)
		2: current_part = current_player.find_child("EyeLeft", true, false) 
		3: current_part = current_player.find_child("Tail", true, false)
		4: current_part = current_player.find_child("Clothes", true, false) 
		5: current_part = current_player.find_child("Hair", true, false)    
	
	if current_part:
		spin_x.value = current_part.position.x
		spin_y.value = current_part.position.y

func _on_value_changed(_value: float) -> void:
	if current_part:
		current_part.position = Vector2(spin_x.value, spin_y.value)

func _on_save_pressed() -> void:
	var body_idx = GameState.skin.get("body_index", 0)
	
	if GameState.parts_db.has("body") and body_idx < GameState.parts_db["body"].size():
		var part_key = ""
		
		match part_selector.selected:
			0: part_key = "hats_pos"
			1: part_key = "head_pos"
			2: part_key = "eyes_pos"
			3: part_key = "tail_pos"
			4: part_key = "clothes_pos"
			5: part_key = "hair_pos"
			
		if part_key != "":
			GameState.parts_db["body"][body_idx][part_key] = [int(spin_x.value), int(spin_y.value)]
			
			var file = FileAccess.open(GameState.PARTS_CONFIG_PATH, FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify(GameState.parts_db, "\t"))
				file.close()
				print("УРА! Координаты сохранены в JSON: ", part_key, " = [", int(spin_x.value), ", ", int(spin_y.value), "]")

extends Control

@onready var character_preview = $Margin/VBox/Body/PreviewStage/CharacterPreview

# ССЫЛКИ НА СПИСКИ
@onready var body_opt = $Margin/VBox/Body/Panel/ScrollContainer/OptionsVBox/BodyOption
@onready var head_opt = $Margin/VBox/Body/Panel/ScrollContainer/OptionsVBox/HeadOption
@onready var eyes_opt = $Margin/VBox/Body/Panel/ScrollContainer/OptionsVBox/EyesOption
@onready var hair_opt = $Margin/VBox/Body/Panel/ScrollContainer/OptionsVBox/HairOption
@onready var clothes_opt = $Margin/VBox/Body/Panel/ScrollContainer/OptionsVBox/ClothesOption
@onready var hats_opt = $Margin/VBox/Body/Panel/ScrollContainer/OptionsVBox/HatsOption
@onready var tail_opt = $Margin/VBox/Body/Panel/ScrollContainer/OptionsVBox/TailOption

@onready var save_button = $Margin/VBox/Body/Panel/SaveButton
@onready var back_button = $Margin/VBox/Body/Panel/BackButton

func _ready() -> void:
	_setup_options()

	# Восстанавливаем выбранные индексы
	body_opt.selected = GameState.skin.get("body_index", 0)
	head_opt.selected = GameState.skin.get("head_index", 0)
	eyes_opt.selected = GameState.skin.get("eyes_index", 0)
	hair_opt.selected = GameState.skin.get("hair_index", 0)
	clothes_opt.selected = GameState.skin.get("clothes_index", 0)
	hats_opt.selected = GameState.skin.get("hats_index", 0)
	tail_opt.selected = GameState.skin.get("tail_index", 0)

	# Подключаем сигналы
	body_opt.item_selected.connect(func(_i): _refresh_preview())
	head_opt.item_selected.connect(func(_i): _refresh_preview())
	eyes_opt.item_selected.connect(func(_i): _refresh_preview())
	hair_opt.item_selected.connect(func(_i): _refresh_preview())
	clothes_opt.item_selected.connect(func(_i): _refresh_preview())
	hats_opt.item_selected.connect(func(_i): _refresh_preview())
	tail_opt.item_selected.connect(func(_i): _refresh_preview())

	save_button.pressed.connect(_on_save)
	back_button.pressed.connect(_on_back)

	_refresh_preview()

func _setup_options() -> void:
	var setup_list = func(option_node: OptionButton, category_key: String):
		option_node.clear()
		if not GameState.parts_db.has(category_key):
			print("ОШИБКА: В JSON нет категории ", category_key)
			return
			
		var parts_array = GameState.parts_db[category_key]
		for i in range(parts_array.size()):
			var part = parts_array[i]
			var icon = null
			if part["path"] != "" and ResourceLoader.exists(part["path"]):
				icon = load(part["path"])
			
			if icon:
				option_node.add_icon_item(icon, part["name"], i)
			else:
				option_node.add_item(part["name"], i)
				
		print("Список [", category_key, "] заполнен. Элементов: ", option_node.item_count)

	# Применяем ко всем спискам
	setup_list.call(hats_opt, "hats")
	setup_list.call(body_opt, "body")
	setup_list.call(head_opt, "head")
	setup_list.call(eyes_opt, "eyes")
	setup_list.call(hair_opt, "hair")
	setup_list.call(clothes_opt, "clothes")
	setup_list.call(tail_opt, "tail")

func _current_skin() -> Dictionary:
	return {
		"body_index": body_opt.selected,
		"head_index": head_opt.selected,
		"eyes_index": eyes_opt.selected,
		"hair_index": hair_opt.selected,
		"clothes_index": clothes_opt.selected,
		"hats_index": hats_opt.selected,
		"tail_index": tail_opt.selected
	}

func _refresh_preview() -> void:
	character_preview.apply_skin(_current_skin())

func _on_save() -> void:
	GameState.skin = _current_skin()
	GameState.save_profile() # <-- Добавить эту строку
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

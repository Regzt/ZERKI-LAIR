extends CharacterBody2D

const SPEED = 300.0

@export var interact_distance: float = 100.0 # Дистанция наведения
var is_hovered: bool = false 

@onready var anim_player = $CharacterSprite/AnimationPlayer
@onready var camera = $Camera2D
@onready var preview = $CharacterSprite
@onready var chat_bubble = find_child("ChatBubble", true, false)
@onready var name_label = $NameLabel
@onready var interact_area = $InteractArea 

# --- Настройки зума ---
var zoom_hold_speed: float = 2.0 
var target_zoom: Vector2 = Vector2(1.0, 1.0) 
var zoom_step: float = 0.1 
var zoom_speed: float = 6.0 
var min_zoom: float = 0.5
var max_zoom: float = 3.0

var player_id: int = 1
var is_local: bool = false
var my_skin: Dictionary = {}
var my_nick: String = ""


func _ready() -> void:
	if name.is_valid_int():
		player_id = int(name)
	
	is_local = is_multiplayer_authority()
	
	if is_local:
		add_to_group("local_player")
		var cam = get_node_or_null("Camera2D")
		if cam:
			cam.make_current()
			
		my_skin = GameState.skin
		my_nick = GameState.nickname
		
		preview.apply_skin(my_skin)
		name_label.text = my_nick
		
		var world = get_tree().current_scene
		if world:
			if multiplayer.is_server():
				world.network_sync_info.rpc(my_nick, my_skin, player_id)
			else:
				world.network_sync_info.rpc_id(1, my_nick, my_skin, player_id)
	else:
		var cam = get_node_or_null("Camera2D")
		if cam: cam.queue_free()
		set_physics_process(false)
		
		if not my_skin.is_empty(): preview.apply_skin(my_skin)
		if not my_nick.is_empty(): name_label.text = my_nick

	# --- ПОДКЛЮЧАЕМ ЗОНУ ВЗАИМОДЕЙСТВИЯ ---
	if interact_area:
		interact_area.mouse_entered.connect(_on_mouse_entered)
		interact_area.mouse_exited.connect(_on_mouse_exited)
		interact_area.input_event.connect(_on_interact_area_input_event)


func _physics_process(delta: float) -> void:
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if direction:
		velocity = direction * SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)

	# --- ЛОГИКА РАЗВОРОТА ---
	if direction.x != 0:
		if direction.x > 0:
			preview.scale.x = -abs(preview.scale.x)
		else:
			preview.scale.x = abs(preview.scale.x)

	# --- ЧИСТАЯ АНИМАЦИЯ (БЕЗ ПРЫЖКОВ) ---
	if velocity.length() > 0:
		# Если идем — включаем анимацию
		if anim_player.current_animation != "walk":
			anim_player.play("walk")
	else:
		# Если стоим — выключаем и возвращаем первый кадр
		if anim_player.is_playing():
			anim_player.stop()
		
		# Принудительно ставим кадр 0 всем частям, чтобы он застыл
		for child in preview.get_children():
			if child is Sprite2D:
				child.frame = 0

	move_and_slide()

func _process(delta: float) -> void:
	# Прячем ник, когда печатаем
	if chat_bubble and name_label:
		name_label.visible = not chat_bubble.panel.visible
		
	# ЗУМ КАМЕРЫ
	var zoom_direction: float = 0.0
	if Input.is_physical_key_pressed(KEY_EQUAL) or Input.is_physical_key_pressed(KEY_KP_ADD):
		zoom_direction -= 0.6 
	if Input.is_physical_key_pressed(KEY_MINUS) or Input.is_physical_key_pressed(KEY_KP_SUBTRACT):
		zoom_direction += 0.6 
		
	if zoom_direction != 0.0:
		target_zoom += Vector2(zoom_direction, zoom_direction) * zoom_hold_speed * delta
		target_zoom = target_zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
		
	if camera:
		camera.zoom = camera.zoom.lerp(target_zoom, delta * zoom_speed)

	# ПРОВЕРКА ДИСТАНЦИИ ПРИ НАВЕДЕНИИ
	if is_hovered and not is_local:
		check_distance_and_highlight()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("chat"):
		var chat_input = get_tree().current_scene.find_child("ChatInput", true, false)
		if chat_input:
			chat_input.grab_focus()
			get_viewport().set_input_as_handled()

# ФУНКЦИИ ДЛЯ РАБОТЫ С СЕТЬЮ
@rpc("any_peer", "call_local", "reliable")
func set_network_info(nick: String, new_skin: Dictionary) -> void:
	my_nick = nick
	my_skin = new_skin
	name_label.text = nick
	preview.apply_skin(new_skin)

@rpc("any_peer", "call_local", "reliable")
func network_show_bubble(text: String, is_typing: bool) -> void:
	if is_typing:
		chat_bubble.show_typing()
	else:
		chat_bubble.show_message(text)

func toggle_name_tag(show_tag: bool) -> void:
	name_label.visible = show_tag

# МАГИЯ ВЗАИМОДЕЙСТВИЯ
func _on_mouse_entered() -> void:
	if is_local: return
	is_hovered = true
	# Сразу проверяем дистанцию при наведении
	check_distance_and_highlight()

func _on_mouse_exited() -> void:
	if is_local: return
	is_hovered = false
	preview.modulate = Color(1, 1, 1) 

func _on_interact_area_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if is_local: return 
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var my_player = get_tree().get_first_node_in_group("local_player")
		if my_player:
			var dist = global_position.distance_to(my_player.global_position)
			if dist <= interact_distance: 
				var world = get_tree().current_scene
				if world.has_method("open_player_menu"):
					world.open_player_menu(self)
			else:
				print("Слишком далеко для клика! Нужно подойти ближе.")

func check_distance_and_highlight() -> void:
	var my_player = get_tree().get_first_node_in_group("local_player")
	if my_player:
		var dist = global_position.distance_to(my_player.global_position)
		
		if dist <= interact_distance:
			preview.modulate = Color(1.5, 1.5, 1.5) # Яркий белый
		else:
			preview.modulate = Color(1, 1, 1) # Обычный цвет
@rpc("any_peer", "reliable")
func receive_invite(inviter_id: int, inviter_name: String) -> void:
	# приглошение не нам значит игнор
	if not is_local: 
		return
		
	print("Приглашение от ", inviter_name, " (ID: ", inviter_id, ")")
	
	# Пока просто выводим в консоль, а в следующем шаге сделаем красивое окошко
	# Пока что давай автоматически согласимся для теста!
	var world = get_tree().current_scene
	if world.has_method("start_xo_game"):
		world.start_xo_game(inviter_id, multiplayer.get_unique_id())

extends Node2D

@onready var spawner = $Spawner

# Переменные для меню
var menu_target_id: String = ""
var menu_target_node: Node = null 

func _ready() -> void:
	spawner.spawn_function = _custom_spawn
	print("--- ЗАГРУЗКА МИРА ---")
	
	# ПРИНУДИТЕЛЬНО ПРЯЧЕМ МЕНЮ ПРИ СТАРТЕ
	var menu = get_node_or_null("CanvasLayer/UIRoot/PlayerMenu")
	if menu:
		menu.visible = false
	
	# Запускаем сервер или подключаемся как клиент
	if multiplayer.is_server():
		spawn_player(1)
		multiplayer.peer_disconnected.connect(despawn_player)
	else:
		print("Я клиент. Отправляю серверу сигнал готовности...")
		rpc_id(1, "client_ready")

func spawn_player(id: int) -> void:
	spawner.spawn(id)

func _custom_spawn(id: int) -> Node:
	var player = load("res://scenes/player.tscn").instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)
	
	if id == 1:
		player.position = Vector2(0, 0)
	else:
		player.position = Vector2(100, 0)
		
	return player

@rpc("any_peer", "reliable")
func client_ready() -> void:
	if multiplayer.is_server():
		var client_id = multiplayer.get_remote_sender_id()
		spawn_player(client_id)
		
		await get_tree().process_frame
		
		# Отправляем новому клиенту ники и скины всех игроков
		for p in get_tree().get_nodes_in_group("players"):
			if int(p.name) != client_id:
				network_sync_info.rpc_id(client_id, p.my_nick, p.my_skin, int(p.name))

# Синхронизация НИКА и СКИНА
@rpc("any_peer", "reliable") 
func network_sync_info(nick: String, skin_data: Dictionary, target_id: int) -> void:
	var sender = multiplayer.get_remote_sender_id()
	
	if multiplayer.is_server() and sender != 0:
		network_sync_info.rpc(nick, skin_data, target_id)
		
	var player_node = get_node_or_null(str(target_id))
	if player_node:
		player_node.set_network_info(nick, skin_data)

func despawn_player(id: int) -> void:
	var player = get_node_or_null(str(id))
	if player: 
		player.queue_free()

# ==========================================
# МЕНЮ ВЗАИМОДЕЙСТВИЯ
# ==========================================

func open_player_menu(target_player: Node) -> void:
	var menu = get_node_or_null("CanvasLayer/UIRoot/PlayerMenu")
	if not menu: return

	# --- МАГИЯ ПЕРЕКЛЮЧАТЕЛЯ ---
	# Если меню уже открыто И мы кликнули по тому же игроку
	if menu.visible and menu_target_node == target_player:
		menu.visible = false
		menu_target_node = null
		menu_target_id = ""
		print("Меню закрыто повторным кликом.")
		return # Выходим из функции, чтобы меню не открылось заново

	# --- ЕСЛИ МЕНЮ БЫЛО ЗАКРЫТО ИЛИ МЫ КЛИКНУЛИ НА ДРУГОГО ---
	menu_target_id = target_player.name 
	menu_target_node = target_player 
	
	menu.visible = true
	update_menu_position()
	
	# Прячем кнопку XO по умолчанию
	var xo_btn = menu.get_node_or_null("VBoxContainer/XOButton")
	if xo_btn: 
		xo_btn.visible = false
	
	# Подключаем кнопку закрытия "X" (безопасно)
	var close_btn = menu.get_node_or_null("CloseButton")
	if close_btn and not close_btn.pressed.is_connected(_on_close_menu_pressed):
		close_btn.pressed.connect(_on_close_menu_pressed)
		
	# Подключаем кнопку "Мини-игры" (безопасно)
	var mini_btn = menu.get_node_or_null("VBoxContainer/MiniGamesButton")
	if mini_btn and not mini_btn.pressed.is_connected(_on_mini_games_pressed):
		mini_btn.pressed.connect(_on_mini_games_pressed)

func _on_close_menu_pressed() -> void:
	var menu = get_node_or_null("CanvasLayer/UIRoot/PlayerMenu")
	if menu: 
		menu.visible = false
		print("Меню закрыто крестиком.")

func _on_mini_games_pressed() -> void:
	print("Нажата кнопка Мини-игры!")
	var menu = get_node_or_null("CanvasLayer/UIRoot/PlayerMenu")
	if menu:
		var xo_btn = menu.get_node_or_null("VBoxContainer/XOButton")
		if xo_btn:
			xo_btn.visible = true
			if not xo_btn.pressed.is_connected(_on_xo_pressed):
				xo_btn.pressed.connect(_on_xo_pressed)

func _on_xo_pressed() -> void:
	print("Отправляем приглашение игроку: ", menu_target_id)
	get_node("CanvasLayer/UIRoot/PlayerMenu").visible = false
	
	var target_player = get_node_or_null(menu_target_id)
	if target_player:
		# Вызываем функцию приглашения в скрипте canvas_layer.gd (интерфейсе)
		var ui = get_tree().current_scene.get_node_or_null("CanvasLayer")
		if ui:
			ui.receive_invite.rpc_id(int(menu_target_id), multiplayer.get_unique_id(), GameState.nickname)

# --- СЛЕЖЕНИЕ ЗА ИГРОКОМ ---
func _process(_delta: float) -> void:
	var menu = get_node_or_null("CanvasLayer/UIRoot/PlayerMenu")
	
	# Если меню открыто и игрок еще существует
	if menu and menu.visible and is_instance_valid(menu_target_node):
		update_menu_position()
		
		# Проверка дистанции
		var my_player = get_tree().get_first_node_in_group("local_player")
		if my_player:
			var dist = my_player.global_position.distance_to(menu_target_node.global_position)
			# ТЕПЕРЬ МЕНЮ БУДЕТ ЗАКРЫВАТЬСЯ ТОЛЬКО ЕСЛИ ВЫЙТИ ЗА ТВОЙ ЛИМИТ
			if dist > my_player.interact_distance: 
				menu.visible = false
				print("Меню закрыто: игрок ушел слишком далеко (дистанция: ", dist, ").")

func update_menu_position() -> void:
	var menu = get_node_or_null("CanvasLayer/UIRoot/PlayerMenu")
	if menu and is_instance_valid(menu_target_node):
		# Переводим координаты из мира в координаты на экране
		var screen_pos = get_viewport().get_canvas_transform() * menu_target_node.global_position
		
		# Ставим меню ровно над головой, центрируя по ширине
		menu.global_position = screen_pos + Vector2(-menu.size.x / 2, -120)

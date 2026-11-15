extends Control

@onready var char_preview = $Margin/MainVBox/Body/LeftPanel/PreviewBox/CharacterPreview
@onready var nickname_edit: LineEdit = $Margin/MainVBox/Body/LeftPanel/NicknameEdit
@onready var char_button: Button    = $Margin/MainVBox/Body/LeftPanel/CharButton
@onready var host_button: Button    = $Margin/MainVBox/Body/RightPanel/HostButton
@onready var ip_edit: LineEdit      = $Margin/MainVBox/Body/RightPanel/IPEdit
@onready var join_button: Button    = $Margin/MainVBox/Body/RightPanel/JoinButton
@onready var exit_button: Button    = $Margin/MainVBox/Body/RightPanel/ExitButton
@onready var status_label: Label    = $Margin/MainVBox/StatusLabel

func _ready() -> void:
	char_button.pressed.connect(_on_char_pressed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	nickname_edit.text_submitted.connect(_on_nick_submitted)

	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)

	nickname_edit.text = GameState.nickname
	if char_preview:
		char_preview.apply_skin(GameState.skin)
		print("Превью в меню принудительно обновлено!")
	else:
		print("ОШИБКА: Нода CharacterPreview не найдена в меню!")

func _validate_nickname() -> bool:
	var nick := nickname_edit.text.strip_edges()
	if nick.length() < 2:
		status_label.text = "Ник минимум 2 символа"
		nickname_edit.grab_focus()
		return false
	GameState.nickname = nick
	return true

func _on_nick_submitted(_t: String) -> void:
	_validate_nickname()

func _on_char_pressed() -> void:
	_validate_nickname()
	get_tree().change_scene_to_file("res://scenes/CharacterCreator.tscn")

func _on_host_pressed() -> void:
	if not _validate_nickname():
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(GameState.PORT, 8)
	if err != OK:
		status_label.text = "Не удалось поднять сервер: %d" % err
		return
	multiplayer.multiplayer_peer = peer
	get_tree().change_scene_to_file("res://scenes/World.tscn")

func _on_join_pressed() -> void:
	if not _validate_nickname():
		return
	var ip := ip_edit.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Введи IP хоста"
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, GameState.PORT)
	if err != OK:
		status_label.text = "Ошибка: %d" % err
		return
	multiplayer.multiplayer_peer = peer
	status_label.text = "Подключаемся к %s..." % ip

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_connected() -> void:
	get_tree().change_scene_to_file("res://scenes/World.tscn")

func _on_connection_failed() -> void:
	status_label.text = "Не удалось подключиться. Проверь IP и что хост запущен."
	multiplayer.multiplayer_peer = null

func _on_disconnected() -> void:
	status_label.text = "Соединение потеряно"
	multiplayer.multiplayer_peer = null

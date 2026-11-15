extends CanvasLayer

func _ready() -> void:
	var input_node = $UIRoot/Chatroot/ChatInput
	if input_node:
		input_node.text_submitted.connect(_on_chat_submitted)
		input_node.focus_entered.connect(_on_chat_focus_entered)
		input_node.focus_exited.connect(_on_chat_focus_exited)
		
	var exit_btn = get_tree().current_scene.find_child("ExitButton", true, false)
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_pressed)

# ЧАТ 
func _on_chat_focus_entered() -> void:
	var players = get_tree().get_nodes_in_group("local_player")
	if players.size() > 0: players[0].network_show_bubble.rpc("", true)

func _on_chat_focus_exited() -> void:
	var players = get_tree().get_nodes_in_group("local_player")
	if players.size() > 0:
		var bubble = players[0].find_child("ChatBubble", true, false)
		if bubble and bubble.label.text == "...": bubble.panel.hide()

func _on_chat_submitted(new_text: String) -> void:
	var text = new_text.strip_edges()
	if text == "": return
	receive_message.rpc(GameState.nickname, text)
	var players = get_tree().get_nodes_in_group("local_player")
	if players.size() > 0: players[0].network_show_bubble.rpc(text, false)
	$UIRoot/Chatroot/ChatInput.text = ""
	$UIRoot/Chatroot/ChatInput.release_focus()

@rpc("any_peer", "call_local", "reliable")
func receive_message(sender_name: String, text: String) -> void:
	$UIRoot/Chatroot/ChatLog.append_text("[" + sender_name + "]: " + text + "\n")

# ВЫХОД ИЗ МИРА 
func _on_exit_pressed() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# ==========================================
# КРЕСТИКИ-НОЛИКИ
# ==========================================
var xo_board = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0]) 
var xo_p1_id: int = -1 
var xo_p2_id: int = -1 
var xo_turn: int = 1 
var xo_active: bool = false

# ПРИГЛАШЕНИЕ 
@rpc("any_peer", "reliable")
func receive_invite(inviter_id: int, inviter_name: String) -> void:
	var popup = $UIRoot/InvitePopup
	if popup:
		popup.visible = true
		popup.get_node("VBoxContainer/Label").text = inviter_name + " приглашает вас в XO!"
		
		# СООБЩЕНИЕ В ЧАТ О ПРИГЛАШЕНИИ
		$UIRoot/Chatroot/ChatLog.append_text("[Система]: " + inviter_name + " приглашает вас в XO! 🎮\n")
		
		var accept_btn = popup.get_node("VBoxContainer/HBoxContainer/AcceptBtn")
		var decline_btn = popup.get_node("VBoxContainer/HBoxContainer/DeclineBtn")
		
		if accept_btn.pressed.is_connected(_on_invite_accept): accept_btn.pressed.disconnect(_on_invite_accept)
		if decline_btn.pressed.is_connected(_on_invite_decline): decline_btn.pressed.disconnect(_on_invite_decline)
		
		accept_btn.pressed.connect(_on_invite_accept.bind(inviter_id))
		decline_btn.pressed.connect(_on_invite_decline.bind(inviter_id))

func _on_invite_accept(inviter_id: int) -> void:
	$UIRoot/InvitePopup.visible = false
	var my_id = multiplayer.get_unique_id()
	
	if multiplayer.is_server():
		server_start_xo(inviter_id, my_id)
	else:
		rpc_id(1, "server_start_xo", inviter_id, my_id)

func _on_invite_decline(inviter_id: int) -> void:
	$UIRoot/InvitePopup.visible = false
	if multiplayer.is_server():
		server_decline_xo(inviter_id)
	else:
		rpc_id(1, "server_decline_xo", inviter_id)

@rpc("any_peer", "reliable")
func invite_declined() -> void:
	$UIRoot/Chatroot/ChatLog.append_text("[Система]: Игрок отказался играть с вами. 😢\n")

# --- СЕРВЕРНЫЕ КОМАНДЫ ---
@rpc("any_peer", "reliable")
func server_decline_xo(inviter_id: int) -> void:
	if multiplayer.is_server():
		rpc_id(inviter_id, "invite_declined")

@rpc("any_peer", "reliable")
func server_start_xo(p1_id: int, p2_id: int) -> void:
	if not multiplayer.is_server(): return
	xo_p1_id = p1_id
	xo_p2_id = p2_id
	xo_board = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
	xo_turn = 1
	xo_active = true
	start_xo_client.rpc(p1_id, p2_id)

# ОТКРЫТИЕ ЭКРАНА 
@rpc("any_peer", "call_local", "reliable")
func start_xo_client(p1_id: int, p2_id: int) -> void:
	xo_p1_id = p1_id
	xo_p2_id = p2_id
	xo_turn = 1
	xo_active = true
	xo_board = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
	
	var panel = get_node_or_null("UIRoot/XO_GamePanel")
	if not panel: return
	
	panel.visible = true
	update_board_ui()
		
	var grid = panel.find_child("BoardGrid", true, false)
	if grid:
		var buttons = []
		for child in grid.get_children():
			if child is Button:
				buttons.append(child)
				
		if buttons.size() >= 9:
			for i in range(9):
				var btn = buttons[i]
				btn.disabled = false
				for connection in btn.pressed.get_connections():
					btn.pressed.disconnect(connection.callable)
				btn.pressed.connect(_on_cell_pressed.bind(i))
	
	var close_btn = panel.find_child("CloseGameBtn", true, false)
	if close_btn:
		for connection in close_btn.pressed.get_connections():
			close_btn.pressed.disconnect(connection.callable)
		close_btn.pressed.connect(_on_close_xo)

# КЛИК ПО КЛЕТКЕ 
func _on_cell_pressed(index: int) -> void:
	var my_id = multiplayer.get_unique_id()
	
	if (xo_turn == 1 and my_id != xo_p1_id) or (xo_turn == 2 and my_id != xo_p2_id):
		return
	if xo_board[index] != 0:
		return
		
	if multiplayer.is_server():
		server_make_move(index)
	else:
		rpc_id(1, "server_make_move", index)

@rpc("any_peer", "call_local", "reliable") 
func server_make_move(index: int) -> void:
	if not multiplayer.is_server(): return
	
	xo_board[index] = xo_turn
	xo_turn = 2 if xo_turn == 1 else 1
	
	sync_board.rpc(xo_board, xo_turn)
	check_win()

@rpc("any_peer", "call_local", "reliable")
func sync_board(new_board: PackedInt32Array, next_turn: int) -> void:
	xo_board = new_board
	xo_turn = next_turn
	update_board_ui()

# ОБНОВЛЕНИЕ UI 
func update_board_ui() -> void:
	var panel = get_node_or_null("UIRoot/XO_GamePanel")
	if not panel: return
	
	var grid = panel.find_child("BoardGrid", true, false)
	if not grid: return
	
	var buttons = []
	for child in grid.get_children():
		if child is Button:
			buttons.append(child)
			
	if buttons.size() >= 9:
		for i in range(9):
			if xo_board[i] == 1: 
				buttons[i].text = "X"
			elif xo_board[i] == 2: 
				buttons[i].text = "O"
			else: 
				buttons[i].text = ""
	
	var my_id = multiplayer.get_unique_id()
	var turn_label = panel.find_child("TurnLabel", true, false)
	if turn_label:
		if (xo_turn == 1 and my_id == xo_p1_id) or (xo_turn == 2 and my_id == xo_p2_id):
			turn_label.text = "Ваш ход!"
		else:
			turn_label.text = "Ход противника..."

# ПОБЕДА 
func check_win() -> void:
	var b = xo_board
	var win = 0
	if b[0] == b[1] and b[1] == b[2] and b[0] != 0: win = b[0]
	elif b[3] == b[4] and b[4] == b[5] and b[3] != 0: win = b[3]
	elif b[6] == b[7] and b[7] == b[8] and b[6] != 0: win = b[6]
	elif b[0] == b[3] and b[3] == b[6] and b[0] != 0: win = b[0]
	elif b[1] == b[4] and b[4] == b[7] and b[1] != 0: win = b[1]
	elif b[2] == b[5] and b[5] == b[8] and b[2] != 0: win = b[2]
	elif b[0] == b[4] and b[4] == b[8] and b[0] != 0: win = b[0]
	elif b[2] == b[4] and b[4] == b[6] and b[2] != 0: win = b[2]
	
	var draw = true
	for i in b:
		if i == 0: draw = false
	
	if win != 0: end_game.rpc(win)
	elif draw: end_game.rpc(0)

@rpc("any_peer", "call_local", "reliable")
func end_game(winner: int) -> void:
	xo_active = false
	var my_id = multiplayer.get_unique_id()
	var turn_label = $UIRoot/XO_GamePanel/VBoxContainer/TurnLabel
	
	# ДОБАВИЛ СООБЩЕНИЯ В ЧАТ О РЕЗУЛЬТАТЕ
	if winner == 0: 
		turn_label.text = "Ничья! 🤝"
		$UIRoot/Chatroot/ChatLog.append_text("[Система]: Ничья\n")
	elif (winner == 1 and my_id == xo_p1_id) or (winner == 2 and my_id == xo_p2_id): 
		turn_label.text = "Вы победили! 🎉"
		$UIRoot/Chatroot/ChatLog.append_text("[Система]: Вы победили!\n")
	else: 
		turn_label.text = "Вы проиграли... 💀"
		$UIRoot/Chatroot/ChatLog.append_text("[Система]: Вы проиграли\n")
		
	await get_tree().create_timer(3.0).timeout
	$UIRoot/XO_GamePanel.visible = false

# ВЫХОД ИЗ ИГРЫ
func _on_close_xo() -> void:
	if multiplayer.is_server():
		cancel_xo_client.rpc()
	else:
		rpc_id(1, "server_cancel_xo")

@rpc("any_peer", "reliable")
func server_cancel_xo() -> void:
	if multiplayer.is_server():
		cancel_xo_client.rpc()

@rpc("any_peer", "call_local", "reliable")
func cancel_xo_client() -> void:
	xo_active = false
	$UIRoot/XO_GamePanel.visible = false
	$UIRoot/Chatroot/ChatLog.append_text("[Система]: Игра завершена\n")

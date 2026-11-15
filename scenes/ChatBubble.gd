extends Node2D

@onready var panel = $Panel
@onready var label = $Panel/TextLabel
var hide_timer: float = 0.0

func _ready() -> void:
	panel.hide() # Изначально пузырь скрыт

# Показать статус "Печатает..."
func show_typing() -> void:
	label.text = "..." # Или "Печатает..."
	label.modulate = Color(0.7, 0.7, 0.7) # Делаем текст серым
	panel.show()
	hide_timer = 0.0 # Сбрасываем таймер скрытия

# Показать само сообщение
func show_message(text: String) -> void:
	if text.length() > 50: #показ только 50 символов
		text = text.substr(0, 47) + "..."
		
	label.text = text
	label.modulate = Color(0.826, 0.826, 0.826, 1.0) # текст 
	panel.show()
	hide_timer = 4.0 # 4 секунды жизни бабла

func _process(delta: float) -> void:
	# таймер на пузырь
	if panel.visible and hide_timer > 0.0:
		hide_timer -= delta
		if hide_timer <= 0.0:
			panel.hide()

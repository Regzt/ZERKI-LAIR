extends Node

#   ДАННЫЕ ИГРОКА  
var nickname: String = ""
var shake_strength: float = 6.0

# Индексы выбранных деталей (по умолчанию 0)
var skin: Dictionary = {
	"body_index": 0,
	"head_index": 0,
	"eyes_index": 0,
	"hair_index": 0,
	"clothes_index": 0,
	"hats_index": 0,
	"tail_index": 0
}

# НАСТРОЙКИ СЕТИ
const PORT := 8910

# ПУТИ К ФАЙЛАМ
const PARTS_CONFIG_PATH := "res://character_parts.json"
const SAVE_PATH := "user://character_save.json"

# БАЗА ДАННЫХ ДЕТАЛЕЙ
var parts_db: Dictionary = {}

func _ready() -> void:
	load_parts_config()
	load_profile()

# ЗАГРУЗКА КОНФИГУРАЦИИ ДЕТАЛЕЙ
func load_parts_config() -> void:
	# Проверяем, существует ли файл
	if not FileAccess.file_exists(PARTS_CONFIG_PATH):
		print("ОШИБКА: Файл конфигурации не найден по пути: ", PARTS_CONFIG_PATH)
		return

	# Открываем и читаем файл
	var file = FileAccess.open(PARTS_CONFIG_PATH, FileAccess.READ)
	if not file:
		print("ОШИБКА: Не удалось открыть файл конфигурации.")
		return

	var json_string = file.get_as_text()
	file.close() # Обязательно закрываем файл

	# Парсим JSON
	var json = JSON.new()
	var error = json.parse(json_string)

	if error == OK:
		parts_db = json.data
		print("УСПЕХ: Конфигурация деталей персонажа загружена. Доступные категории: ", parts_db.keys())
	else:
		print("ОШИБКА JSON: ", json.get_error_message(), " в строке ", json.get_error_line())

# СБРОС ДАННЫХ
func reset() -> void:
	nickname = ""
	skin = {
		"body_index": 0,
		"head_index": 0,
		"eyes_index": 0,
		"hair_index": 0,
		"clothes_index": 0,
		"hats_index": 0,
		"tail_index": 0
	}

# СОХРАНЕНИЕ ПРОФИЛЯ
func save_profile() -> void:
	var data = {
		"nickname": nickname,
		"skin": skin
	}

	# Превращаем словарь в красивую JSON-строку
	var json_string = JSON.stringify(data, "\t")

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("Персонаж успешно сохранен в файл!")
	else:
		print("ОШИБКА: Не удалось сохранить персонажа.")

# ЗАГРУЗКА ПРОФИЛЯ
func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("Сохранений не найдено, используем дефолтного персонажа.")
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		if json.parse(json_string) == OK:
			var data = json.data
			# Загружаем ник и скин
			nickname = data.get("nickname", "")
			skin = data.get("skin", skin)
			print("Персонаж успешно загружен!")
	else:
		print("ОШИБКА: Не удалось открыть файл сохранения.")

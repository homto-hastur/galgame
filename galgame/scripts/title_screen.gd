extends Control

@onready var start_button: Button = $CenterContainer/VBox/StartButton
@onready var quit_button: Button = $CenterContainer/VBox/QuitButton
@onready var bg_texture: TextureRect = $Background


func _ready() -> void:
	start_button.pressed.connect(_on_start)
	quit_button.pressed.connect(_on_quit)
	
	# 標題畫面背景固定為地牢
	bg_texture.texture = preload("res://assets/backgrounds/地牢.png")


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_quit() -> void:
	get_tree().quit()

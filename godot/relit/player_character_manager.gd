class_name PlayerCharacterManager extends Node2D

@onready var active_players := []
@onready var rich_text_label = $RichTextLabel

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	rich_text_label.text = "\n".join(active_players)

func add_user(user_name):
	active_players.append(user_name)

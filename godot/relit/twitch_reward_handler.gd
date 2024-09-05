class_name TwitchRewardHandler extends Node

@onready var twitch_integration_api = %TwitchIntegrationAPI
@onready var player_character_manager = %PlayerCharacterManager


# Called when the node enters the scene tree for the first time.
func _ready():
	twitch_integration_api.create_user_reward_redeemed.connect(_create_new_user)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _create_new_user(response):
	var new_user = response["payload"]["event"]["user_name"]
	player_character_manager.add_user(new_user)


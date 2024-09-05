class_name TwitchIntegrationAPI extends Node

# If we change to sending state -- We will need to change the parse to get the
# access token via the state

# TCP Config
@onready var tcp_server := TCPServer.new()
@onready var tcp_listen_port := 3000
@onready var tcp_listen_url := "http://localhost:%s" % tcp_listen_port

# URI Config
@onready var client_id := "ydmp932f3ranb49gmnav5194vxc2ym"
@onready var url := "https://api.twitch.tv/helix/eventsub/subscriptions"
@onready var scopes := [
	"channel:read:redemptions"
]

# HTTP Request Setup
@onready var token
@onready var oauth_val_http_request = $OauthValHTTPRequest
@onready var oauth_revalidate_timer = $Timer
@onready var session_id

# Event Subscription
var websocket_url := "wss://eventsub.wss.twitch.tv/ws"
var socket = WebSocketPeer.new()
@onready var broadcast_id = "86372641"
@onready var is_websocket_server_setup = false
@onready var requested_subscription = false
@onready var subscription_http_request = $SubscriptionHTTPRequest


# Signals
signal got_token
signal create_user_reward_redeemed

# Called when the node enters the scene tree for the first time.
func _ready():
	oauth_val_http_request.request_completed.connect(_on_request_completed)
	subscription_http_request.request_completed.connect(_on_subscription_request_completed)
	oauth_revalidate_timer.timeout.connect(_validate_oath_token)
	tcp_server.listen(tcp_listen_port)
	OS.shell_open(
		_create_uri()
	)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not token and tcp_server.is_connection_available():
		_check_server()
	if token and is_websocket_server_setup == false:
		_setup_websocket_server()
	if is_websocket_server_setup:
		_check_websocket()

func _create_uri():
	return \
"""https://id.twitch.tv/oauth2/authorize
?response_type=token
&client_id={client_id}
&redirect_uri={redirect_uri}
&scope={scope}
""".format({
	"client_id": client_id,
	"redirect_uri": tcp_listen_url,
	"scope": _create_scope_string()
})

func _create_scope_string():
	return "".join(scopes.map(func (scope): return scope.uri_encode()))

func _check_server():
	var peer := tcp_server.take_connection()
	var bytes := peer.get_available_bytes()
	var info := peer.get_utf8_string(bytes)
	
	# Creates a javascript line in HTML to fetch the "hash" or "fragment" of the URL and send it back
	var script = "<script>fetch('%s/' + window.location.hash.substr(1))</script>" % tcp_listen_url
	peer.put_data(str("HTTP/1.1 200\n\n" + script).to_ascii_buffer())

	if "access_token" in info:
		token = info.split("access_token=")[1]
		token = token.split("&")[0]
		tcp_server.stop()
		got_token.emit()
		_validate_oath_token()


func _on_request_completed(result, response_code, headers, body):
	if response_code == 200:
		return

func _validate_oath_token():
	if token:
		var headers = [
			"User-Agent: Pirulo/1.0 (Godot)",
			"Accept: */*",
			"Authorization: OAuth %s" % token
		]
		oauth_val_http_request.request("https://id.twitch.tv/oauth2/validate", headers)

func _setup_websocket_server():
	var err = socket.connect_to_url(websocket_url)
	if err != OK:
		print("Unable to connect")
		set_process(false)
	else:
		is_websocket_server_setup = true

func _check_websocket():
	socket.poll()
	var socket_state = socket.get_ready_state()
	if socket_state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			var response = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			_handle_websocket_response(response)
			
func _handle_websocket_response(response):
	if response["metadata"]["message_type"] == "session_welcome":
		_subscribe_to_redemption_events(response)
	if response["metadata"]["message_type"] == "notification":
		create_user_reward_redeemed.emit(response)

func _subscribe_to_redemption_events(response):
	if requested_subscription != true:
		session_id = response["payload"]["session"]["id"]
		var subscription_url = "https://api.twitch.tv/helix/eventsub/subscriptions"
		var headers = [
			"User-Agent: Pirulo/1.0 (Godot)",
			"Accept: */*",
			"Authorization: Bearer %s" % token,
			"Client-Id: %s" % client_id,
			"Content-Type: application/json"
		]
		var payload = {
		  "type": "channel.channel_points_custom_reward_redemption.add",
		  "version": "1",
		  "condition": {
			"broadcaster_user_id": broadcast_id
		  },
		  "transport": {
			"method": "websocket",
			"session_id": session_id
		  }
		}
		subscription_http_request.request(subscription_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
		requested_subscription = true

func _on_subscription_request_completed(result, response_code, headers, body):
	if response_code == 202:
		print("Subscription Request completed")

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

# Signals
signal got_token


# WebSocketPeer = WebSocket. and TCPServer is a minimal HTTPServer.

# Called when the node enters the scene tree for the first time.
func _ready():
	tcp_server.listen(tcp_listen_port)
	OS.shell_open(
		_create_uri()
	)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if tcp_server.is_connection_available():
		_check_server()

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
	var script = "<script>fetch('http://%s/' + window.location.hash.substr(1))</script>" % tcp_listen_url
	peer.put_data(str("HTTP/1.1 200\n\n" + script).to_ascii_buffer())

	if "access_token" in info:
		var token = info.split("access_token=")[1]
		token = token.split("&")[0]
		tcp_server.stop()
		
		got_token.emit()
			# Some headers
		var headers = [
			"User-Agent: Pirulo/1.0 (Godot)",
			"Accept: */*",
			"Authorization: OAuth %s" % token
		]
		var http = HTTPClient.new()
		var response = http.request(HTTPClient.METHOD_GET, "https://api.twitch.tv/helix/oauth2/validate", headers)
		print(response)

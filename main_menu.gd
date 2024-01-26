extends Control

class_name MainMenu

@export var lobby_manager_address: String = "164.152.106.183"

@onready var join_btn: Button = $UI/Menu/Items/JoinLobby/Join
@onready var host_btn: Button = $UI/Menu/Items/Host
@onready var ui: VBoxContainer = $UI

@onready var join_http: HTTPRequest = $JoinHTTP
@onready var host_http: HTTPRequest = $HostHTTP

@onready var arena = preload("res://arena.tscn")

signal player_disconnected(pid: int)

var current_players = 0

func _ready():
	var arguments := {}
	
	for argument in OS.get_cmdline_args():
		if argument.find("=") > 1:
			var key_value := argument.split("=")
			arguments[key_value[0].lstrip("--")] = key_value[1]
		else:
			arguments[argument.lstrip("--")] = ""
	
	if arguments.has("port"):
		PrintUtils.print_server("Starting on localhost:25565")
		
		var peer = ENetMultiplayerPeer.new()
		var err: Error = peer.create_server(int(arguments["port"]))
		
		if err != OK:
			PrintUtils.print_server("Failed to start! Error: " + str(err))
			host_btn.disabled = false
		else:
			PrintUtils.print_server("Successfully started on port: " + str(arguments["port"]))
		
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(_on_client_connect)
		multiplayer.peer_disconnected.connect(_on_client_disconnect)

func _on_join_pressed():
	var room_key = $UI/Menu/Items/JoinLobby/Code.text
	
	# Send a request to the master server to join a room
	join_http.request(
		"http://" + lobby_manager_address + ":25565/join_room", 
		["Content-Type: application/json"], 
		HTTPClient.METHOD_POST, JSON.stringify({"key": room_key})
	)

func _on_host_pressed():
	host_http.request("http://" + lobby_manager_address + ":25565/create_room")

func join_lobby(port: int, key: String):
	print("Connecting to server...")
	join_btn.disabled = true
	
	var peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client("164.152.106.183", port)
	
	if err != OK:
		push_error("Failed to join server due to:", err)
		join_btn.disabled = false
		return
	else:
		print("Client successfully connected!")
	
	multiplayer.multiplayer_peer = peer

## Runs when a client joins the server
func _on_client_connect(pid: int):
	PrintUtils.print_server(str(pid) + " has successfully connected!")
	current_players += 1
	
	if current_players >= 2:
		switch_to_arena.rpc()

## Runs when a client leaves the server
func _on_client_disconnect(pid: int):
	PrintUtils.print_server(str(pid) + " has disconnected!")
	
	player_disconnected.emit(pid)
	
	if multiplayer.get_peers().size() <= 0:
		get_tree().quit()

## Switch the scene to an arena
@rpc("authority", "call_local", "reliable")
func switch_to_arena():
	ui.visible = false
	
	var arena_instance = arena.instantiate() as ArenaManager
	add_child(arena_instance)
	
	arena_instance.spawn_players()

func _on_join_http_request_completed(result, response_code, headers, body):
	if response_code == 200:
		var json := JSON.new()
		var error = json.parse(body.get_string_from_utf8())
		if error == OK:
			var port = json.data["port"]
			var key = json.data["key"]
			
			join_lobby(port, key)
	else:
		print("Failed to join room.")

func _on_host_http_request_completed(result, response_code, headers, body):
	if response_code == 200:
		var json := JSON.new()
		var error = json.parse(body.get_string_from_utf8())
		
		if error == OK:
			var port = json.data["port"]
			var key = json.data["key"]
			
			print("PORT: ", port)
			print("KEY: ", key)
			
			join_lobby(port, key)
	else:
		print("failed to start lobby!")

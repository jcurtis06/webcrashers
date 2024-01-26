extends Node2D

class_name ArenaManager

@export var spawn_points: Array[Vector2]

@onready var players_container: Node = $Players
@onready var player_node: PackedScene = preload("res://player.tscn")
@onready var explosion_scene: PackedScene = preload("res://explosion.tscn")

func _ready():
	if !multiplayer.is_server():
		return
	
	var menu = get_parent() as MainMenu
	menu.player_disconnected.connect(
		func(pid):
			players_container.get_node(str(pid)).queue_free()
	)

## Spawns the players into the arena
## Only runs if caller is the server
func spawn_players():
	if !multiplayer.is_server():
		return
	
	var peers = multiplayer.get_peers()
	
	for i in peers.size():
		var spawn_loc = spawn_points[i]
		
		var player_instance = player_node.instantiate() as Player
		player_instance.name = str(peers[i])
		
		players_container.add_child(player_instance)
		player_instance.get_spawn_data.rpc(spawn_loc)

@rpc("any_peer", "call_remote", "reliable")
func player_death(pid: int, p_pos: Vector2):
	print(str(pid) + " has died!")
	
	var explosion = explosion_scene.instantiate() as CPUParticles2D
	explosion.position = p_pos
	
	add_child(explosion, true)
	explosion.emitting = true

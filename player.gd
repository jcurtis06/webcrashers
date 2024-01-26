extends CharacterBody2D

class_name Player

@export var wheel_base = 70
@export var steering_angle = 15
@export var engine_power = 900
@export var friction = -55
@export var drag = -0.06
@export var braking = -450
@export var max_speed_reverse = 250
@export var slip_speed = 400
@export var traction_fast = 2.5
@export var traction_slow = 10
@export var health = 100.0

@export var powerslide_wb = 15
@export var powerslide_friction = -30

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_label: Label = $UI/HUD/Health

@onready var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var arena: ArenaManager = get_parent().get_parent()

@export var spawn_pos: Vector2 = Vector2.ZERO

var acceleration = Vector2.ZERO
var steer_direction
var e_brake = false

var colliding = false

func _enter_tree():
	$MultiplayerSynchronizer.set_multiplayer_authority(int(str(name)))
	position = spawn_pos

func _ready():
	if sync.get_multiplayer_authority() == multiplayer.get_unique_id():
		health_label.text = "Health: " + str(health)
		position = spawn_pos
		$UI.visible = true
		$Camera2D.enabled = true

func _physics_process(delta):
	if sync.get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	
	acceleration = Vector2.ZERO
	get_input()
	apply_friction(delta)
	calculate_steering(delta)
	velocity += acceleration * delta
	
	var collision = move_and_slide()
	
	if collision:
		if colliding:
			return
		colliding = true
		for c in get_slide_collision_count():
			var current_col = get_slide_collision(c)
			var node = get_slide_collision(c).get_collider() as Node2D
			
			if node.is_in_group("Player"):
				if acceleration.length() > 35:
					var hit_player = node as Player
					
					hit_player.receive_damage.rpc_id(hit_player.name.to_int())
	else:
		colliding = false
	
func apply_friction(delta):
	if acceleration == Vector2.ZERO and velocity.length() < 50:
		velocity = Vector2.ZERO
	
	var f_to_use = friction
	
	if e_brake:
		f_to_use = powerslide_friction
	
	var friction_force = velocity * f_to_use * delta
	var drag_force = velocity * velocity.length() * drag * delta
	acceleration += drag_force + friction_force

func get_input():
	e_brake = false
	var turn = Input.get_axis("steer_left", "steer_right")
	steer_direction = turn * deg_to_rad(steering_angle)
	if Input.is_action_pressed("accelerate"):
		acceleration = transform.x * engine_power
	if Input.is_action_pressed("brake"):
		acceleration = transform.x * braking
	if Input.is_action_pressed("e_brake"):
		e_brake = true
	
func calculate_steering(delta):
	var wb_to_use = wheel_base
	
	if e_brake:
		wb_to_use = powerslide_wb
	
	var rear_wheel = position - transform.x * wb_to_use / 2.0
	var front_wheel = position + transform.x * wb_to_use / 2.0
	rear_wheel += velocity * delta
	front_wheel += velocity.rotated(steer_direction) * delta
	var new_heading = rear_wheel.direction_to(front_wheel)
	var traction = traction_slow
	if velocity.length() > slip_speed:
		traction = traction_fast
	var d = new_heading.dot(velocity.normalized())
	if d > 0:
		velocity = lerp(velocity, new_heading * velocity.length(), traction * delta)
	if d < 0:
		velocity = -new_heading * min(velocity.length(), max_speed_reverse)
	
	rotation = new_heading.angle()

@rpc("any_peer")
func receive_damage():
	health -= 1
	if health <= 0:
		health = 5
		arena.player_death.rpc_id(1, multiplayer.get_unique_id(), position)
		position = Vector2.ZERO
	
	health_label.text = "Health: " + str(health)

@rpc("authority")
func get_spawn_data(loc: Vector2):
	position = loc

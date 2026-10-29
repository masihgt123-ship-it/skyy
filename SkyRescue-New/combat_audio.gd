extends Node

var engine: AudioStreamPlayer
var gun: AudioStreamPlayer
var explosion: AudioStreamPlayer
var warning: AudioStreamPlayer

func player(stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var node := AudioStreamPlayer.new()
	node.stream = stream
	node.volume_db = volume
	add_child(node)
	return node

func _ready() -> void:
	var rotor := preload("res://audio/helicopter_loop.ogg").duplicate() as AudioStreamOggVorbis
	rotor.loop = true
	engine = player(rotor, -15.0)
	gun = player(preload("res://audio/lmg_fire01.mp3"), -10.0)
	gun.max_polyphony = 4
	explosion = player(preload("res://audio/explosion.wav"), -8.0)
	explosion.max_polyphony = 4
	var alert := preload("res://audio/alarm.ogg").duplicate() as AudioStreamOggVorbis
	alert.loop = true
	warning = player(alert, -14.0)
	engine.play()

func update_state(health: float, flight_speed: float, enabled: bool) -> void:
	engine.stream_paused = not enabled
	gun.stream_paused = not enabled
	explosion.stream_paused = not enabled
	engine.pitch_scale = clampf(0.95 + absf(flight_speed) * 0.002, 0.95, 1.12)
	if enabled and health > 0.0 and health <= 30.0:
		if not warning.playing:
			warning.play()
	else:
		warning.stop()

func fire() -> void:
	gun.play()

func explode() -> void:
	explosion.play()

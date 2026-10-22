extends Node
## Small generated instrument bank; no network, external sound packs or music files.
var player:AudioStreamPlayer
var playback:AudioStreamGeneratorPlayback
var clock:float = 0.0
var phase:float = 0.0
var muted:bool = false
var intensity:float = 0.0
var cue_time:float = 0.0
var cue_freq:float = 440.0
var rate:float = 22050.0

func _ready() -> void:
	player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = rate
	stream.buffer_length = 0.18
	player.stream = stream
	player.volume_db = -17.0
	add_child(player)
	player.play()
	playback = player.get_stream_playback()

func ping(frequency:float=600.0) -> void:
	cue_freq = frequency
	cue_time = 0.22

func _exit_tree() -> void:
	playback = null
	if is_instance_valid(player):
		player.stop()

func _process(delta:float) -> void:
	if playback == null:
		return
	player.volume_db = -80.0 if muted else -17.0
	var frames:int = mini(playback.get_frames_available(),4096)
	var chord := [110.0,130.8128,164.8138,195.9977]
	for i in frames:
		clock += 1.0/rate
		var note:float = chord[int(clock/5.0)%4]
		var breath:float = 0.55+0.45*sin(clock*0.19)
		var pad:float = (sin(TAU*55.0*clock)*0.06+sin(TAU*note*clock)*0.045+sin(TAU*note*1.501*clock)*0.02)*breath
		var beat:float = pow(maxf(0.0,sin(clock*2.7)),14.0)*sin(clock*TAU*73.4)*0.07*intensity
		var cue:float = 0.0
		if cue_time>0.0:
			cue = sin(clock*TAU*cue_freq)*0.35*(cue_time/0.22)
			cue_time -= 1.0/rate
		playback.push_frame(Vector2(pad+beat+cue,pad+beat+cue))

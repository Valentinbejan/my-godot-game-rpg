extends Node
## Original synthesized score and effects; no external audio is required.
var clips: Dictionary = {}
var ambient: AudioStreamPlayer

func _ready() -> void:
	for clip_name in ["swing","hit","block","hurt","spell","flutter","bell","step","warn","pickup"]:
		clips[clip_name] = synth(clip_name)
	ambient = AudioStreamPlayer.new()
	ambient.stream = drone()
	ambient.volume_db = -18
	add_child(ambient)
	ambient.play()

func play_tone(id: String, volume: float = 0.0) -> void:
	if not clips.has(id):
		return
	var p := AudioStreamPlayer.new()
	p.stream = clips[id]
	p.volume_db = -11+volume
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func synth(id: String) -> AudioStreamWAV:
	var duration := 0.32
	var frequency := 180.0
	match id:
		"bell": duration = 3.8; frequency = 146.83
		"spell": duration = 0.55; frequency = 660
		"flutter": duration = 1.1; frequency = 440
		"pickup": duration = 1.6; frequency = 587.33
		"hit": frequency = 95
		"hurt": frequency = 64
		"block": frequency = 900
		"warn": duration = 0.8; frequency = 220
	var rate := 22050
	var bytes := PackedByteArray()
	bytes.resize(int(duration*rate)*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 147
	for i in range(int(duration*rate)):
		var t := float(i)/rate
		var envelope := minf(t*90,1)*exp(-t*5/duration)
		var sample := sin(TAU*frequency*t)*0.6+sin(TAU*frequency*2.01*t)*0.18+sin(TAU*frequency*3.91*t)*0.1
		if id in ["swing","hit","hurt","step"]:
			sample = sample*0.4+rng.randf_range(-1,1)*0.35
		if id == "flutter":
			sample *= 0.6+sin(t*38)*0.4
		bytes.encode_s16(i*2,int(clampf(sample*envelope*0.7,-1,1)*32767))
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = rate
	clip.data = bytes
	return clip

func drone() -> AudioStreamWAV:
	var rate := 22050
	var duration := 12
	var bytes := PackedByteArray()
	bytes.resize(rate*duration*2)
	for i in range(rate*duration):
		var t := float(i)/rate
		var value := sin(TAU*55*t)*0.15+sin(TAU*82.5*t)*0.06+sin(TAU*110*t)*0.07
		value += sin(TAU*220*t)*0.035*(0.5+0.5*sin(TAU*t/12))
		value += sin(TAU*293.333333*t)*0.014*(0.5+0.5*cos(TAU*t/6))
		bytes.encode_s16(i*2,int(value*32767))
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = rate
	clip.data = bytes
	clip.loop_mode = AudioStreamWAV.LOOP_FORWARD
	clip.loop_end = rate*duration
	return clip

func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	clips.clear()

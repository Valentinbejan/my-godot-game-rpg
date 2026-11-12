extends Control
## Crisp, resolution-independent UI over the intentionally coarse 3D scene.
var game: Node3D
var serif: SystemFont
var sans: SystemFont
var buttons: Control
var ink := Color("e0dfca")
var muted := Color("879a9d")
var gold := Color("bba376")
var teal := Color("93c8bd")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia","Times New Roman"])
	sans = SystemFont.new()
	sans.font_names = PackedStringArray(["Segoe UI","Arial"])
	buttons = Control.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(buttons)

func _process(_delta: float) -> void:
	queue_redraw()

func text(value: String, pos: Vector2, font_size: int = 18, color: Color = ink, font: Font = sans) -> void:
	draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func centered(value: String, y: float, font_size: int, color: Color, font: Font = sans) -> void:
	var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	text(value,Vector2((get_viewport_rect().size.x-width)*0.5,y),font_size,color,font)

func wrapped(value: String, pos: Vector2, width: float, font_size: int, color: Color, font: Font = sans) -> void:
	draw_multiline_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,-1,color)

func _draw() -> void:
	if not is_instance_valid(game.player): return
	var screen := get_viewport_rect().size
	var w := screen.x
	var h := screen.y
	# Subtle framing preserves the center's contrast and reading clarity.
	for i in range(20):
		var alpha := 0.006+0.024*float(20-i)/20
		draw_rect(Rect2(i*2,i*2,w-i*4,h-i*4),Color(0.008,0.016,0.025,alpha),false,2)
	if game.settings.retro:
		for y in range(0,int(h),4):
			draw_line(Vector2(0,y),Vector2(w,y),Color(0,0,0,0.027),1)
	if game.overlay == "title":
		for i in range(100):
			var x := floorf(float(i)*w/100)
			var alpha := 0.96*pow(1.0-float(i)/100,2)
			draw_rect(Rect2(x,0,floorf(float(i+1)*w/100)-x,h),Color(0.022,0.039,0.050,alpha))
		text("A PILGRIMAGE BELOW THE DEAD TEMPLE",Vector2(66,85),12,gold)
		draw_line(Vector2(66,112),Vector2(360,112),Color(gold,0.5),1)
		text("THE",Vector2(62,197),50,ink,serif)
		text("HOLLOW",Vector2(60,282),84,ink,serif)
		text("STAR",Vector2(62,367),84,ink,serif)
		text("S U N K E N   C L O I S T E R",Vector2(68,410),16,gold)
		text("Some lights should never wake.",Vector2(68,446),19,muted,serif)
		text("FIRST-PERSON DARK FANTASY",Vector2(68,h-80),11,muted)
		text("A playable proof of concept  /  01",Vector2(68,h-55),13,gold)
		text("THE QUIET NAVE",Vector2(w-260,78),12,gold)
		text("Beneath a star that dreams",Vector2(w-260,101),14,ink,serif)
		return
	if game.playing:
		if game.player.moth:
			draw_rect(Rect2(0,0,w,h),Color(0.28,0.38,0.5,0.075))
			for side in [-1,1]:
				var cx: float = w*0.5+side*w*0.42
				for i in range(5):
					draw_arc(Vector2(cx,h*0.7),125+i*17,PI*1.08 if side<0 else PI*1.6,PI*1.4 if side<0 else PI*1.92,20,Color(teal,0.08),1.0)
		# Compass tick marks and a gold diamond toward the next objective.
		draw_line(Vector2(w/2-95,29),Vector2(w/2+95,29),Color(muted,0.36),1)
		for i in range(-4,5):
			draw_line(Vector2(w/2+i*22,26),Vector2(w/2+i*22,31),Color(muted,0.5),1)
		var target: Vector3 = game.objective_position()-game.player.global_position
		var angle: float = wrapf(atan2(-target.x,-target.z)-game.player.rotation.y,-PI,PI)
		var marker_x: float = w/2+clampf(angle/PI*150,-105,105)
		diamond(Vector2(marker_x,29),4,gold)
		centered(game.room_name.to_upper(),58,12,gold)
		centered(game.objective(),82,14,ink)
		if game.room_time > 0:
			var alpha: float = minf(1,game.room_time)
			centered(game.room_name,h*0.24,31,Color(ink,alpha),serif)
			draw_line(Vector2(w/2-60,h*0.24+17),Vector2(w/2+60,h*0.24+17),Color(gold,alpha*0.65),1)
		var center := screen*0.5
		draw_circle(center,1.4,Color(ink,0.85))
		if game.hit_flash > 0:
			for side in [-1,1]:
				draw_line(center+Vector2(side*5,side*5),center+Vector2(side*11,side*11),ink,2)
				draw_line(center+Vector2(side*5,-side*5),center+Vector2(side*11,-side*11),ink,2)
		if not game.focused.is_empty() and game.overlay == "":
			draw_arc(center,9,0,TAU,24,Color(gold,0.8),1)
			centered("[ E ]  "+game.focused.label,h/2+43,16,ink)
		# Three resources, simple enough to read during an attack.
		var y := h-115
		text("PILGRIM",Vector2(42,y-22),11,gold)
		bar(Vector2(42,y),240,game.player.health,Color("c5837c"),"VITALITY")
		bar(Vector2(42,y+26),240,game.player.stamina,Color("b1ae80"),"STAMINA")
		bar(Vector2(42,y+52),240,game.player.charge,Color("89b8c6"),"STARLIGHT")
		text("F  Moon draught  × "+str(game.draughts),Vector2(42,h-24),12,ink)
		text(str(game.essence)+"  ESSENCE",Vector2(323,h-38),12,gold)
		text("MOTH FORM" if game.player.moth else "PILGRIM BLADE",Vector2(w-256,h-112),14,teal if game.player.moth else ink)
		text("R  "+("Return to human" if game.player.moth else ("Moth Form" if game.flags.moth else "Undiscovered form")),Vector2(w-256,h-86),12,muted)
		text("Q  "+("Star Needle" if game.flags.needle else "Undiscovered spell"),Vector2(w-256,h-63),12,muted)
		text("TAB  Relics & route     ESC  Pause",Vector2(w-256,h-34),11,gold)
		if game.player.attacking:
			draw_arc(center,17,-PI/2,-PI/2+minf(game.player.attack_hold/0.48,1)*TAU,32,gold,2)
		if game.player.blocking:
			centered("GUARD",h/2+70,11,gold)
		if game.message_time > 0 and game.overlay == "":
			var message_width := minf(840,w-100)
			draw_rect(Rect2((w-message_width)*0.5,h-212,message_width,51),Color(0.03,0.06,0.08,0.88))
			draw_line(Vector2((w-message_width)*0.5,h-212),Vector2((w+message_width)*0.5,h-212),Color(gold,0.4),1)
			draw_multiline_string(sans,Vector2((w-message_width)*0.5+18,h-189),game.message,HORIZONTAL_ALIGNMENT_CENTER,message_width-36,14,2,ink)
		if is_instance_valid(game.boss) and not game.boss.dead and game.player.position.x>33 and game.player.position.z>-14:
			var bw := 420.0
			centered("THE BELL KEEPER",h-269,17,ink,serif)
			draw_rect(Rect2((w-bw)*0.5,h-253,bw,5),Color("23373c"))
			draw_rect(Rect2((w-bw)*0.5,h-253,bw*game.boss.health/game.boss.max_health,5),Color("af8676"))
		if game.damage_flash > 0:
			draw_rect(Rect2(0,0,w,h),Color(0.5,0.035,0.035,game.damage_flash*0.23))
	if game.overlay != "":
		draw_rect(Rect2(0,0,w,h),Color(0.014,0.025,0.035,0.91 if game.overlay != "dialogue" else 0.65))
		draw_line(Vector2(66,112),Vector2(w-66,112),Color(gold,0.35),1)
		match game.overlay:
			"pause":
				text("A MOMENT OF STILLNESS",Vector2(66,86),12,gold)
				text("The dark can wait.",Vector2(64,180),43,ink,serif)
				text("Progress is saved at shrines and after major discoveries.",Vector2(68,222),15,muted)
				controls(Vector2(w*0.55,288))
			"settings":
				text("MAKE YOURSELF AT HOME",Vector2(66,86),12,gold)
				text("Settings",Vector2(64,180),43,ink,serif)
			"inventory":
				text("WHAT YOU CARRY",Vector2(66,86),12,gold)
				text("Relics of a pilgrimage",Vector2(64,180),43,ink,serif)
				var relics := [["Pilgrim blade","EQUIPPED • Hold LMB for a charged thrust. RMB to guard."],["Star Needle" if game.flags.needle else "A silent constellation","Q • A ranged shard of starlight. Costs 9 starlight." if game.flags.needle else "Something still waits in the Pilgrim Crypt."],["Moth Form" if game.flags.moth else "Unopened wings","R • Glide after a jump. Reveal hidden marks. RMB to flutter." if game.flags.moth else "Seek the winged reliquary beyond the crypt."],["The Unwritten Name" if game.flags.secret else "An empty page","You remember a name the temple tried to forget." if game.flags.secret else "Silver eyes see what stone conceals."]]
				for i in range(relics.size()):
					var yy: float = 275+i*89
					diamond(Vector2(76,yy-7),5,gold)
					text(relics[i][0],Vector2(102,yy),23,ink,serif)
					wrapped(relics[i][1],Vector2(102,yy+27),w*0.46,13,muted)
				map_draw(Vector2(w*0.67,325),170)
			"dialogue":
				text(game.dialogue_title,Vector2(100,178),13,gold)
				wrapped(game.dialogue,Vector2(100,240),w-200,25,ink,serif)
			"death":
				centered("THE WATER REMEMBERS",h*0.31,13,gold)
				centered("Your light has not gone out.",h*0.43,40,ink,serif)
				centered("Return to the shrine. Your discoveries and shortcuts remain.",h*0.5,16,muted)
			"ending":
				centered("PILGRIMAGE COMPLETE",h*0.27,13,gold)
				centered("A star opens its eye.",h*0.39,48,ink,serif)
				centered("You rang the drowned bell, and found your way home.",h*0.47,18,muted)
				centered("The Unwritten Name discovered" if game.flags.secret else "One secret still sleeps inside the stone",h*0.54,15,gold)
				centered("THE HOLLOW STAR  /  End of the Sunken Cloister demo",h*0.63,13,ink)

func diamond(pos: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([pos+Vector2(0,-radius),pos+Vector2(radius,0),pos+Vector2(0,radius),pos+Vector2(-radius,0)]),color)

func bar(pos: Vector2, width: float, amount: float, color: Color, label: String) -> void:
	draw_rect(Rect2(pos,width*Vector2.RIGHT+Vector2(0,5)),Color("253238"))
	draw_rect(Rect2(pos,Vector2(width*clampf(amount/100,0,1),5)),color)
	text(label,Vector2(pos.x+width+13,pos.y+7),10,muted)
	text(str(int(amount)),Vector2(pos.x-28,pos.y+7),12,color)

func controls(pos: Vector2) -> void:
	text("THE PILGRIM'S ARTS",pos,12,gold)
	var lines := ["W A S D     Walk       Shift     Sprint","Mouse        Look       Space    Jump","Left click    Strike     Hold      Charge","Right click  Guard     E           Interact","Q                Spell       R           Transform","F                Drink      Tab       Relics & route"]
	for i in range(lines.size()):
		text(lines[i],pos+Vector2(0,40+i*33),15,ink)

func map_draw(pos: Vector2, span: float) -> void:
	text("THE SUNKEN CLOISTER",pos+Vector2(-25,-55),12,gold)
	var points := [Vector2(0,span),Vector2(0,span*0.5),Vector2(0,0),Vector2(span*0.5,0),Vector2(span,0),Vector2(span,span*0.5),Vector2(span,span)]
	var names := ["Nave","Vestibule","Gallery","Crypt","Chapel","Moon Gap","Bell"]
	for i in range(points.size()-1):
		draw_line(pos+points[i],pos+points[i+1],Color(muted,0.6),1)
	if game.flags.shortcut:
		draw_line(pos+points[0],pos+points[6],gold,2)
	for i in range(points.size()):
		diamond(pos+points[i],4,gold)
		text(names[i],pos+points[i]+Vector2(8,18),11,muted)
	var p: Vector3 = game.player.position
	var player_point := pos+Vector2(clampf(p.x/46,0,1)*span,clampf((p.z+46)/46,0,1)*span)
	draw_circle(player_point,4,teal)
	text("You",player_point+Vector2(9,-8),11,teal)

func show_menu() -> void:
	if not is_instance_valid(buttons): return
	for child in buttons.get_children():
		buttons.remove_child(child)
		child.queue_free()
	var w := get_viewport_rect().size.x
	var h := get_viewport_rect().size.y
	match game.overlay:
		"title":
			button("Begin pilgrimage",Vector2(68,490),func(): game.start_game(false))
			var b := button("Continue",Vector2(68,547),func(): game.start_game(true))
			b.disabled = not FileAccess.file_exists(game.SAVE_PATH)
			button("Settings",Vector2(68,604),func(): game.set_overlay("settings"))
			button("Leave the temple",Vector2(68,661),func(): game.get_tree().quit())
		"pause":
			button("Resume pilgrimage",Vector2(68,288),func(): game.set_overlay(""))
			button("Relics & route",Vector2(68,345),func(): game.set_overlay("inventory"))
			button("Settings",Vector2(68,402),func(): game.set_overlay("settings"))
			button("Save & return to title",Vector2(68,459),func(): game.save_game(); game.playing=false; game.title_camera.current=true; game.set_overlay("title"))
			button("Save & quit",Vector2(68,516),func(): game.save_game(); game.get_tree().quit())
		"settings":
			slider("Mouse sensitivity",0.0006,0.007,game.settings.sensitivity,Vector2(70,255),func(v): game.settings.sensitivity=v; game.save_settings())
			slider("Field of view",65,100,game.settings.fov,Vector2(70,332),func(v): game.settings.fov=v; game.save_settings())
			slider("Master volume",0,1,game.settings.volume,Vector2(70,409),func(v): game.settings.volume=v; game.save_settings())
			slider("Ambient score",0,1,game.settings.music,Vector2(70,486),func(v): game.settings.music=v; game.save_settings())
			slider("Camera motion",0,1,game.settings.shake,Vector2(70,563),func(v): game.settings.shake=v; game.save_settings())
			check("Subtle retro grain",game.settings.retro,Vector2(w*0.55,264),func(v): game.settings.retro=v; game.save_settings())
			check("Fullscreen",game.settings.fullscreen,Vector2(w*0.55,321),func(v): game.settings.fullscreen=v; game.save_settings())
			button("Back",Vector2(68,h-103),func(): game.set_overlay("pause" if game.playing else "title"))
		"inventory":
			button("Return to the pilgrimage",Vector2(68,h-103),func(): game.set_overlay(""))
		"dialogue":
			button("Continue  [ E ]",Vector2(100,h-138),func(): game.set_overlay(""))
		"death":
			button("Return to the shrine",Vector2(w/2-165,h*0.62),func(): game.respawn())
		"ending":
			button("Explore a little longer",Vector2(w/2-165,h*0.72),func(): game.set_overlay(""))
			button("Return to title",Vector2(w/2-165,h*0.72+57),func(): game.playing=false; game.title_camera.current=true; game.set_overlay("title"))

func button(label: String, pos: Vector2, action: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.position = pos
	b.size = Vector2(330,44)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font",sans)
	b.add_theme_font_size_override("font_size",16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06,0.095,0.11,0.85)
	style.border_color = Color("435556")
	style.set_border_width_all(1)
	style.content_margin_left = 19
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = Color("243b3c")
	hover.border_color = gold
	b.add_theme_stylebox_override("normal",style)
	b.add_theme_stylebox_override("hover",hover)
	b.add_theme_stylebox_override("focus",hover)
	b.add_theme_color_override("font_color",ink)
	b.add_theme_color_override("font_hover_color",Color.WHITE)
	buttons.add_child(b)
	b.pressed.connect(action)
	return b

func slider(label: String, minimum: float, maximum: float, value: float, pos: Vector2, action: Callable) -> void:
	var l := Label.new()
	l.text = label
	l.position = pos
	l.add_theme_color_override("font_color",ink)
	l.add_theme_font_override("font",sans)
	buttons.add_child(l)
	var s := HSlider.new()
	s.position = pos+Vector2(0,33)
	s.size = Vector2(380,20)
	s.min_value = minimum
	s.max_value = maximum
	s.step = (maximum-minimum)/100
	s.value = value
	buttons.add_child(s)
	s.value_changed.connect(action)

func check(label: String, value: bool, pos: Vector2, action: Callable) -> void:
	var b := CheckBox.new()
	b.text = label
	b.position = pos
	b.button_pressed = value
	b.add_theme_font_override("font",sans)
	b.add_theme_font_size_override("font_size",17)
	buttons.add_child(b)
	b.toggled.connect(action)

extends SceneTree
## Generates the content that is tedious to write by hand:
##   res://resources/tilesets/floor_tileset.tres   (floor TileSet)
##   res://assets/characters/player_frames.tres     (SpriteFrames: every pose set x down/up/side)
##   res://assets/characters/player_animations.tres (AnimationLibrary: pickup / throw_*)
##   res://assets/audio/*.wav                       (placeholder sound effects)
##   res://scenes/scavenging/house.tscn              (the house map)
##
## Run from the project folder (after the SVGs have been imported once):
##   godot --headless --path . --script res://tools/build_level.gd
##
## After generating, edit house.tscn in the Godot editor like any scene.
## Re-running this script OVERWRITES house.tscn.
## Only rebuild some parts:  ... --script res://tools/build_level.gd -- --only=player,sounds
## (parts: sounds, player, tileset, house)

const TILE := Vector2i(64, 48)
const FURNITURE_SCENE := "res://scenes/scavenging/furniture.tscn"
const PICKUP_SCENE := "res://scenes/items/item_pickup.tscn"
const FURN := "res://assets/environments/furniture/%s.svg"
const OUT := "res://assets/environments/outside/%s.svg"
const DECOR := "res://assets/environments/decor/%s.svg"
const WALLS := "res://assets/environments/walls/%s.svg"

enum Floor { LIVING, BEDROOM, KITCHEN, STORAGE, PORCH }

# House layout in tiles. Interior = 24 x 17 tiles (1536 x 816 px).
const ROOMS := [
	{"name": "Bedroom", "rect": Rect2i(0, 0, 10, 8), "floor": Floor.BEDROOM},
	{"name": "Kitchen", "rect": Rect2i(10, 0, 14, 8), "floor": Floor.KITCHEN},
	{"name": "LivingRoom", "rect": Rect2i(0, 8, 15, 9), "floor": Floor.LIVING},
	{"name": "Storage", "rect": Rect2i(15, 8, 9, 9), "floor": Floor.STORAGE},
	{"name": "Porch", "rect": Rect2i(4, 17, 6, 2), "floor": Floor.PORCH},
]
const HOUSE_W := 1536.0
const HOUSE_H := 816.0
const PORCH := Rect2(256, 816, 384, 96)

var _root: Node2D
var _rumble := 0.0
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 2024
	var only := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	var want := func(part: String) -> bool: return only.is_empty() or only.has(part)
	if want.call("sounds"):
		_build_sounds()
	if want.call("player"):
		_build_player_frames()
		_build_player_animations()
	if want.call("tileset") or want.call("house"):
		var tileset := _build_tileset()
		if want.call("house"):
			_build_house(tileset)
	print("build_level: done")
	quit()


# ------------------------------------------------------------------ sounds
func _build_sounds() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio"))
	# [start_hz, end_hz, seconds, wave: "sine" | "square" | "noise"]
	_save_wav("pickup", [[660.0, 880.0, 0.07, "sine"], [990.0, 1320.0, 0.12, "sine"]], 0.45)
	_save_wav("error", [[190.0, 170.0, 0.09, "square"], [0.0, 0.0, 0.04, "sine"], [170.0, 150.0, 0.12, "square"]], 0.3)
	_save_wav("tick", [[1400.0, 1200.0, 0.035, "square"]], 0.25)
	_save_wav("time_up", [[880.0, 860.0, 0.18, "square"], [660.0, 640.0, 0.18, "square"], [440.0, 380.0, 0.45, "square"]], 0.3)
	_save_wav("throw", [[1.0, 1.0, 0.22, "noise"]], 0.35)
	_save_wav("thud", [[300.0, 160.0, 0.04, "square"], [150.0, 70.0, 0.14, "sine"]], 0.6)
	_save_wav("news_jingle", [[880.0, 880.0, 0.14, "sine"], [0.0, 0.0, 0.05, "sine"], [1175.0, 1175.0, 0.14, "sine"], [0.0, 0.0, 0.05, "sine"], [1568.0, 1568.0, 0.32, "sine"]], 0.4)
	_save_wav("thunder", [[1.0, 1.0, 1.6, "rumble"]], 0.9)


func _save_wav(file: String, segments: Array, volume: float) -> void:
	const RATE := 22050
	var samples := PackedFloat32Array()
	var phase := 0.0
	for seg in segments:
		var n := int(seg[2] * RATE)
		for i in n:
			var t := float(i) / n
			var freq: float = lerpf(seg[0], seg[1], t)
			phase += freq / RATE
			var s := sin(TAU * phase)
			if seg[3] == "square":
				s = signf(s) * 0.55
			elif seg[3] == "noise":
				s = _rng.randf_range(-1.0, 1.0) * sin(PI * t) # soft whoosh
			elif seg[3] == "rumble":
				_rumble = _rumble * 0.985 + _rng.randf_range(-1.0, 1.0) * 0.06 # low-passed noise
				s = clampf(_rumble * 4.0, -1.0, 1.0) * (1.0 - t) * (1.0 if t > 0.03 else t / 0.03)
			var env := minf(1.0, i / (RATE * 0.004)) * (1.0 if seg[3] == "noise" or seg[3] == "rumble" else pow(1.0 - t, 1.3))
			samples.append(s * env * volume if freq > 0.0 else 0.0)
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.save_to_wav(ProjectSettings.globalize_path("res://assets/audio/%s.wav" % file))


# ----------------------------------------------------------- player frames
## Frame counts must match tools/art/generate_art.mjs (PLAYER_ANIMS).
## Frames are 64x96, pivot = feet at (32, 90) -> AnimatedSprite2D.offset = (0, -42).
const PLAYER_SETS := {
	"idle": [2, 3.0], "walk": [4, 9.0], "run": [4, 13.0],
	"carry_idle": [2, 3.0], "carry_walk": [4, 9.0], "carry_run": [4, 13.0],
	"pickup": [2, 0.0], "throw": [3, 0.0], # pose sets: stepped by the AnimationPlayer
}


func _build_player_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for dir in ["down", "up", "side"]:
		for set_name: String in PLAYER_SETS:
			var count: int = PLAYER_SETS[set_name][0]
			var fps: float = PLAYER_SETS[set_name][1]
			var anim_name := StringName("%s_%s" % [set_name, dir])
			frames.add_animation(anim_name)
			frames.set_animation_loop(anim_name, fps > 0.0)
			frames.set_animation_speed(anim_name, maxf(fps, 1.0))
			for i in count:
				frames.add_frame(anim_name, load("res://assets/characters/player/%s_%s_%d.svg" % [set_name, dir, i]))
	_check(ResourceSaver.save(frames, "res://assets/characters/player_frames.tres"), "player_frames")


# ------------------------------------------------------- player animations
## AnimationPlayer clips. Tracks are relative to the Player node:
##   AnimatedSprite2D:frame    pose frame inside pickup_<dir> / throw_<dir> (direction picked in code)
##   AnimatedSprite2D:scale    squash & stretch (crouch / wind-up / release)
##   AnimatedSprite2D:position small dip
##   . (method)                _on_pickup_grab_frame / _on_throw_release_frame
func _build_player_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation(&"RESET", _clip(0.001, {0.0: 0}, {0.0: Vector2.ONE}, {0.0: Vector2.ZERO}, {}))
	# bend down (0.12) -> hand reaches item, grab happens (0.2) -> stand up (0.45)
	lib.add_animation(&"pickup", _clip(0.45,
		{0.0: 0, 0.1: 1, 0.32: 0},
		{0.0: Vector2.ONE, 0.12: Vector2(1.06, 0.9), 0.3: Vector2(1.0, 0.97), 0.45: Vector2.ONE},
		{0.0: Vector2.ZERO, 0.12: Vector2(0, 3), 0.45: Vector2.ZERO},
		{0.2: &"_on_pickup_grab_frame"}))
	# wind-up: lean back, stretch
	lib.add_animation(&"throw_start", _clip(0.16,
		{0.0: 0},
		{0.0: Vector2.ONE, 0.16: Vector2(0.95, 1.05)},
		{0.0: Vector2.ZERO, 0.16: Vector2(0, -2)},
		{}))
	# release: item leaves the hand at 0.05
	lib.add_animation(&"throw_release", _clip(0.2,
		{0.0: 1},
		{0.0: Vector2(1.07, 0.95), 0.2: Vector2.ONE},
		{0.0: Vector2(0, 1), 0.2: Vector2.ZERO},
		{0.05: &"_on_throw_release_frame"}))
	# recover back to the normal stance
	lib.add_animation(&"throw_recover", _clip(0.2,
		{0.0: 2},
		{0.0: Vector2(1.02, 0.98), 0.2: Vector2.ONE},
		{0.0: Vector2.ZERO, 0.2: Vector2.ZERO},
		{}))
	_check(ResourceSaver.save(lib, "res://assets/characters/player_animations.tres"), "player_animations")


func _clip(length: float, frames: Dictionary, scales: Dictionary, positions: Dictionary, calls: Dictionary) -> Animation:
	var a := Animation.new()
	a.length = length
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, "AnimatedSprite2D:frame")
	a.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
	for time in frames:
		a.track_insert_key(t, time, frames[time])
	t = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, "AnimatedSprite2D:scale")
	for time in scales:
		a.track_insert_key(t, time, scales[time])
	t = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, "AnimatedSprite2D:position")
	for time in positions:
		a.track_insert_key(t, time, positions[time])
	if not calls.is_empty():
		t = a.add_track(Animation.TYPE_METHOD)
		a.track_set_path(t, ".")
		for time in calls:
			a.track_insert_key(t, time, {"method": calls[time], "args": []})
	return a


# ------------------------------------------------------------------ tileset
func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = TILE
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/environments/floor_atlas.svg")
	src.texture_region_size = TILE
	for col in 5:
		for row in 2:
			src.create_tile(Vector2i(col, row))
	ts.add_source(src, 0)
	var path := "res://resources/tilesets/floor_tileset.tres"
	_check(ResourceSaver.save(ts, path), "floor_tileset")
	return load(path)


# -------------------------------------------------------------------- house
func _build_house(tileset: TileSet) -> void:
	_root = Node2D.new()
	_root.name = "House"
	_root.y_sort_enabled = true
	_root.set_script(load("res://scripts/game/house.gd"))
	_root.set("camera_limits", Rect2(-260, -330, 2060, 1580))

	_build_water()
	_build_floor(tileset)
	_build_floor_shading()
	_build_walls()
	_build_wall_decor()
	_build_props()
	_build_outside()
	_build_items()

	var spawn := Marker2D.new()
	spawn.position = Vector2(448, 760)
	_add(_root, spawn, "PlayerSpawn")

	var scene := PackedScene.new()
	_check(scene.pack(_root), "pack house")
	_check(ResourceSaver.save(scene, "res://scenes/scavenging/house.tscn"), "house.tscn")
	_root.free()


func _build_water() -> void:
	var water := Polygon2D.new()
	water.polygon = PackedVector2Array([Vector2(-900, -700), Vector2(2500, -700), Vector2(2500, 1700), Vector2(-900, 1700)])
	water.z_index = -20
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/environments/flood_water.gdshader")
	water.material = mat
	_add(_root, water, "FloodWater")


func _build_floor(tileset: TileSet) -> void:
	var layer := TileMapLayer.new()
	layer.tile_set = tileset
	layer.z_index = -10
	for room in ROOMS:
		var r: Rect2i = room.rect
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				var variant := 1 if _rng.randf() < 0.3 else 0
				layer.set_cell(Vector2i(x, y), 0, Vector2i(room.floor, variant))
	_add(_root, layer, "Floor")


func _build_floor_shading() -> void:
	var holder := Node2D.new()
	holder.z_index = -9
	_add(_root, holder, "FloorShading")
	var ink := Color("211e1b")
	# raised floor edge of the stilt house (front face of the floor slab)
	_poly(holder, "FoundationFront", [Vector2(-8, 824), Vector2(HOUSE_W + 8, 824), Vector2(HOUSE_W + 8, 852), Vector2(-8, 852)], Color("4a3322"))
	_poly(holder, "PorchFront", [Vector2(PORCH.position.x, PORCH.end.y), Vector2(PORCH.end.x, PORCH.end.y), Vector2(PORCH.end.x, PORCH.end.y + 22), Vector2(PORCH.position.x, PORCH.end.y + 22)], Color("3d2a1c"))
	var outline := Line2D.new()
	outline.points = PackedVector2Array([Vector2(-8, -8), Vector2(-8, 852), Vector2(PORCH.position.x, 852), Vector2(PORCH.position.x, PORCH.end.y + 22),
		Vector2(PORCH.end.x, PORCH.end.y + 22), Vector2(PORCH.end.x, 852), Vector2(HOUSE_W + 8, 852), Vector2(HOUSE_W + 8, -8)])
	outline.width = 4.0
	outline.default_color = ink
	_add(holder, outline, "Outline")
	# soft contact shadow along the walls (painted ambient occlusion)
	_gradient_strip(holder, "BackWallShadow", Rect2(0, 0, HOUSE_W, 46), 0.38)
	_gradient_strip(holder, "MidWallShadow", Rect2(0, 392, HOUSE_W, 30), 0.25)
	_gradient_strip(holder, "PorchShadow", Rect2(PORCH.position.x, 824, PORCH.size.x, 26), 0.3)
	# warm indoor light (additive) — the outside water stays cool
	var warm := _poly(holder, "WarmLight", [Vector2(0, 0), Vector2(HOUSE_W, 0), Vector2(HOUSE_W, HOUSE_H), Vector2(0, HOUSE_H)], Color(1.0, 0.75, 0.42, 0.07))
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	warm.material = add_mat


func _gradient_strip(parent: Node, node_name: String, r: Rect2, strength: float) -> void:
	var poly := _poly(parent, node_name, [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)], Color.WHITE)
	var dark := Color(0.05, 0.04, 0.03, strength)
	var clear := Color(0.05, 0.04, 0.03, 0.0)
	poly.vertex_colors = PackedColorArray([dark, dark, clear, clear])


# ----------------------------------------------------------------- walls
func _build_walls() -> void:
	var visuals := Node2D.new()
	visuals.y_sort_enabled = true
	_add(_root, visuals, "Walls")
	var body := StaticBody2D.new()
	body.collision_mask = 0
	_add(_root, body, "WallCollision")

	# Tall back (north) wall
	var back := _region_sprite(load(WALLS % "back_wall"), Rect2(0, 0, HOUSE_W, 128))
	back.position = Vector2(0, 0)
	back.offset = Vector2(0, -128)
	_add(visuals, back, "BackWall")
	_rect_shape(body, Rect2(-16, -24, HOUSE_W + 32, 24))

	# Horizontal cut-away walls: [y, x0, x1, gaps]
	_h_wall(visuals, body, 384.0, 0.0, HOUSE_W, [Vector2(192, 320), Vector2(704, 832), Vector2(1216, 1344)])
	_h_wall(visuals, body, HOUSE_H, 0.0, HOUSE_W, [Vector2(384, 512)])
	# Vertical cut-away walls: [x, y0, y1, gaps]
	_v_wall(visuals, body, 0.0, -8.0, HOUSE_H, [])
	_v_wall(visuals, body, HOUSE_W, -8.0, HOUSE_H, [])
	_v_wall(visuals, body, 640.0, 0.0, 384.0, [Vector2(144, 240)])
	_v_wall(visuals, body, 960.0, 384.0, HOUSE_H, [Vector2(528, 624)])

	# Porch edges: invisible (the water is the visual boundary) but solid
	_rect_shape(body, Rect2(PORCH.position.x - 16, PORCH.position.y, 16, PORCH.size.y + 16))
	_rect_shape(body, Rect2(PORCH.end.x, PORCH.position.y, 16, PORCH.size.y + 16))
	_rect_shape(body, Rect2(PORCH.position.x, PORCH.end.y, PORCH.size.x, 16))


func _h_wall(visuals: Node, body: StaticBody2D, y: float, x0: float, x1: float, gaps: Array) -> void:
	for seg in _segments(x0, x1, gaps):
		var s := _region_sprite(load(WALLS % "wall_cut_h"), Rect2(0, 0, seg.y - seg.x, 36))
		s.position = Vector2(seg.x, y + 8)
		s.offset = Vector2(0, -36)
		_add(visuals, s, "WallH")
		_rect_shape(body, Rect2(seg.x, y - 8, seg.y - seg.x, 16))
		_post(visuals, Vector2(seg.x + 8, y + 8))
		_post(visuals, Vector2(seg.y - 8, y + 8))


func _v_wall(visuals: Node, body: StaticBody2D, x: float, y0: float, y1: float, gaps: Array) -> void:
	for seg in _segments(y0, y1, gaps):
		var y := seg.x
		while y < seg.y:
			# one sprite per tile row so tall things Y-sort correctly beside the wall
			var y2 := minf(y + TILE.y, seg.y)
			var s := _region_sprite(load(WALLS % "wall_cut_v"), Rect2(0, 0, 16, y2 - y))
			s.position = Vector2(x - 8, y2)
			s.offset = Vector2(0, -(y2 - y) - 20)
			_add(visuals, s, "WallV")
			y = y2
		_rect_shape(body, Rect2(x - 8, seg.x, 16, seg.y - seg.x))
		_post(visuals, Vector2(x, seg.y))


func _segments(a: float, b: float, gaps: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var start := a
	for g in gaps:
		if g.x > start:
			result.append(Vector2(start, g.x))
		start = g.y
	if start < b:
		result.append(Vector2(start, b))
	return result


func _post(parent: Node, pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load(WALLS % "wall_post")
	s.centered = false
	s.offset = Vector2(-10, -36)
	s.position = pos
	_add(parent, s, "WallPost")


func _region_sprite(tex: Texture2D, region: Rect2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = region
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	return s


func _rect_shape(body: StaticBody2D, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	_add(body, cs, "Shape")


# ------------------------------------------------------------- decoration
func _build_wall_decor() -> void:
	var holder := Node2D.new()
	holder.y_sort_enabled = true
	_add(_root, holder, "WallDecor")
	# [texture, centre on the back wall]
	var decor := [
		["picture_stupa", Vector2(130, -84)], ["window", Vector2(430, -78)], ["buddha_shelf", Vector2(585, -100)],
		["window", Vector2(770, -78)], ["calendar", Vector2(930, -88)], ["photo", Vector2(1300, -80)],
		["clock", Vector2(1390, -96)], ["picture_candle", Vector2(1470, -80)],
	]
	for d in decor:
		var s := Sprite2D.new()
		s.texture = load(DECOR % d[0])
		# origin just in front of the back wall so it draws over the wall but under furniture
		s.position = Vector2(d[1].x, 1)
		s.offset = Vector2(0, d[1].y - 1)
		_add(holder, s, d[0].to_pascal_case())


func _build_props() -> void:
	var holder := Node2D.new()
	holder.y_sort_enabled = true
	_add(_root, holder, "Props")
	# [texture, position (front-bottom centre), footprint, options]
	var props := [
		# Bedroom
		["bed", Vector2(96, 196), Vector2(112, 150)],
		["nightstand", Vector2(186, 74), Vector2(44, 22)],
		["wardrobe", Vector2(290, 48), Vector2(108, 36)],
		["dresser", Vector2(430, 60), Vector2(120, 36)],
		["med_cabinet", Vector2(560, 66), Vector2(64, 34)],
		["fan", Vector2(590, 300), Vector2(24, 14)],
		["plant", Vector2(40, 362), Vector2(30, 16)],
		["rug", Vector2(340, 260), Vector2.ZERO, {"collide": false, "z": -5}],
		# Kitchen
		["counter_sink", Vector2(770, 58), Vector2(188, 44)],
		["stove_counter", Vector2(940, 58), Vector2(120, 44)],
		["fridge", Vector2(1060, 52), Vector2(68, 40)],
		["food_shelf", Vector2(1180, 46), Vector2(120, 36)],
		["water_jar", Vector2(1290, 72), Vector2(56, 30)],
		["plant", Vector2(1500, 60), Vector2(30, 16)],
		["dining_table", Vector2(1000, 270), Vector2(148, 56)],
		["chair", Vector2(905, 262), Vector2(30, 14)],
		["chair", Vector2(1095, 262), Vector2(30, 14), {"flip": true}],
		# Living room
		["tv_stand", Vector2(110, 440), Vector2(132, 30)],
		["sofa", Vector2(150, 640), Vector2(168, 56)],
		["coffee_table", Vector2(150, 734), Vector2(108, 30)],
		["armchair", Vector2(330, 640), Vector2(76, 40)],
		["rug", Vector2(330, 590), Vector2.ZERO, {"collide": false, "z": -5}],
		["fan", Vector2(620, 440), Vector2(24, 14)],
		["doc_cabinet", Vector2(880, 454), Vector2(92, 30)],
		["shoe_rack", Vector2(300, 800), Vector2(72, 16)],
		["doormat", Vector2(448, 822), Vector2.ZERO, {"collide": false, "z": -5}],
		["plant", Vector2(30, 800), Vector2(30, 16)],
		["plant", Vector2(925, 800), Vector2(30, 16)],
		# Storage
		["metal_rack", Vector2(1060, 452), Vector2(148, 36)],
		["crate", Vector2(1440, 470), Vector2(68, 30)],
		["crate", Vector2(1470, 560), Vector2(68, 30)],
		["boxes", Vector2(1480, 790), Vector2(80, 40)],
		["workbench", Vector2(1180, 780), Vector2(160, 34)],
		["barrel", Vector2(1010, 790), Vector2(52, 26)],
		["bucket_broom", Vector2(1340, 790), Vector2(40, 16)],
	]
	for p in props:
		_prop(holder, FURN % p[0], p[1], p[2], p[3] if p.size() > 3 else {})


func _build_outside() -> void:
	var holder := Node2D.new()
	holder.y_sort_enabled = true
	_add(_root, holder, "Outside")
	var outside := [
		["banana_tree", Vector2(-150, 260)], ["banana_tree", Vector2(-190, 660)], ["banana_tree", Vector2(1700, 320)],
		["banana_tree", Vector2(1730, 780)], ["banana_tree", Vector2(200, -150)], ["banana_tree", Vector2(1250, -140)],
		["pole", Vector2(1640, 40)], ["fence", Vector2(1100, 1010)], ["fence", Vector2(1240, 1010)],
		["fence", Vector2(-80, 1010)], ["debris_bucket", Vector2(1010, 960)], ["debris_plank", Vector2(300, 1020)],
		["debris_sandal", Vector2(1520, 940)], ["debris_plank", Vector2(-260, 320)],
	]
	for o in outside:
		_prop(holder, OUT % o[0], o[1], Vector2.ZERO, {"collide": false})
	# stilts under the raised floor and porch
	for x in [16.0, 208.0, 704.0, 896.0, 1088.0, 1280.0, 1520.0, 272.0, 448.0, 624.0]:
		var y := 936.0 if x in [272.0, 448.0, 624.0] else 876.0
		_prop(holder, OUT % "stilt", Vector2(x, y), Vector2.ZERO, {"collide": false})


func _prop(parent: Node, tex_path: String, pos: Vector2, footprint: Vector2, opts: Dictionary) -> void:
	var f: Node2D = load(FURNITURE_SCENE).instantiate()
	f.set("texture", load(tex_path))
	f.set("footprint", footprint if footprint != Vector2.ZERO else Vector2(8, 8))
	f.set("has_collision", opts.get("collide", true))
	f.set("flip_h", opts.get("flip", false))
	f.z_index = opts.get("z", 0)
	f.position = pos
	_add(parent, f, tex_path.get_file().get_basename().to_pascal_case())


# ------------------------------------------------------------------ items
func _build_items() -> void:
	var holder := Node2D.new()
	holder.y_sort_enabled = true
	_add(_root, holder, "Items")
	# [item id, position (floor point in front of the surface), quantity, elevation]
	var items := [
		["water", Vector2(845, 62), 2, 58.0],          # kitchen counter
		["water", Vector2(1345, 84), 2, 0.0],          # beside the water jar
		["canned_food", Vector2(1150, 50), 2, 52.0],   # food shelf
		["canned_food", Vector2(1030, 456), 2, 58.0],  # storage rack
		["canned_food", Vector2(1030, 274), 1, 48.0],  # dining table
		["medicine", Vector2(560, 70), 1, 72.0],       # medicine cabinet
		["medicine", Vector2(186, 78), 1, 40.0],       # nightstand
		["flashlight", Vector2(455, 64), 1, 56.0],     # dresser drawer
		["batteries", Vector2(1215, 784), 2, 54.0],    # workbench
		["batteries", Vector2(164, 444), 2, 34.0],     # TV cabinet
		["rope", Vector2(1300, 640), 1, 0.0],          # storage floor
		["radio", Vector2(150, 738), 1, 30.0],         # coffee table
		["documents", Vector2(880, 458), 1, 68.0],     # document cabinet
	]
	var scene: PackedScene = load(PICKUP_SCENE)
	for it in items:
		var p: Node2D = scene.instantiate()
		p.set("item", load("res://resources/items/%s.tres" % it[0]))
		p.set("quantity", it[2])
		p.set("elevation", it[3])
		p.position = it[1]
		_add(holder, p, String(it[0]).to_pascal_case())
	# Family members (default seats; shuffled at runtime like the items)
	for f in [["family_mother", Vector2(110, 652), 26.0], ["family_sister", Vector2(430, 320), 0.0], ["family_grandpa", Vector2(905, 276), 24.0]]:
		var p: Node2D = scene.instantiate()
		p.set("item", load("res://resources/items/%s.tres" % f[0]))
		p.set("quantity", 1)
		p.set("elevation", f[2])
		p.position = f[1]
		_add(holder, p, String(f[0]).trim_prefix("family_").to_pascal_case())

	# Every place an item may be put when the layout is shuffled (House.randomize_layout).
	# [position = floor point in front of the surface, elevation of the surface]
	var spots := Node2D.new()
	_add(_root, spots, "ItemSpots")
	var item_spots := [
		[Vector2(845, 62), 58.0], [Vector2(735, 62), 58.0], [Vector2(960, 62), 58.0], [Vector2(1345, 84), 0.0],
		[Vector2(1150, 50), 52.0], [Vector2(1205, 50), 90.0], [Vector2(1030, 456), 58.0], [Vector2(1090, 456), 98.0],
		[Vector2(1030, 274), 48.0], [Vector2(970, 274), 48.0], [Vector2(560, 70), 72.0], [Vector2(186, 78), 40.0],
		[Vector2(455, 64), 56.0], [Vector2(405, 64), 56.0], [Vector2(1215, 784), 54.0], [Vector2(164, 444), 34.0],
		[Vector2(1300, 640), 0.0], [Vector2(150, 738), 30.0], [Vector2(880, 458), 68.0], [Vector2(230, 250), 0.0],
		[Vector2(330, 700), 0.0], [Vector2(620, 560), 0.0], [Vector2(740, 700), 0.0], [Vector2(1400, 720), 0.0],
		[Vector2(1440, 474), 52.0], [Vector2(1470, 794), 100.0], [Vector2(1300, 300), 0.0], [Vector2(560, 250), 0.0],
	]
	for s in item_spots:
		var m := Marker2D.new()
		m.position = s[0]
		m.set_meta("elevation", s[1])
		_add(spots, m, "Spot")
	# Where a family member may sit (sofa, bed, chairs, floors)
	var seats := Node2D.new()
	_add(_root, seats, "FamilySpots")
	var family_spots := [
		[Vector2(110, 652), 26.0], [Vector2(190, 652), 26.0], [Vector2(330, 652), 30.0], [Vector2(96, 206), 30.0],
		[Vector2(905, 276), 24.0], [Vector2(1200, 330), 0.0], [Vector2(1250, 560), 0.0], [Vector2(520, 640), 0.0],
		[Vector2(430, 320), 0.0],
	]
	for s in family_spots:
		var m := Marker2D.new()
		m.position = s[0]
		m.set_meta("elevation", s[1])
		_add(seats, m, "Seat")


# ---------------------------------------------------------------- helpers
func _add(parent: Node, node: Node, node_name: String) -> Node:
	node.name = node_name
	parent.add_child(node, true)
	node.owner = _root
	return node


func _poly(parent: Node, node_name: String, points: Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array(points)
	p.color = color
	_add(parent, p, node_name)
	return p


func _check(err: int, what: String) -> void:
	if err != OK:
		push_error("build_level: failed to save %s (error %d)" % [what, err])

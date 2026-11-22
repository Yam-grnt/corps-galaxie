extends Node3D
## Essai de la présence du guide sur ordinateur, sans casque :
##   Godot --xr-mode off --path godot res://essai_presence.tscn            → le scénario tourne en boucle, au temps réel
##   Godot --xr-mode off --path godot res://essai_presence.tscn -- --photo → temps simulé (1/90 s par image), captures dans user://, puis quitte
## Scénario (26,5 s, joué trois fois : incarnée sur fond noir, descriptive, incarnée sur fond clair de réalité mixte) :
##   repos → écoute → réfléchit 5 s → parle (niveau de voix simulé) → montre trois cibles → repos → disparaît.
## Captures : presence_<passe>_<instant>.png (vue entière) et planche_<passe>.png (quinze gros plans, dans l'ordre du scénario).
## Le mode photo vérifie aussi les interdits (distance au visage, jamais derrière, jamais devant l'objet, pas d'à-coup).

const PresenceScript := preload("res://presence.gd")

const TETE := Vector3(0, 1.6, 0)
const OBJET := Vector3(0, 1.25, -0.85)
const R_OBJET := 0.3
const CIBLES := [Vector3(-0.16, 1.42, -0.62), Vector3(-0.62, 1.55, -1.1), Vector3(0.3, 1.02, -0.72)]
const DUREE := 26.5
const PASSES := ["incarne", "descriptif", "clair"]
const VIGNETTE := 320
# [instant dans la passe, nom, vue entière aussi]
const PRISES := [
	[1.0, "apparition", true], [2.7, "repos", true], [4.2, "ecoute_arrive", false], [5.8, "ecoute", true], [8.0, "reflechit_a", false],
	[10.6, "reflechit_b", true], [12.6, "parle_a", false], [13.9, "parle_b", true], [16.42, "montre_vol", true],
	[17.9, "montre_pose_a", true], [18.56, "montre_vol_b", false], [20.2, "montre_pose_b", false], [22.4, "montre_pose_c", true],
	[23.0, "retour", false], [26.05, "disparition", true]]

var camera: Camera3D
var env: Environment
var presence: PresenceScript
var photo := false
var image := 0
var t_sim := 0.0
var passe := -1
var prises: Array = []
var planche: Image
var n_vignettes := 0
var fini := false
var avant_pos := Vector3.ZERO
var avant_vit := Vector3.ZERO
var v_max := 0.0
var a_max := 0.0
var d_min := 1e9
var fautes := 0
var etat_courant := {}


func _ready() -> void:
	photo = "--photo" in OS.get_cmdline_user_args()
	get_window().size = Vector2i(1600, 1000)
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.006, 0.016)
	we.environment = env
	add_child(we)
	camera = Camera3D.new()
	camera.position = TETE
	camera.fov = 75.0
	camera.near = 0.02
	add_child(camera)
	_construire_objet()
	presence = PresenceScript.new()
	add_child(presence)
	presence.preparer()
	if photo:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		print("captures dans : ", ProjectSettings.globalize_path("user://"))


## L'objet étudié : une sphère de grains, dans l'esprit du corps.
func _construire_objet() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := 2600
	var pos := PackedVector3Array()
	var cou := PackedColorArray()
	pos.resize(n)
	cou.resize(n)
	for i in n:
		var z := rng.randf_range(-1, 1)
		var a := rng.randf() * TAU
		var r := sqrt(1.0 - z * z)
		pos[i] = Vector3(r * cos(a), z, r * sin(a)) * R_OBJET * (1.0 if rng.randf() < 0.7 else pow(rng.randf(), 0.4))
		cou[i] = Color(0.925, 0.91, 0.875).lerp(Color(1.0, 0.45, 0.5) if rng.randf() < 0.3 else Color(0.55, 0.75, 1.0), rng.randf() * 0.7)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_COLOR] = cou
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arr)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled;
varying vec3 col;
void vertex() {
	float u = max(abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y * 0.5 / 792.0, 0.75);
	POINT_SIZE = 2.6 * u;
	col = COLOR.rgb * 0.5;
}
void fragment() {
	vec2 q = POINT_COORD * 2.0 - 1.0;
	float k = 1.0 - dot(q, q);
	if (k <= 0.0) {
		discard;
	}
	ALBEDO = pow(col * smoothstep(0.0, 0.4, k), vec3(2.2));
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	m.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = OBJET
	add_child(mi)


## Ce que main.gd passerait à la présence à l'instant t de la passe.
func _etat(t: float, mode: String) -> Dictionary:
	var e := {"tete": TETE, "avant": Vector3(0, 0, -1), "objet": OBJET, "rayon": R_OBJET,
		"mode": "descriptif" if mode == "descriptif" else "incarne", "humeur": 0.3 if mode == "incarne" else 0.0,
		"clair": 1.0 if mode == "clair" else 0.0, "etat": "repos"}
	if t >= 3.0 and t < 6.0:
		e.etat = "ecoute"
	elif t >= 6.0 and t < 11.0:
		e.etat = "reflechit"
	elif t >= 11.0 and t < 16.0:
		e.etat = "parle"
		# une voix simulée : des syllabes, des phrases, des respirations (en mode descriptif on laisse la présence l'inventer)
		if mode != "descriptif":
			var phrase := smoothstep(-0.2, 0.2, sin((t - 11.0) * 1.9 + 0.4) + 0.6)
			e["voix"] = clampf(absf(sin(t * 9.0)) * (0.65 + 0.35 * sin(t * 2.3)), 0.0, 1.0) * phrase
	elif t >= 16.0 and t < 22.6:
		e.etat = "montre"
		e["cible"] = CIBLES[clampi(int((t - 16.0) / 2.2), 0, 2)]
	return e


func _process(dt: float) -> void:
	if fini:
		return
	image += 1
	if photo:
		# la capture montre l'image précédente, c'est-à-dire l'instant t_sim
		var tp := t_sim - passe * DUREE
		while passe >= 0 and not prises.is_empty() and tp >= prises[0][0]:
			_capturer(prises.pop_front())
		dt = 1.0 / 90.0 if image > 4 else 0.0      # les premières images laissent les shaders se compiler
	t_sim += dt
	var p := int(t_sim / DUREE)
	if p != passe:
		if photo and passe >= 0:
			planche.save_png("user://planche_%s.png" % PASSES[passe])
		if photo and p >= PASSES.size():
			_conclure()
			return
		passe = p
		var mode: String = PASSES[passe % PASSES.size()]
		env.background_color = Color(0.74, 0.72, 0.68) if mode == "clair" else Color(0.004, 0.006, 0.016)
		prises = PRISES.duplicate()
		planche = Image.create(VIGNETTE * 4, VIGNETTE * 4, false, Image.FORMAT_RGB8)
		n_vignettes = 0
		presence.apparaitre()
		print("passe ", mode)
	var t := t_sim - passe * DUREE
	if t > 25.3:
		presence.disparaitre()
	etat_courant = _etat(t, PASSES[passe % PASSES.size()])
	presence.maj(dt, etat_courant)
	if photo and dt > 0.0 and t > 0.1:
		_verifier(dt, t)
	avant_pos = presence.coeur


func _verifier(dt: float, t: float) -> void:
	var c := presence.coeur
	var vit := (c - avant_pos) / dt
	if t > 0.2:
		v_max = maxf(v_max, vit.length())
		a_max = maxf(a_max, (vit - avant_vit).length() / dt)
	avant_vit = vit
	var d := c.distance_to(TETE)
	d_min = minf(d_min, d)
	var faute := ""
	if d < 0.6 - 1e-4:
		faute = "à moins de 60 cm du visage"
	if (c - TETE).dot(Vector3(0, 0, -1)) <= 0.0:
		faute = "derrière le visiteur"
	if etat_courant.etat != "montre" and presence._t_retour > 1.5:
		var axe := (OBJET - TETE).normalized()
		var s := (c - TETE).dot(axe)
		var long := OBJET.distance_to(TETE)
		if s > 0.0 and s < long and ((c - TETE) - axe * s).length() < R_OBJET * s / long + 0.08:
			faute = "devant l'objet"
	if faute != "":
		fautes += 1
		if fautes < 6:
			print("FAUTE à ", snappedf(t_sim, 0.01), " s : ", faute)


func _capturer(prise: Array) -> void:
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var nom := "%s_%s" % [PASSES[passe], prise[1]]
	if prise[2]:
		img.save_png("user://presence_%s.png" % nom)
	# gros plan autour de la présence, rangé sur la planche de la passe
	var ecran := camera.unproject_position(presence.coeur)
	var x := clampi(int(ecran.x) - VIGNETTE / 2, 0, img.get_width() - VIGNETTE)
	var y := clampi(int(ecran.y) - VIGNETTE / 2, 0, img.get_height() - VIGNETTE)
	planche.blit_rect(img, Rect2i(x, y, VIGNETTE, VIGNETTE), Vector2i((n_vignettes % 4) * VIGNETTE, (n_vignettes / 4) * VIGNETTE))
	n_vignettes += 1
	print("capture ", nom, " à ", snappedf(t_sim, 0.01), " s  (", presence.etat, ", à ", snappedf(presence.coeur.distance_to(TETE), 0.01), " m)")


func _conclure() -> void:
	fini = true
	print("vitesse maximale : ", snappedf(v_max, 0.01), " m/s ; accélération maximale : ", snappedf(a_max, 0.1), " m/s² ; distance minimale au visage : ",
		snappedf(d_min, 0.01), " m ; fautes : ", fautes)
	var ok := fautes == 0 and v_max < 3.2 and a_max < 60.0
	print("ESSAI PRESENCE ", "OK" if ok else "ÉCHEC")
	get_tree().quit(0 if ok else 1)

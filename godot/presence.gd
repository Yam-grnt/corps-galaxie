class_name Presence extends Node3D
## La présence du guide : « une voix sans poussière, logée dans un corps de lumière ».
##
## Elle, c'est le cœur : une lueur chaude, lisse, sans grain propre, qui s'allume sur place. Autour, une petite galaxie
## (deux bras, un halo, une poignée d'astres) faite d'une poussière qu'elle emprunte au corps étudié : les grains montent
## de l'objet quand elle apparaît, et y retournent quand elle s'efface. Jamais attachée à la tête du visiteur :
##   repos     : disque incliné qui tourne lentement, à côté de l'objet, un peu au-dessus du regard ;
##   écoute    : elle s'approche, se penche, et son disque se creuse en coupe tournée vers le visiteur (des rides y
##               glissent vers le cœur : elle recueille) ;
##   réfléchit : elle se retire un peu, ses bras se renouent en un seul fil de lumière qui coule sans fin sur un nœud
##               de trèfle, parcouru de perles dorées à contre-courant ;
##   parle     : elle s'avance, s'ouvre face au visiteur, et des ondes partent du cœur au rythme de la voix ;
##   montre    : elle file vers la cible en comète (chaque grain suit le cœur avec son propre retard), s'y pose en
##               anneau doré autour du point désigné, puis revient.
## En mode « descriptif », il ne reste que le cœur : un point de lumière discret qui respire avec la voix.
##
## Un seul nuage de points (N grains, un appel de dessin), tout animé dans le vertex shader par quelques uniforms.
## Un second appel, facultatif (clé "clair" > 0 : réalité mixte dans une pièce claire), dessine un voile sombre et doux
## derrière elle pour que le grain additif reste lisible.
##
## Le nœud lui-même n'a pas besoin d'être placé : tout est calculé en repère monde. `coeur` donne sa position.

const N_COEUR := 220
const N_BRAS := 1300
const N_HALO := 420
const N_ASTRES := 40
const N := N_COEUR + N_BRAS + N_HALO + N_ASTRES     # 1 980 grains
const RAYON := 0.08                 # rayon du disque (mètres) : 16 cm d'envergure
const RAYON_POSE := 0.07            # rayon de l'anneau posé autour d'une cible
const N_TRACE := 16                 # positions passées du cœur transmises au shader
const DUREE_TRACE := 0.6            # … couvrant cette durée (secondes)
const PAS := 1.0 / 120.0            # pas de la mémoire du trajet
const N_MEMO := 96
const D_MIN := 0.6                  # jamais plus près du visage (mètres) ; la place visée garde une marge
const D_VISEE := 0.74
const AZIMUT_MAX := 0.72            # (radians) écart maximal à l'axe du regard : elle reste dans le champ, jamais derrière

var coeur := Vector3.ZERO           # position actuelle (repère monde)
var etat := "repos"
var presente := false               # apparaitre() / disparaitre()
var posee := false                  # en « montre » : vrai quand elle est arrivée sur la cible
var vitesse := Vector3.ZERO         # (m/s) pour qui voudrait l'accompagner d'un son

var _nuage: MeshInstance3D
var _mat: ShaderMaterial
var _voile: MeshInstance3D
var _mat_voile: ShaderMaterial
var _t := 0.0
var _vis := 0.0
var _a_poser := true                # la prochaine image la place d'emblée au bon endroit (pas d'arrivée de loin)
var _cote := 1.0
var _normale := Vector3(0, 0.6, 0.8).normalized()
var _axe_x := Vector3.RIGHT
var _phase := 0.0
var _v_phase := 0.35
var _flux := 0.0
var _onde := 0.0
var _voix := 0.0
var _p_ecoute := 0.0
var _p_pense := 0.0
var _p_parle := 0.0
var _p_pose := 0.0
var _mini := 0.0
var _humeur := 0.0
var _clair := 0.0
var _traine := 0.12
var _vol := 0.0
var _micro := 0.6
var _elan := Vector3.ZERO
var _t_retour := 9.0                # temps écoulé depuis la fin d'un « montre »
var _memo := PackedVector3Array()   # trajet du cœur, du plus récent au plus ancien, un point tous les PAS
var _reste := 0.0
var _trace := PackedVector3Array()


# ───────── préparation ─────────

func preparer() -> void:
	for e in get_children():
		e.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261123
	var pos := PackedVector3Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var uv := PackedVector2Array()
	pos.resize(N)
	c0.resize(N * 4)
	c1.resize(N * 4)
	uv.resize(N)
	for i in N:
		var nature := 0
		var rang := 0.0
		var p := Vector3.ZERO
		if i < N_COEUR:
			# le cœur : une petite boule serrée, plus dense au centre
			rang = float(i) / N_COEUR
			p = _boule(rng) * pow(rng.randf(), 0.7) * 0.17
		elif i < N_COEUR + N_BRAS:
			# deux bras en spirale logarithmique dans le plan xz, et un peu de poussière entre eux
			nature = 1
			rang = float(i - N_COEUR) / N_BRAS
			var r := 0.14 + 0.86 * pow(rng.randf(), 0.75)
			var a := rng.randf() * TAU
			if rng.randf() < 0.82:
				a = float(rng.randi() % 2) * PI + log(r / 0.14) * 1.9 + rng.randfn() * 0.16 / (0.3 + r)
			p = Vector3(r * cos(a), rng.randfn() * 0.035 * (1.25 - r), r * sin(a))
		elif i < N_COEUR + N_BRAS + N_HALO:
			# le halo : une poussière rare, un peu aplatie, qui déborde le disque
			nature = 2
			rang = float(i - N_COEUR - N_BRAS) / N_HALO
			p = _sphere(rng) * (0.35 + 0.95 * pow(rng.randf(), 0.6)) * Vector3(1.0, 0.62, 1.0)
		else:
			# quelques astres plus vifs, sur des orbites inclinées
			nature = 3
			rang = float(i - N_COEUR - N_BRAS - N_HALO) / N_ASTRES
			p = _sphere(rng) * rng.randf_range(0.75, 1.3) * Vector3(1.0, 0.45, 1.0)
		pos[i] = p
		var o := i * 4
		var j := Vector3(rng.randfn(), rng.randfn(), rng.randfn())      # écart au fil du nœud, à l'anneau
		c0[o] = j.x
		c0[o + 1] = j.y
		c0[o + 2] = j.z
		c0[o + 3] = float(nature)
		for k in 4:
			c1[o + k] = rng.randf()
		uv[i] = Vector2(rng.randf() * TAU, rang)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_CUSTOM0] = c0
	arr[Mesh.ARRAY_CUSTOM1] = c1
	var format := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var maillage := ArrayMesh.new()
	maillage.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arr, [], {}, format)
	maillage.custom_aabb = AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))    # les positions sont calculées par le shader
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.render_priority = 2
	maillage.surface_set_material(0, _mat)
	_nuage = MeshInstance3D.new()
	_nuage.mesh = maillage
	_nuage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_nuage.top_level = true
	_nuage.visible = false
	add_child(_nuage)
	_nuage.global_transform = Transform3D.IDENTITY
	# le voile de la réalité mixte
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var shv := Shader.new()
	shv.code = SHADER_VOILE
	_mat_voile = ShaderMaterial.new()
	_mat_voile.shader = shv
	_mat_voile.render_priority = 1
	q.material = _mat_voile
	_voile = MeshInstance3D.new()
	_voile.mesh = q
	_voile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_voile.extra_cull_margin = 1.0
	_voile.top_level = true
	_voile.visible = false
	add_child(_voile)
	_memo.resize(N_MEMO)
	_trace.resize(N_TRACE)
	_vis = 0.0
	_a_poser = true
	presente = false


## Le cœur s'allume à sa place, la poussière monte de l'objet étudié et s'enroule autour de lui (deux secondes).
func apparaitre() -> void:
	if not presente and _vis <= 0.0:
		_a_poser = true
	presente = true


## Elle rend sa poussière à l'objet et s'éteint (une seconde et demie).
func disparaitre() -> void:
	presente = false


func _boule(rng: RandomNumberGenerator) -> Vector3:
	while true:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if v.length_squared() <= 1.0:
			return v
	return Vector3.ZERO


func _sphere(rng: RandomNumberGenerator) -> Vector3:
	var z := rng.randf_range(-1, 1)
	var a := rng.randf() * TAU
	var r := sqrt(1.0 - z * z)
	return Vector3(r * cos(a), z, r * sin(a))


# ───────── à chaque image ─────────

func maj(dt: float, e: Dictionary) -> void:
	if _mat == null:
		return
	dt = clampf(dt, 0.0, 0.1)
	_t += dt
	_vis = move_toward(_vis, 1.0 if presente else 0.0, dt / (2.0 if presente else 1.4))
	# ce que main.gd nous dit
	var tete: Vector3 = e.get("tete", Vector3(0, 1.6, 0))
	var av: Vector3 = e.get("avant", Vector3(0, 0, -1))
	var avant := Vector3(av.x, 0, av.z)
	avant = avant.normalized() if avant.length() > 0.01 else Vector3(0, 0, -1)
	var droite := avant.cross(Vector3.UP)
	var objet: Vector3 = e.get("objet", tete + avant * 0.9 - Vector3(0, 0.3, 0))
	var r_objet := maxf(float(e.get("rayon", 0.3)), 0.02)
	var nouvel_etat := str(e.get("etat", "repos"))
	if not nouvel_etat in ["repos", "ecoute", "reflechit", "parle", "montre"]:
		nouvel_etat = "repos"
	if etat == "montre" and nouvel_etat != "montre":
		_t_retour = 0.0
	etat = nouvel_etat
	_t_retour += dt
	var a_cible := e.has("cible")
	var cible: Vector3 = e.get("cible", objet)
	var incarne := str(e.get("mode", "incarne")) != "descriptif"
	_humeur = _vers(_humeur, clampf(float(e.get("humeur", 0.0)), -1.0, 1.0), dt, 1.0)
	_clair = _vers(_clair, clampf(float(e.get("clair", 0.0)), 0.0, 1.0), dt, 1.5)
	_mini = _vers(_mini, 0.0 if incarne else 1.0, dt, 2.0)
	var vif := 1.0 + 0.3 * _humeur

	# la voix : niveau fourni, ou parole plausible ; lissée pour qu'elle fasse respirer la forme sans jamais la faire clignoter
	var niveau := 0.0
	if e.has("voix"):
		niveau = clampf(float(e.voix), 0.0, 1.0)
	elif etat == "parle":
		var phrase := smoothstep(-0.25, 0.25, sin(_t * 1.15) + 0.55 + 0.3 * sin(_t * 0.43))
		niveau = clampf(0.5 + 0.28 * sin(_t * 5.3) + 0.22 * sin(_t * 8.7 + 1.0), 0.0, 1.0) * phrase
	_voix += (niveau - _voix) * (1.0 - exp(-dt / (0.09 if niveau > _voix else 0.28)))

	# de quel côté de l'objet : le côté libre (l'objet déporté à gauche du regard → elle se tient à droite), sans hésiter
	if e.has("cote"):
		_cote = -1.0 if float(e.cote) < 0.0 else 1.0
	else:
		var lat := (objet - tete).dot(droite)
		if lat > 0.12:
			_cote = -1.0
		elif lat < -0.12:
			_cote = 1.0

	# sa place de repos : à côté de l'objet, un peu au-dessus du regard, ni trop près ni trop loin
	var prof := maxf((objet - tete).dot(avant), 0.5)
	var r_eff := minf(r_objet, 0.5 * prof)      # un objet immense (le corps entier) ne la chasse pas hors du champ
	var p0 := objet + droite * _cote * (r_eff + 0.2)
	p0.y = tete.y + 0.07
	var vers := p0 - tete
	if vers.length() > 1.6:
		p0 = tete + vers.normalized() * 1.6
	var vers_tete := (tete - p0).normalized()
	var voulu := p0
	var duree := 0.8        # temps caractéristique du déplacement
	var v_max := 1.2
	var montre := etat == "montre"
	match etat:
		"parle":
			voulu = p0 + vers_tete * 0.14 - Vector3(0, 0.03, 0)
			duree = 0.7
		"ecoute":
			voulu = p0 + vers_tete * 0.26 - Vector3(0, 0.07, 0) - droite * _cote * 0.04
			duree = 0.6
		"reflechit":
			# elle se retire un peu, monte, et dérive très lentement sur un huit
			voulu = p0 - vers_tete * 0.05 + Vector3(0, 0.05, 0) + (droite * sin(_t * 0.31) * 0.03 + Vector3(0, sin(_t * 0.62) * 0.014, 0))
			duree = 1.1
		"montre":
			voulu = cible
			duree = 0.3
			v_max = 3.0
	if not montre:
		if _t_retour < 1.4:
			duree = 0.45
			v_max = 2.4
		if a_cible:
			# quelque chose arrive ou mérite un regard : elle s'incline vers ce point sans quitter sa place
			var dc := cible - voulu
			if dc.length() > 0.05:
				voulu += dc.normalized() * 0.08
		# elle flotte : un souffle lent, jamais immobile
		voulu += Vector3(sin(_t * 0.5) * 0.012, sin(_t * 0.83 + 1.0) * 0.014, cos(_t * 0.37) * 0.01) * vif
	voulu = _contraindre(voulu, tete, avant, droite, objet, r_eff, montre)

	var avant_maj := coeur
	if _a_poser:
		_a_poser = false
		avant_maj = voulu
		coeur = voulu
		vitesse = Vector3.ZERO
		_memo.fill(coeur)
		_reste = 0.0
		_normale = ((tete - coeur).normalized() * 0.5 + Vector3.UP * 0.6).normalized()
	elif dt > 0.0:
		coeur = _amortir(coeur, voulu, duree, v_max, dt)
		# garde-fou : quoi que fasse le visiteur, jamais à moins de 60 cm de son visage
		var ecart := coeur - tete
		if ecart.length() < D_MIN:
			var dir := ecart.normalized() if ecart.length() > 0.001 else avant
			coeur = tete + dir * D_MIN
			vitesse -= dir * minf(vitesse.dot(dir), 0.0)
	global_position = coeur
	posee = montre and coeur.distance_to(voulu) < 0.1

	# la mémoire du trajet (pour la traîne)
	_reste += dt
	while _reste >= PAS:
		_reste -= PAS
		for k in range(N_MEMO - 1, 0, -1):
			_memo[k] = _memo[k - 1]
		_memo[0] = coeur.lerp(avant_maj, clampf(_reste / maxf(dt, 1e-5), 0.0, 1.0))
	for k in N_TRACE:
		var age := DUREE_TRACE * float(k) / float(N_TRACE - 1)
		if age <= _reste:
			_trace[k] = coeur.lerp(_memo[0], age / maxf(_reste, 1e-5))
		else:
			var x := (age - _reste) / PAS
			var i0 := mini(int(x), N_MEMO - 2)
			_trace[k] = _memo[i0].lerp(_memo[i0 + 1], clampf(x - float(i0), 0.0, 1.0))

	# les poids des états (le shader les adoucit encore, et décale chaque grain)
	_p_ecoute = _vers(_p_ecoute, 1.0 if etat == "ecoute" else 0.0, dt, 2.2)
	_p_pense = _vers(_p_pense, 1.0 if etat == "reflechit" else 0.0, dt, 1.5)
	_p_parle = _vers(_p_parle, 1.0 if etat == "parle" else 0.0, dt, 2.2)
	_p_pose = _vers(_p_pose, 1.0 if posee else 0.0, dt, 4.5 if posee else 7.0)
	var allure := vitesse.length()
	_traine = _vers(_traine, lerpf(0.12, 0.6, smoothstep(0.25, 1.4, allure)), dt, 6.0)
	_vol = _vers(_vol, smoothstep(0.3, 1.5, allure), dt, 7.0)
	_micro = _vers(_micro, clampf(float(e.get("micro", 0.6)), 0.0, 1.0), dt, 5.0)

	# l'orientation du disque : sa normale se tourne plus ou moins vers le visiteur
	var vt := (tete - coeur).normalized()
	var n_voulue := vt * 0.55 + Vector3.UP * 0.65 + droite * sin(_t * 0.23) * 0.12
	match etat:
		"parle":
			n_voulue = vt + Vector3.UP * 0.22
		"ecoute":
			n_voulue = vt + Vector3.UP * 0.62 - droite * _cote * 0.2
		"reflechit":
			n_voulue = vt + Vector3.UP * 0.3 + droite * sin(_t * 0.4) * 0.3 + Vector3.UP * cos(_t * 0.27) * 0.2
		"montre":
			n_voulue = vt
	var elan_voulu := Vector3.ZERO
	if a_cible and not montre:
		var dc := cible - coeur
		if dc.length() > 0.05:
			n_voulue = n_voulue.normalized() * 0.6 + dc.normalized()
			elan_voulu = dc.normalized() * 0.07
	_elan = _elan.lerp(elan_voulu, 1.0 - exp(-dt * 2.5))
	_normale = _normale.lerp(n_voulue.normalized(), 1.0 - exp(-dt * 2.6)).normalized()
	_axe_x = _axe_x - _normale * _axe_x.dot(_normale)
	if _axe_x.length() < 0.05:
		_axe_x = droite - _normale * droite.dot(_normale)
	_axe_x = _axe_x.normalized()
	var base := Basis(_axe_x, _normale, _axe_x.cross(_normale))

	# les horloges propres (accumulées : changer d'allure ne fait jamais sauter la forme)
	var v_phase := 0.34
	match etat:
		"ecoute":
			v_phase = 0.09
		"reflechit":
			v_phase = 0.16
		"parle":
			v_phase = 0.46
		"montre":
			v_phase = 1.1 if posee else 0.5
	_v_phase = _vers(_v_phase, v_phase * vif, dt, 1.6)
	_phase = fmod(_phase + dt * _v_phase, TAU)
	_flux = fmod(_flux + dt * 0.4 * vif, TAU)
	_onde = fmod(_onde + dt * (2.6 + 3.2 * _voix), TAU)

	_nuage.visible = _vis > 0.0
	_voile.visible = _vis > 0.0 and _clair > 0.01
	if not _nuage.visible:
		return
	_mat.set_shader_parameter("trace", _trace)
	_mat.set_shader_parameter("base", base)
	_mat.set_shader_parameter("temps", fmod(_t, 3600.0))
	_mat.set_shader_parameter("phase", _phase)
	_mat.set_shader_parameter("flux", _flux)
	_mat.set_shader_parameter("onde", _onde)
	_mat.set_shader_parameter("p_ecoute", _p_ecoute)
	_mat.set_shader_parameter("p_pense", _p_pense)
	_mat.set_shader_parameter("p_parle", _p_parle)
	_mat.set_shader_parameter("p_pose", _p_pose)
	_mat.set_shader_parameter("mini", _mini)
	_mat.set_shader_parameter("voix", _voix)
	_mat.set_shader_parameter("humeur", _humeur)
	_mat.set_shader_parameter("vis", _vis)
	_mat.set_shader_parameter("traine", _traine)
	_mat.set_shader_parameter("elan", _elan)
	_mat.set_shader_parameter("clair", _clair)
	_mat.set_shader_parameter("vol", _vol)
	_mat.set_shader_parameter("micro", _micro)
	_mat.set_shader_parameter("source", Vector4(objet.x, objet.y, objet.z, r_eff))
	if _voile.visible:
		_voile.global_transform = Transform3D(Basis.IDENTITY, _trace[1])
		_mat_voile.set_shader_parameter("force", _clair * _vis)
		_mat_voile.set_shader_parameter("taille", lerpf(0.44, 0.15, _mini) * (1.0 + 0.25 * _p_pose))


func _vers(x: float, but: float, dt: float, allure: float) -> float:
	return x + (but - x) * (1.0 - exp(-dt * allure))


## Amortissement critique : elle part en douceur, arrive en douceur, et ne dépasse jamais `v_max`.
func _amortir(p: Vector3, but: Vector3, duree: float, v_max: float, dt: float) -> Vector3:
	var w := 2.0 / duree
	var x := w * dt
	var ex := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var ecart := p - but
	var maxi := v_max * duree
	if ecart.length() > maxi:
		ecart = ecart.normalized() * maxi
	var vise := p - ecart
	var tmp := (vitesse + w * ecart) * dt
	vitesse = (vitesse - w * tmp) * ex
	return vise + (ecart + tmp) * ex


## Les interdits : rester dans le champ (jamais derrière), ne pas passer devant l'objet regardé, garder ses distances.
func _contraindre(p: Vector3, tete: Vector3, avant: Vector3, droite: Vector3, objet: Vector3, r_objet: float, montre: bool) -> Vector3:
	# dans le champ : l'écart à l'axe du regard est borné (on tourne autour de la verticale de la tête)
	var rel := p - tete
	var lat := rel.dot(droite)
	var prof := rel.dot(avant)
	var az := atan2(lat, prof)
	var limite := AZIMUT_MAX + (0.5 if montre else 0.0)
	if absf(az) > limite:
		var h := maxf(Vector2(lat, prof).length(), 0.3)
		az = clampf(az, -limite, limite)
		p = tete + droite * sin(az) * h + avant * cos(az) * h + Vector3(0, rel.y, 0)
	if not montre:
		# jamais dans le cône qui va des yeux à l'objet (ni dans l'objet)
		var axe := objet - tete
		var long := axe.length()
		if long > 0.05:
			axe /= long
			var t := (p - tete).dot(axe)
			if t > 0.05 and t < long + r_objet:
				var w := (p - tete) - axe * t
				var marge := r_objet * minf(t / long, 1.0) + 0.14
				if w.length() < marge:
					var dw := w.normalized() if w.length() > 0.005 else droite * _cote
					p = tete + axe * t + dw * marge
	var e := p - tete
	if e.length() < D_VISEE:
		p = tete + (e.normalized() if e.length() > 0.001 else avant) * D_VISEE
	return p


# ───────── shaders ─────────

const SHADER := """
// Présence du guide : un seul nuage de points. Tout est calculé ici, en repère monde, à partir de quelques uniforms.
//   VERTEX  : position dans la forme de repos (petite galaxie de rayon 1 ; le plan du disque est xz)
//   CUSTOM0 : écart aléatoire (xyz) autour du fil du nœud ou de l'anneau, nature du grain (a) : 0 cœur, 1 bras, 2 halo, 3 astre
//   CUSTOM1 : quatre graines de hasard
//   UV      : x = place le long du nœud et de l'anneau (0 à 2π), y = rang du grain dans sa famille (0 à 1)
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled;

uniform vec3 trace[16];           // trajet du cœur : maintenant, puis de 40 ms en 40 ms dans le passé
uniform mat3 base = mat3(1.0);    // orientation : la colonne y est la normale du disque
uniform float temps = 0.0;
uniform float phase = 0.0;        // rotation du disque (accumulée)
uniform float flux = 0.0;         // écoulement le long du nœud (accumulé)
uniform float onde = 0.0;         // phase des ondes de la parole (accumulée)
uniform float p_ecoute = 0.0;
uniform float p_pense = 0.0;
uniform float p_parle = 0.0;
uniform float p_pose = 0.0;       // posée en anneau autour d'une cible
uniform float mini = 0.0;         // mode descriptif : il ne reste que le cœur
uniform float voix = 0.0;         // niveau de la voix, lissé
uniform float humeur = 0.0;
uniform float vis = 1.0;          // apparition
uniform float traine = 0.12;      // retard (secondes) des grains les plus lents
uniform vec3 elan = vec3(0.0);    // panache tendu vers un point (mètres)
uniform float micro = 0.6;        // niveau de la voix du visiteur pendant l'écoute (les rides s'animent)
uniform float vol = 0.0;          // en déplacement rapide : la forme se resserre en comète
uniform vec4 source = vec4(0.0);  // centre et rayon de l'objet étudié : la poussière lui est empruntée, puis rendue
uniform float clair = 0.0;        // pièce claire (réalité mixte) : grain un peu plus gros et plus franc
uniform float rayon = 0.08;
uniform float r_pose = 0.07;

const float F_REF = 792.0;        // pixels de référence par radian (comme points.gdshader)
const float GAIN = 1.5;
const vec3 BLANC = vec3(1.0, 0.93, 0.82);
const vec3 CLAIR = vec3(0.925, 0.91, 0.875);
const vec3 DORE = vec3(1.0, 0.82, 0.3);
const vec3 BLEU = vec3(0.22, 0.4, 1.0);
const vec3 CIEL = vec3(0.55, 0.75, 1.0);
const vec3 ROSE = vec3(1.0, 0.36, 0.5);
varying vec3 col;

vec3 tourne_y(vec3 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

float doux(float x) {
	x = clamp(x, 0.0, 1.0);
	return x * x * (3.0 - 2.0 * x);
}

void vertex() {
	vec4 g = CUSTOM1;
	vec3 ec = CUSTOM0.xyz;
	int k = int(CUSTOM0.a + 0.5);
	float u0 = UV.x;
	float rang = UV.y;
	float u = max(abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y * 0.5 / F_REF, 0.75);   // pixels réels par pixel de référence

	// chaque grain suit le cœur avec son propre retard : au repos une inertie douce, en vol une traîne de comète
	float w = k == 0 ? 0.1 * g.z : (k == 1 ? 0.12 + 0.6 * g.z : (k == 2 ? 0.25 + 0.75 * g.z * g.z : 0.4 + 0.4 * g.z));
	float age = clamp(w * traine / 0.6, 0.0, 1.0) * 15.0;
	int i0 = int(min(floor(age), 14.0));
	vec3 c = mix(trace[i0], trace[i0 + 1], age - float(i0));
	float file = smoothstep(0.3 * rayon, 1.8 * rayon, distance(c, trace[0]));

	// chaque grain change d'état à son heure
	float e_ec = doux(p_ecoute * 1.5 - g.z * 0.5);
	float e_pe = doux(p_pense * 1.6 - g.w * 0.6);
	float e_pa = doux(p_parle * 1.4 - g.z * 0.4);
	float e_po = doux(p_pose * 1.5 - g.x * 0.5);
	float apl = clamp(vis * 1.5 - g.y * 0.5, 0.0, 1.0);
	float ap = doux(apl);

	// taille apparente de la présence : comme le corps, elle ne montre que les grains que sa taille mérite
	float d0 = max(length((VIEW_MATRIX * vec4(trace[0], 1.0)).xyz), 0.05);
	float prn = rayon / d0 * F_REF;

	vec3 q = VERTEX;
	vec3 teinte;
	float l = 1.0;      // lumière
	float a = 1.0;      // présence du grain
	float px = 2.6;
	float perle = 0.0;
	float th = u0 + phase;
	float souffle = 1.0 + 0.05 * sin(temps * 2.9) + 0.1 * voix;       // l'anneau posé respire
	vec3 anneau = vec3(cos(th), 0.0, sin(th)) * (r_pose / rayon) * souffle;

	if (k == 0) {
		// le cœur : il frémit, gonfle avec la voix, se recueille quand elle réfléchit
		q += 0.03 * vec3(sin(temps * 1.3 + g.x * 40.0), sin(temps * 1.1 + g.y * 40.0), sin(temps * 0.9 + g.w * 40.0));
		q *= (1.0 + 0.75 * voix) * mix(1.0, 0.7, e_pe) * mix(1.0, 0.85, e_ec) * mix(1.0, 0.75, mini);
		q = mix(q, (anneau + ec * 0.045) * mix(1.0, 0.42, mini), e_po);      // en mode descriptif : un tout petit anneau
		teinte = mix(BLANC, DORE, 0.2 * g.x);
		l = 1.0 + 0.5 * voix + 0.08 * sin(temps * 1.9);
		l *= mix(1.0, 0.62 + 0.2 * sin(temps * 1.26), e_pe);
		a = 0.46 * mix(1.0, step(rang, 0.5), mini) * mix(1.0, 0.8, e_po);
		px = mix(4.0, 3.0, e_po * (1.0 - mini));      // des grains larges qui se fondent : une lueur, pas une matière
	} else if (k == 1) {
		float r = length(q.xz);
		vec3 b = tourne_y(q, phase);
		// écoute : le disque se creuse en coupe, des rides glissent du bord vers le cœur
		b.y += e_ec * 0.85 * pow(r, 1.2);
		float ride = 0.5 + 0.5 * sin(r * 9.0 + temps * (1.8 + 1.6 * micro));
		l *= mix(1.0, 0.4 + (0.9 + 0.8 * micro) * ride * ride, e_ec);
		// parole : des ondes partent du cœur, d'autant plus hautes que la voix porte
		float on = sin(r * 7.0 - onde);
		b.y += e_pa * voix * 0.08 * on * smoothstep(0.1, 0.5, r);
		b.xz *= 1.0 + e_pa * (0.14 * voix + (0.025 + 0.085 * voix) * sin(r * 9.0 - onde) * smoothstep(0.08, 0.4, r) / max(r, 0.1));
		l *= 1.0 + e_pa * voix * 0.7 * (0.5 + 0.5 * on);
		// réflexion : les bras se renouent en un fil qui coule le long d'un nœud de trèfle
		float s = u0 + flux;
		float cr = 2.0 + cos(3.0 * s);
		vec3 noeud = vec3(cr * cos(2.0 * s), 0.95 * sin(3.0 * s), cr * sin(2.0 * s)) * 0.37 + ec * (0.024 + 0.06 * g.x * g.x * g.x);
		float pe = max(0.0, sin(1.5 * u0 + 0.5 * flux + 2.0 * sin(flux)));     // perles de lumière, à contre-courant
		perle = pe * pe * pe * e_pe;
		b = mix(b, noeud, e_pe);
		l *= mix(1.0, 0.72 + 1.6 * pe * pe * pe, e_pe);
		// posée : un anneau autour de ce qu'elle désigne
		b = mix(b, anneau * (1.0 + 0.1 * (g.y - 0.5)) + ec * 0.03, e_po);
		q = b;
		teinte = mix(CIEL, CLAIR, 0.3 + 0.6 * g.x);
		teinte = mix(teinte, mix(BLANC, DORE, 0.5), smoothstep(0.55, 0.12, r) * 0.8);
		teinte = mix(teinte, DORE, step(0.87, g.y) * 0.9);
		teinte = mix(teinte, BLEU, step(g.y, 0.07) * 0.8);
		teinte = mix(teinte, ROSE, step(0.955, g.w) * 0.85);      // un peu du vivant, pris au corps
		// la densité : un grain pour ~14 px² ; au-delà, les derniers rangs se taisent
		float n_rev = 0.24 * prn * prn * mix(1.0, 0.55, max(e_po, e_pe * 0.3));
		a = 0.62 * clamp((n_rev - rang * 1300.0) / (0.3 * n_rev + 1.0), 0.0, 1.0);
		px = 2.5 + 0.5 * step(0.87, g.y);
	} else if (k == 2) {
		q = tourne_y(q, phase * 0.4 + 0.35 * sin(temps * 0.27 + g.x * 6.3));
		q += 0.06 * vec3(sin(temps * 0.5 + g.y * 30.0), sin(temps * 0.4 + g.z * 30.0), sin(temps * 0.6 + g.w * 30.0));
		q *= mix(1.0, 0.82, e_pe) * (1.0 + 0.12 * voix);
		q.y += e_ec * 0.7 * pow(length(q.xz), 1.2);
		teinte = mix(BLEU, CIEL, g.y);
		teinte = mix(teinte, CLAIR, step(0.8, g.x) * 0.6);
		float n_rev = 0.09 * prn * prn;
		a = 0.42 * mix(1.0, 0.6, e_ec) * mix(1.0, 0.45, e_po) * clamp((n_rev - rang * 420.0) / (0.3 * n_rev + 1.0), 0.0, 1.0);
		l = 0.8 + 0.2 * sin(temps * (1.0 + 2.0 * g.w) + g.x * 50.0);
		px = 2.4;
	} else {
		q = tourne_y(q, -phase * 0.3 + temps * 0.05 * (g.x - 0.5));
		q *= mix(1.0, 0.9, e_pe);
		q = mix(q, vec3(cos(th), 0.0, sin(th)) * (r_pose / rayon) * 1.32, e_po);
		teinte = mix(DORE, BLANC, g.x);
		teinte = mix(teinte, CIEL, step(0.7, g.y) * 0.7);
		l = 0.75 + 0.35 * sin(temps * (1.2 + 2.5 * g.w) + g.z * 60.0);
		a = 0.95;
		px = 3.8;
	}

	// nuances : l'état teinte à peine, l'humeur encore moins
	if (k != 0) {
		teinte = mix(teinte, CIEL, 0.3 * e_ec);
		teinte = mix(teinte, mix(BLEU, CIEL, 0.6), 0.42 * e_pe);
		teinte = mix(teinte, DORE, 0.85 * perle);
		teinte = mix(teinte, BLANC, 0.3 * e_pa * voix);
		teinte = mix(teinte, DORE, 0.6 * e_po);
	}
	teinte = mix(teinte, humeur > 0.0 ? DORE : BLEU, 0.2 * abs(humeur) * (k == 0 ? 0.5 : 1.0));

	// apparition : la poussière se rassemble ; mode descriptif : tout rentre dans le cœur
	if (k != 0) {
		q *= mix(1.0, 0.25, mini);
		a *= 1.0 - doux(mini * 1.4 - g.z * 0.4);
		// en vol, la forme se resserre et la traîne s'effile
		q *= mix(1.0, 0.12, file) * mix(1.0, 0.4, vol);
		l *= 1.0 + 0.7 * vol;
		a *= smoothstep(0.0, 0.25, apl);
	} else {
		a *= ap;        // le cœur, lui, ne vient de nulle part : il s'allume sur place
	}
	a *= mix(1.0, 0.8, file);

	vec3 monde = c + base * (q * rayon);
	if (k != 0 && ap < 1.0) {
		// elle n'a pas de poussière à elle : chaque grain monte du corps étudié en s'enroulant, et y retourne quand elle s'efface
		vec3 depart = source.xyz + ec * source.w * 0.4;
		vec3 chemin = mix(depart, monde, ap);
		float arc = sin(ap * 3.14159);
		chemin += base * (tourne_y(q, 2.5 * (1.0 - ap)) - q) * rayon * ap + vec3(0.0, 0.06, 0.0) * arc * (0.4 + g.x);
		monde = chemin;
	}
	if (k == 1) {
		float f = max(g.w - 0.7, 0.0) / 0.3;
		monde += elan * f * f * (1.0 - mini);
	}
	VERTEX = monde;
	float d = max(length((VIEW_MATRIX * vec4(monde, 1.0)).xyz), 0.02);
	a *= smoothstep(0.15, 0.32, d);      // rien de lumineux à moins de 15 cm des yeux
	float scint = 0.88 + 0.12 * sin(temps * (2.0 + 3.5 * g.x) + g.w * 80.0);
	POINT_SIZE = a > 0.003 ? px * u * (1.0 + 0.22 * clair) : 0.0;
	col = teinte * min(a * l * scint * GAIN * (1.0 + 0.35 * clair), 1.6);
}

void fragment() {
	vec2 q = POINT_COORD * 2.0 - 1.0;
	float k = 1.0 - dot(q, q);
	if (k <= 0.0) {
		discard;
	}
	vec3 c = col * smoothstep(0.0, 0.4, k);
	ALBEDO = pow(c, vec3(2.2));
}
"""

const SHADER_VOILE := """
// Voile de la réalité mixte : une ombre ronde et douce derrière la présence, pour que son grain additif se lise
// dans une pièce claire. Toujours face au regard.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled;

uniform float force = 0.0;
uniform float taille = 0.5;

void vertex() {
	VERTEX *= taille;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float k = max(0.0, 1.0 - dot(q, q));
	ALBEDO = vec3(0.0, 0.002, 0.008);
	ALPHA = force * 0.62 * k * k * (3.0 - 2.0 * k);
}
"""

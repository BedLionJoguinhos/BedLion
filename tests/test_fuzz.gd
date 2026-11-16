extends "res://tests/test_helper.gd"

const Caminhos := preload("res://scripts/caminhos.gd")
const Controles := preload("res://scripts/controles.gd")
const Linguas := preload("res://scripts/linguas.gd")
const LinguaNoChao := preload("res://scripts/lingua_no_chao.gd")
const CocoPombo := preload("res://scripts/coco_pombo.gd")
const Pistas := preload("res://scripts/pistas.gd")

const ESTADOS_LINGUA_VALIDOS := ["", "indo", "voltando", "puxando", "trazendo", "gancho"]

var fuzz_seed := 20261116
var fuzz_iterations := 200


func get_suite_name() -> String:
	return "Fuzzy Testing Determinístico (seed=%d, iterações=%d)" % [fuzz_seed, fuzz_iterations]


func run_tests() -> void:
	configurar_rng(fuzz_seed)
	fuzz_mapas_geometria()
	fuzz_caminhos_rotas()
	fuzz_controles_e_partida()
	await fuzz_arena_combate_headless()


func _ponto_aleatorio(margem_extra := 200.0) -> Vector2:
	return Vector2(rng.randf_range(-margem_extra, 1600.0 + margem_extra), rng.randf_range(-margem_extra, 900.0 + margem_extra))


func fuzz_mapas_geometria() -> void:
	var ok := true
	var passos := fuzz_iterations * 2

	for _i in passos:
		var ret := Rect2(rng.randf_range(-200.0, 1800.0), rng.randf_range(-200.0, 1100.0), rng.randf_range(0.0, 600.0), rng.randf_range(0.0, 600.0))
		var pt := _ponto_aleatorio(300.0)
		var folga := rng.randf_range(-40.0, 40.0)
		var c := Mapas.curva(ret)
		var dentro := Mapas.dentro_arredondado(ret, pt, folga)
		if not assert_quiet(is_finite(c) and c >= 0.0 and (dentro == true or dentro == false), "Mapas.curva/dentro_arredondado inválido"):
			ok = false
			break

		var mapa: Dictionary = Mapas.MAPAS[rng.randi() % Mapas.MAPAS.size()]
		var ponte := Mapas.ponte_em(mapa, pt)
		if ponte.has_area():
			if not assert_quiet(
				not Mapas.na_agua(mapa, pt), "Invariante violada em '%s': ponte_em() e na_agua() verdadeiros para %s" % [mapa["nome"], str(pt)]
			):
				ok = false
				break

		if Mapas.lugar_livre(mapa, pt, Mapas.PES.y + Mapas.MARGEM_BEIRADA + 1.0):
			var em_parede := false
			for parede in mapa.get("paredes", []):
				if (parede as Rect2).has_point(pt):
					em_parede = true
					break
			if not assert_quiet(
				not em_parede and not Mapas.afunda(mapa, pt), "Invariante violada em '%s': lugar_livre() aceitou parede ou água em %s" % [mapa["nome"], str(pt)]
			):
				ok = false
				break

	assert_true(ok, "Fuzz Mapas: %d pontos/retângulos aleatórios preservaram invariantes geométricas" % passos)


func fuzz_caminhos_rotas() -> void:
	var ok := true
	for _i in fuzz_iterations:
		var mapa: Dictionary = Mapas.MAPAS[rng.randi() % Mapas.MAPAS.size()]
		var de := _ponto_aleatorio(100.0)
		var ate := _ponto_aleatorio(100.0)
		var rota := Caminhos.caminho(mapa, de, ate)
		for k in rota.size():
			var wp := rota[k]
			if not assert_quiet(wp.is_finite(), "Waypoint não-finito em rota de '%s'" % mapa["nome"]):
				ok = false
				break
			if not assert_quiet(wp.x >= 0.0 and wp.x <= 1600.0 and wp.y >= 0.0 and wp.y <= 900.0, "Waypoint fora dos limites da arena: %s" % str(wp)):
				ok = false
				break
			if k < rota.size() - 1:
				for parede in mapa.get("paredes", []):
					if (parede as Rect2).has_point(wp):
						assert_quiet(false, "Waypoint intermediário %s dentro de parede em '%s'" % [str(wp), mapa["nome"]])
						ok = false
						break
		if not ok:
			break

	assert_true(ok, "Fuzz Caminhos: %d rotas A* aleatórias válidas e sem waypoints em paredes" % fuzz_iterations)


func fuzz_controles_e_partida() -> void:
	var ok := true
	var partida: Node = (Engine.get_main_loop() as SceneTree).root.get_node("Partida")
	var amostras := [
		"",
		"pad",
		"pad-1",
		"pad0",
		"pad7",
		"pad8",
		"pad999",
		"padabc",
		"teclado1",
		"teclado2",
		"teclado3",
		"bot",
		"😀",
		"a".repeat(256),
	]
	for _i in fuzz_iterations:
		var s: String
		if rng.randf() < 0.35:
			s = amostras[rng.randi() % amostras.size()]
		else:
			var tamanho := rng.randi_range(0, 16)
			s = ""
			for _c in tamanho:
				s += char(rng.randi_range(32, 126))
		var dev := Controles.dispositivo_de(s)
		var eh_p := Controles.eh_pad(s)
		if not assert_quiet(dev >= -1 and dev < Controles.MAX_PADS, "dispositivo_de fora do intervalo para '%s'" % s):
			ok = false
			break
		if not assert_quiet(eh_p == (dev >= 0), "eh_pad inconsistente com dispositivo_de para '%s'" % s):
			ok = false
			break
		Controles.vibrar(s, rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0), rng.randf_range(-1.0, 1.0))
		Controles.parar_vibracao(s)
		var idx: int = partida.indice_cor(s)
		if not assert_quiet(idx >= -1 and idx < partida.CORES.size(), "indice_cor fora do intervalo para '%s'" % s):
			ok = false
			break

	assert_true(ok, "Fuzz Controles/Partida: %d entradas aleatórias/malformadas tratadas com segurança" % fuzz_iterations)


func fuzz_arena_combate_headless() -> void:
	var ok := true
	var rodadas := maxi(2, mini(6, int(ceil(fuzz_iterations / 40.0))))
	var ticks_por_rodada := 120
	var upgrades_possiveis: Array = [Linguas.BASICA] + Linguas.UPGRADES

	for r in rodadas:
		var mapa: Dictionary = Mapas.MAPAS[r % Mapas.MAPAS.size()]
		var arena := criar_arena_teste(mapa)
		# Paredes externas da arena
		adicionar_parede(arena, Rect2(0, 0, 1600, 40))
		adicionar_parede(arena, Rect2(0, 860, 1600, 40))
		adicionar_parede(arena, Rect2(0, 0, 40, 900))
		adicionar_parede(arena, Rect2(1560, 0, 40, 900))

		var pistas := Pistas.new()
		pistas.mapa = mapa
		arena.add_child(pistas)

		var bots := ["dificil", "medio", "facil", "parado"]
		var camaleoes: Array = []
		for i in 4:
			var dif: String = bots[(i + r) % bots.size()]
			var c := criar_camaleao_teste(arena, mapa["inicios"][i], mapa, Color.from_hsv(i * 0.25, 0.8, 0.9), dif)
			c.lingua = upgrades_possiveis[rng.randi() % upgrades_possiveis.size()]
			camaleoes.append(c)

		# Spawna upgrades e cocôs extras para exercitar interações no fuzzing
		for pt in mapa["pontos_upgrade"].slice(0, 2):
			var up := LinguaNoChao.new()
			up.tipo = Linguas.UPGRADES[rng.randi() % Linguas.UPGRADES.size()]
			up.position = pt
			arena.add_child(up)
		var coco := CocoPombo.new()
		coco.position = mapa["inicios"][0]
		arena.add_child(coco)

		await avancar_fisica(2)

		for tick in ticks_por_rodada:
			# Injeta entradas aleatórias no camaleão "parado" (ator fuzzed)
			for c in camaleoes:
				if not is_instance_valid(c) or not c.vivo:
					continue
				if c.bot == "parado":
					_aplicar_input_fuzz(c)

			await avancar_fisica(1)

			# Valida invariantes estritas em todos os camaleões vivos
			for c in camaleoes:
				if not is_instance_valid(c) or not c.vivo:
					continue
				if not _validar_invariantes_camaleao(c, mapa["nome"], r, tick):
					ok = false
					break
			if not ok:
				break

		limpar_arena(arena)
		if not ok:
			break

	assert_true(ok, "Fuzz Arena Headless: %d partidas (%d ticks/partida) sem violações de invariantes" % [rodadas, ticks_por_rodada])


func _aplicar_input_fuzz(c: CharacterBody2D) -> void:
	var dir := Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
	if dir.length() > 0.05:
		c.direcao = dir.normalized()
		c.velocity = c.direcao * c.VELOCIDADE
		c.move_and_slide()
	var acao := rng.randi() % 10
	match acao:
		0, 1:
			c._golpear()
		2, 3:
			if c.get("_estado_lingua") == "":
				c._lancar_lingua()
			else:
				c.soltar_lingua(c.RECARGA_SOLTAR)
		4:
			c._controlar_invisibilidade(0.55, true, true)
		5:
			c._controlar_invisibilidade(0.55, false, true)
		6:
			c._controlar_invisibilidade(0.05, false, false)


func _validar_invariantes_camaleao(c: CharacterBody2D, nome_mapa: String, rodada: int, tick: int) -> bool:
	var ctx := "mapa=%s rodada=%d tick=%d" % [nome_mapa, rodada, tick]
	if not assert_quiet(c.position.is_finite() and c.velocity.is_finite(), "Posição/velocidade não-finita (%s)" % ctx):
		return false
	if not assert_quiet(c.get("_embalo").is_finite() and c.get("_ponta").is_finite(), "Embalo/ponta não-finita (%s)" % ctx):
		return false
	if not assert_quiet(
		c.position.x >= -5.0 and c.position.x <= 1605.0 and c.position.y >= -5.0 and c.position.y <= 905.0,
		"Camaleão escapou da arena: %s (%s)" % [str(c.position), ctx]
	):
		return false
	if not assert_quiet(c.invisivel == (not c.visible), "invisivel != not visible (%s)" % ctx):
		return false
	if not assert_quiet(Linguas.TIPOS.has(c.lingua), "Língua inválida '%s' (%s)" % [c.lingua, ctx]):
		return false
	if c.invisivel and not assert_quiet(c.lingua == Linguas.BASICA, "Camaleão invisível manteve poder '%s' (%s)" % [c.lingua, ctx]):
		return false
	if not assert_quiet(ESTADOS_LINGUA_VALIDOS.has(c.get("_estado_lingua")), "Estado de língua inválido '%s' (%s)" % [str(c.get("_estado_lingua")), ctx]):
		return false
	if not assert_quiet(c.puxado_por != c, "Camaleão puxando a si mesmo (%s)" % ctx):
		return false
	return true

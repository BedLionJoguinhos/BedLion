extends "res://tests/test_helper.gd"

const Armas := preload("res://scripts/armas.gd")
const ArmaNoChao := preload("res://scripts/arma_no_chao.gd")
const ArmaNaMao := preload("res://scripts/arma_na_mao.gd")
const Projetil := preload("res://scripts/projetil.gd")
const EfeitoTiro := preload("res://scripts/efeito_tiro.gd")
const EfeitoAtordoado := preload("res://scripts/efeito_atordoado.gd")
const Casca := preload("res://scripts/casca.gd")
const MainScript := preload("res://scripts/main.gd")


func get_suite_name() -> String:
	return "Testes de Armas e Atordoar (armas.gd, arma_na_mao.gd, projetil.gd)"


func run_tests() -> void:
	test_configuracao_e_sorteio()
	await test_golpe_atordoa_empurra_e_derruba_arma()
	await test_lingua_atordoa_ao_chegar()
	await test_invisivel_larga_arma_menos_eletrica()
	await test_pistola_mata_e_acaba_municao()
	await test_espingarda_leque_curto()
	await test_metralhadora_aquece_e_dispara_carga()
	await test_sniper_mira_e_parede()
	await test_laser_quica_e_acerta_quem_atirou()
	await test_bazuca_explosao_em_area()
	await test_bumerangue_ida_e_volta()
	await test_lingua_eletrica_tempo_e_lambida()
	await test_lingua_puxa_arma_e_morte_larga_arma()
	await test_spawn_de_armas_na_rodada()
	await test_bot_busca_arma_e_atira()
	await test_desenhos_e_efeitos()


## Dá uma arma nova (cheia) para o camaleão.
func _armar(c: CharacterBody2D, tipo: String) -> void:
	var no_chao := ArmaNoChao.new()
	no_chao.tipo = tipo
	c.mundo.add_child(no_chao)
	c.pegar_arma(no_chao)
	no_chao.free()


func _contar(arena: Node, script: Script) -> int:
	var n := 0
	for filho in arena.get_children():
		if filho.get_script() == script and not filho.is_queued_for_deletion():
			n += 1
	return n


func _contar_mortes(c: Node) -> Array:
	var mortes := [0]
	c.morreu.connect(func(_q: Node) -> void: mortes[0] += 1)
	return mortes


func test_configuracao_e_sorteio() -> void:
	for tipo in ["pistola", "espingarda", "metralhadora", "sniper", "laser", "bazuca", "bumerangue", "eletrica"]:
		assert_quiet(Armas.ARMAS.has(tipo), "Arsenal tem %s" % tipo)
	assert_eq(Armas.ARMAS.size(), 8, "Arsenal tem 8 armas (sem SMG)")
	assert_eq(Armas.armas_no_inicio(2), 1, "2 jogadores começam com 1 arma no mapa")
	assert_eq(Armas.armas_no_inicio(3), 1, "3 jogadores começam com 1 arma no mapa")
	assert_eq(Armas.armas_no_inicio(4), 2, "4 jogadores começam com 2 armas no mapa")
	assert_true(Armas.por_tempo("eletrica") and not Armas.por_tempo("pistola"), "Só a língua elétrica acaba por tempo")
	configurar_rng(42)
	var contagem := {}
	for _i in 3000:
		var tipo := Armas.sortear()
		contagem[tipo] = int(contagem.get(tipo, 0)) + 1
	assert_eq(contagem.size(), 8, "Sorteio pode sair qualquer arma")
	assert_true(int(contagem["pistola"]) > int(contagem["bazuca"]) * 2, "Arma forte (bazuca) sai bem menos que a pistola")


func test_golpe_atordoa_empurra_e_derruba_arma() -> void:
	var arena := criar_arena_teste()
	var a := criar_camaleao_teste(arena, Vector2(300, 300))
	var b := criar_camaleao_teste(arena, Vector2(370, 300))
	a.direcao = Vector2.RIGHT
	_armar(b, "pistola")
	b.arma.municao = 4
	var mortes := _contar_mortes(b)
	await avancar_fisica(1)
	a._golpear()
	await avancar_fisica(3)
	assert_eq(mortes[0], 0, "Golpe não mata")
	assert_true(b.atordoado(), "Golpe atordoa")
	assert_true(b.arma == null, "Golpe derruba a arma de quem levou")
	var no_chao: Array = arena.get_children().filter(func(n: Node) -> bool: return n is ArmaNoChao)
	assert_eq(no_chao.size(), 1, "Arma derrubada fica no chão")
	assert_eq(no_chao[0].municao, 4, "Arma no chão guarda a munição que sobrou")
	assert_true(b.position.x > 375.0, "Golpe empurra para longe de quem bateu")
	assert_false(b.pegar_arma(no_chao[0]), "Atordoado não pega arma")
	assert_eq(_contar(arena, EfeitoAtordoado), 1, "Passarinhos aparecem em cima de quem está atordoado")

	# Atordoado não age, e outro golpe não soma tempo
	var tempo_antes: float = b.get("_tempo_atordoado")
	assert_true(b.atordoar(Armas.TEMPO_ATORDOADO, Vector2.ZERO, true), "Golpe em quem já está tonto ainda conta")
	assert_true(b.get("_tempo_atordoado") <= tempo_antes, "Golpe em quem já está tonto não aumenta o tempo")

	# Acorda: fica imune por um tempo e os passarinhos somem
	b.set("_tempo_atordoado", 0.01)
	await avancar_fisica(2)
	await arvore().process_frame
	await arvore().process_frame
	assert_false(b.atordoado(), "Atordoamento acaba")
	assert_eq(_contar(arena, EfeitoAtordoado), 0, "Passarinhos somem quando acorda")
	assert_false(b.atordoar(Armas.TEMPO_ATORDOADO, Vector2.ZERO, false), "Logo depois de acordar fica imune")
	b.set("_imune_atordoar", 0.0)
	assert_true(b.atordoar(1.0, Vector2.ZERO, false), "Depois da imunidade pode ser atordoado de novo")
	limpar_arena(arena)


func test_lingua_atordoa_ao_chegar() -> void:
	var arena := criar_arena_teste()
	var atacante := criar_camaleao_teste(arena, Vector2(200, 300))
	var alvo := criar_camaleao_teste(arena, Vector2(420, 300))
	_armar(alvo, "pistola")
	await avancar_fisica(1)
	atacante.direcao = Vector2.RIGHT
	atacante._lancar_lingua()
	for _i in 90:
		await avancar_fisica(1)
		if alvo.atordoado():
			break
	assert_true(alvo.atordoado(), "Puxada da língua que chega até a boca atordoa")
	assert_true(alvo.arma != null, "Língua não derruba a arma")
	assert_true(alvo.vivo, "Língua não mata")
	limpar_arena(arena)


func test_invisivel_larga_arma_menos_eletrica() -> void:
	var arena := criar_arena_teste()
	var c := criar_camaleao_teste(arena, Vector2(300, 300))
	_armar(c, "bazuca")
	c._sumir()
	assert_true(c.arma == null, "Ficar invisível larga a arma")
	assert_eq(arena.get_children().filter(func(n: Node) -> bool: return n is ArmaNoChao).size(), 1, "Arma fica no chão")
	var outra := ArmaNoChao.new()
	outra.tipo = "pistola"
	arena.add_child(outra)
	assert_false(c.pegar_arma(outra), "Invisível não pega arma")

	var e := criar_camaleao_teste(arena, Vector2(600, 300))
	var alvo := criar_camaleao_teste(arena, Vector2(680, 300))
	var mortes := _contar_mortes(alvo)
	_armar(e, "eletrica")
	await avancar_fisica(1)
	e._sumir()
	assert_true(e.arma != null and e.invisivel, "Língua elétrica não cai ao ficar invisível")
	e.direcao = Vector2.RIGHT
	e._golpear()
	assert_false(e.invisivel, "Usar a língua elétrica faz aparecer")
	await avancar_fisica(1)
	assert_eq(mortes[0], 1, "Invisível mata de perto com a língua elétrica")
	limpar_arena(arena)


func test_pistola_mata_e_acaba_municao() -> void:
	var arena := criar_arena_teste()
	var c := criar_camaleao_teste(arena, Vector2(200, 300))
	var alvo := criar_camaleao_teste(arena, Vector2(500, 300))
	var mortes := _contar_mortes(alvo)
	_armar(c, "pistola")
	assert_eq(c.arma.municao, 5, "Pistola começa com 5 tiros")
	await avancar_fisica(1)
	c.direcao = Vector2.RIGHT
	c._golpear()
	assert_eq(c.arma.municao, 4, "Atirar gasta munição")
	assert_false(c.arma.pronta(), "Pistola tem recarga entre tiros")
	await avancar_fisica(25)
	assert_eq(mortes[0], 1, "Tiro de pistola mata com 1 acerto")
	for _i in 4:
		c.arma.set("_recarga", 0.0)
		c._golpear()
	await avancar_fisica(2)
	assert_true(c.arma == null, "Sem munição a arma some e fica desarmado")
	c._golpear()
	assert_true(c.get("_recarga_golpe") > 0.0, "Desarmado, o botão volta a ser golpe")
	await avancar_fisica(30)
	assert_eq(arvore().get_nodes_in_group("projeteis").size(), 0, "Balas somem no fim do alcance")
	limpar_arena(arena)


func test_espingarda_leque_curto() -> void:
	var arena := criar_arena_teste()
	var c := criar_camaleao_teste(arena, Vector2(200, 300))
	var perto := criar_camaleao_teste(arena, Vector2(330, 320))
	var longe := criar_camaleao_teste(arena, Vector2(700, 300))
	var mortes_perto := _contar_mortes(perto)
	var mortes_longe := _contar_mortes(longe)
	_armar(c, "espingarda")
	await avancar_fisica(1)
	c.direcao = Vector2.RIGHT
	c._golpear()
	assert_eq(arvore().get_nodes_in_group("projeteis").size(), Armas.ARMAS["espingarda"]["chumbos"], "Espingarda solta vários chumbos")
	await avancar_fisica(40)
	assert_eq(mortes_perto[0], 1, "Espingarda mata de perto")
	assert_eq(mortes_longe[0], 0, "Espingarda não alcança longe")
	limpar_arena(arena)


func test_metralhadora_aquece_e_dispara_carga() -> void:
	var arena := criar_arena_teste()
	var c := criar_camaleao_teste(arena, Vector2(200, 300))
	_armar(c, "metralhadora")
	var arma: ArmaNaMao = c.arma
	arma.set_physics_process(false)
	c.direcao = Vector2.UP
	c._golpear()
	assert_true(arma.ocupada(), "Metralhadora começa aquecendo")
	assert_eq(arvore().get_nodes_in_group("projeteis").size(), 0, "Nada sai durante o aquecimento")
	arma._physics_process(0.5)
	assert_eq(arma.municao, 10, "Ainda aquecendo na metade do tempo")
	arma._physics_process(0.55)
	arma._physics_process(0.01)
	assert_eq(arma.municao, 9, "Depois de aquecer sai o primeiro tiro")
	for _i in 12:
		arma._physics_process(0.16)
	assert_true(c.arma == null, "Depois da carga toda a metralhadora some")
	limpar_arena(arena)


func test_sniper_mira_e_parede() -> void:
	var arena := criar_arena_teste()
	var c := criar_camaleao_teste(arena, Vector2(100, 300))
	var alvo := criar_camaleao_teste(arena, Vector2(1400, 300))
	var protegido := criar_camaleao_teste(arena, Vector2(1400, 600))
	adicionar_parede(arena, Rect2(700, 560, 20, 80))
	var mortes := _contar_mortes(alvo)
	var mortes_protegido := _contar_mortes(protegido)
	_armar(c, "sniper")
	var arma: ArmaNaMao = c.arma
	arma.set_physics_process(false)
	await avancar_fisica(2)
	c.direcao = Vector2.RIGHT
	c._golpear()
	arma._physics_process(0.3)
	assert_eq(mortes[0], 0, "Sniper espera a mira laser antes de atirar")
	arma.queue_redraw()
	await arvore().process_frame
	arma._physics_process(0.3)
	assert_eq(mortes[0], 1, "Sniper acerta longe, em linha reta")
	c.position = Vector2(100, 600)
	arma.set("_recarga", 0.0)
	c._golpear()
	arma._physics_process(0.6)
	assert_eq(mortes_protegido[0], 0, "Parede segura o tiro da sniper")
	limpar_arena(arena)


func test_laser_quica_e_acerta_quem_atirou() -> void:
	var arena := criar_arena_teste()
	var c := criar_camaleao_teste(arena, Vector2(300, 300))
	adicionar_parede(arena, Rect2(500, 200, 20, 200))
	var mortes := _contar_mortes(c)
	_armar(c, "laser")
	await avancar_fisica(2)
	c.direcao = Vector2.RIGHT
	c._golpear()
	await avancar_fisica(3)
	assert_eq(mortes[0], 0, "Laser não acerta quem atirou antes de quicar")
	await avancar_fisica(40)
	assert_eq(mortes[0], 1, "Laser quica na parede e acerta quem atirou")
	limpar_arena(arena)


func test_bazuca_explosao_em_area() -> void:
	var arena := criar_arena_teste()
	var c := criar_camaleao_teste(arena, Vector2(200, 300))
	var alvo := criar_camaleao_teste(arena, Vector2(500, 300))
	var vizinho := criar_camaleao_teste(arena, Vector2(540, 360))
	var casca := Casca.new()
	casca.position = Vector2(520, 230)
	arena.add_child(casca)
	var mortes := _contar_mortes(alvo)
	var mortes_vizinho := _contar_mortes(vizinho)
	var mortes_dono := _contar_mortes(c)
	_armar(c, "bazuca")
	await avancar_fisica(1)
	c.direcao = Vector2.RIGHT
	c._golpear()
	await avancar_fisica(40)
	assert_eq(mortes[0] + mortes_vizinho[0], 2, "Explosão da bazuca pega todo mundo em volta")
	assert_eq(mortes_dono[0], 0, "Quem atirou longe não é pego")
	assert_false(is_instance_valid(casca) and not casca.is_queued_for_deletion(), "Explosão estoura a pele velha")
	assert_eq(_contar(arena, EfeitoTiro), 1, "Explosão aparece na tela")

	# Atirar colado na parede explode em quem atirou
	adicionar_parede(arena, Rect2(260, 250, 20, 100))
	await avancar_fisica(2)
	c.arma.set("_recarga", 0.0)
	c._golpear()
	await avancar_fisica(10)
	assert_eq(mortes_dono[0], 1, "Bazuca na parede colada mata quem atirou")
	limpar_arena(arena)


func test_bumerangue_ida_e_volta() -> void:
	var arena := criar_arena_teste()
	var c := criar_camaleao_teste(arena, Vector2(200, 300))
	var alvo := criar_camaleao_teste(arena, Vector2(450, 300))
	var mortes := _contar_mortes(alvo)
	var mortes_dono := _contar_mortes(c)
	_armar(c, "bumerangue")
	await avancar_fisica(1)
	c.direcao = Vector2.RIGHT
	c._golpear()
	var tiro: Node = arvore().get_nodes_in_group("projeteis")[0]
	c.arma.set("_recarga", 0.0)
	assert_false(c.arma.pronta(), "Só joga outro bumerangue quando o anterior voltar")
	for _i in 60:
		await avancar_fisica(1)
		if tiro.voltando():
			break
	assert_eq(mortes[0], 1, "Bumerangue mata na ida")
	assert_true(tiro.voltando(), "Bumerangue volta no fim do alcance")
	var na_volta := criar_camaleao_teste(arena, (tiro.position + c.position) / 2.0 + Vector2(0, 10))
	var mortes_volta := _contar_mortes(na_volta)
	await avancar_fisica(40)
	assert_eq(mortes_volta[0], 1, "Bumerangue mata na volta")
	assert_eq(mortes_dono[0], 0, "Bumerangue nunca acerta quem jogou")
	assert_false(is_instance_valid(tiro), "Bumerangue some ao voltar para a mão")
	assert_eq(c.arma.municao, 2, "Cada arremesso gasta um")
	limpar_arena(arena)


func test_lingua_eletrica_tempo_e_lambida() -> void:
	var arena := criar_arena_teste()
	var c := criar_camaleao_teste(arena, Vector2(300, 300))
	var perto := criar_camaleao_teste(arena, Vector2(400, 300))
	var longe := criar_camaleao_teste(arena, Vector2(520, 300))
	var mortes_perto := _contar_mortes(perto)
	var mortes_longe := _contar_mortes(longe)
	_armar(c, "eletrica")
	assert_approx(c.arma.tempo_restante, 8.0, 0.01, "Língua elétrica dura 8 s")
	await avancar_fisica(1)
	c.direcao = Vector2.RIGHT
	c._golpear()
	await avancar_fisica(1)
	assert_eq(mortes_perto[0], 1, "Lambida elétrica mata de perto")
	assert_eq(mortes_longe[0], 0, "Lambida elétrica não alcança longe")
	c.arma.tempo_restante = 0.05
	await avancar_fisica(6)
	assert_true(c.arma == null, "Língua elétrica acaba depois do tempo")
	limpar_arena(arena)


func test_lingua_puxa_arma_e_morte_larga_arma() -> void:
	var arena := criar_arena_teste()
	var c := criar_camaleao_teste(arena, Vector2(200, 300))
	var no_chao := ArmaNoChao.new()
	no_chao.tipo = "laser"
	no_chao.position = Vector2(420, 300)
	arena.add_child(no_chao)
	await avancar_fisica(1)
	c.direcao = Vector2.RIGHT
	c._lancar_lingua()
	for _i in 90:
		await avancar_fisica(1)
		if c.arma != null:
			break
	assert_true(c.arma != null and c.arma.tipo == "laser", "Língua puxa uma arma do chão e pega")

	# Já armado: a que vem pela língua cai aos pés
	var outra := ArmaNoChao.new()
	outra.tipo = "pistola"
	outra.position = Vector2(420, 300)
	arena.add_child(outra)
	assert_false(c.pegar_arma(outra), "Armado não pega outra arma")

	# Na água a arma afunda
	outra.afundar()
	outra._physics_process(ArmaNoChao.TEMPO_AFUNDAR + 0.1)
	assert_true(outra.is_queued_for_deletion(), "Arma na água afunda e some")

	c.morrer()
	var largadas: Array = arena.get_children().filter(func(n: Node) -> bool: return n is ArmaNoChao and n.tipo == "laser")
	assert_eq(largadas.size(), 1, "Quem morre larga a arma no chão")
	limpar_arena(arena)


func test_spawn_de_armas_na_rodada() -> void:
	var main: Node = MainScript.new()
	arvore().root.add_child(main)
	await arvore().process_frame
	var rodada: Node = main.get("_rodada")
	var armas := func() -> int: return rodada.get_children().filter(func(n: Node) -> bool: return n is ArmaNoChao).size()
	var jogadores: int = main.get("_jogadores").size()
	assert_eq(armas.call(), Armas.armas_no_inicio(jogadores), "Rodada começa com poucas armas no mapa")
	for _i in 5:
		main._spawnar_arma()
	assert_eq(armas.call(), Armas.MAX_ARMAS_NO_CHAO, "Armas que aparecem depois respeitam MAX_ARMAS_NO_CHAO")
	var livres: Array = main._pontos_livres()
	assert_true(livres.size() < main.get("_mapa")["pontos_upgrade"].size(), "Ponto com arma conta como ocupado")
	main.set("_rodada_acabou", true)
	main._spawnar_arma()
	assert_eq(armas.call(), Armas.MAX_ARMAS_NO_CHAO, "Rodada acabada não cria arma")
	main.free()


func test_desenhos_e_efeitos() -> void:
	var arena := criar_arena_teste()
	var x := 100.0
	for tipo: String in Armas.ARMAS:
		var no_chao := ArmaNoChao.new()
		no_chao.tipo = tipo
		no_chao.position = Vector2(x, 100)
		arena.add_child(no_chao)
		var c := criar_camaleao_teste(arena, Vector2(x, 400))
		c.direcao = Vector2.LEFT if tipo == "laser" else Vector2.RIGHT
		_armar(c, tipo)
		x += 150.0
	for tipo in ["bala", "laser", "foguete", "bumerangue"]:
		var tiro := Projetil.new()
		tiro.tipo = tipo
		tiro.position = Vector2(800, 700)
		tiro.alcance = 50.0
		tiro.velocidade = 10.0
		arena.add_child(tiro)
	for tipo in ["rastro", "explosao", "choque"]:
		var efeito := EfeitoTiro.new()
		efeito.tipo = tipo
		efeito.ate = Vector2(300, 300)
		arena.add_child(efeito)
	await arvore().process_frame
	await arvore().process_frame
	assert_true(arena.get_child_count() > 20, "Armas, tiros e efeitos se desenham sem erro")
	for filho in arena.get_children():
		if filho is EfeitoTiro:
			filho._process(1.0)
	assert_eq(_contar(arena, EfeitoTiro), 0, "Efeitos de tiro somem depois do tempo")
	limpar_arena(arena)


func test_bot_busca_arma_e_atira() -> void:
	configurar_rng(7)
	var arena := criar_arena_teste()
	var c := criar_camaleao_teste(arena, Vector2(300, 300), {}, Color.GREEN, "dificil")
	c.set_physics_process(false)
	var cerebro: Object = c.get("_cerebro")
	var longe := ArmaNoChao.new()
	longe.tipo = "pistola"
	longe.position = Vector2(1000, 300)
	arena.add_child(longe)
	await avancar_fisica(1)
	cerebro._buscar_arma(1.0)
	assert_eq(cerebro.get("_destino"), longe.position, "Bot desarmado anda até a arma longe")
	longe.position = Vector2(500, 300)
	cerebro._buscar_arma(1.0)
	assert_true(cerebro.get("_mira_lingua") != Vector2.ZERO, "Bot desarmado puxa com a língua a arma perto")
	longe.free()

	# Armado: não some (sumir largaria a arma) e atira em quem está ao alcance
	_armar(c, "pistola")
	assert_false(cerebro._talvez_sumir(1.0), "Bot armado não fica invisível")
	var alvo := criar_camaleao_teste(arena, Vector2(600, 300))
	await avancar_fisica(1)
	assert_true(cerebro._alvo_do_tiro() != Vector2.INF, "Bot armado acha alvo ao alcance da arma")
	var atirou := false
	for _i in 30:
		if cerebro.agir(0.05)["golpe"]:
			atirou = true
			break
	assert_true(atirou, "Bot armado atira no alvo depois de reagir")

	# Posição: longe chega perto, perto demais da bazuca se afasta, no alcance anda de lado
	cerebro._posicionar_para_atirar(Vector2(1500, 300), 1200.0, false)
	assert_eq(cerebro.get("_destino"), Vector2(1500, 300), "Bot armado chega até o alcance da arma")
	c.arma.tipo = "bazuca"
	cerebro._posicionar_para_atirar(Vector2(380, 300), 80.0, false)
	assert_true(cerebro.get("_destino").x < 300.0, "Bot com bazuca se afasta de alvo perto demais")
	alvo.position = Vector2(360, 300)
	assert_eq(cerebro._alvo_do_tiro(), Vector2.INF, "Bot não atira de bazuca em alvo colado")
	cerebro._posicionar_para_atirar(Vector2(700, 300), 400.0, false)
	assert_true(absf(cerebro.get("_destino").y - 300.0) > 50.0, "Bot armado no alcance anda de lado")
	cerebro._pensar()
	limpar_arena(arena)

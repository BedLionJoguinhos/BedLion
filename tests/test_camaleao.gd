extends "res://tests/test_helper.gd"

const Linguas := preload("res://scripts/linguas.gd")
const LinguaNoChao := preload("res://scripts/lingua_no_chao.gd")
const Grude := preload("res://scripts/grude.gd")
const Casca := preload("res://scripts/casca.gd")
const Pegada := preload("res://scripts/pegada.gd")


func get_suite_name() -> String:
	return "Testes de Mecânicas do Camaleão (scripts/camaleao.gd)"


func run_tests() -> void:
	await test_invisibilidade_carga_recarga_e_largar_poder()
	await test_poder_muda_cria_casca()
	await test_golpe_alcance_parede_e_empate()
	await test_lingua_puxar_soltar_e_cortar()
	await test_lingua_trazer_item_e_cair_na_agua()
	await test_poder_gancho_e_embalo()
	await test_poder_grude_e_imunidade()
	await test_pes_sujos_pegadas_olho_e_morte_agua()
	await test_recolher_lingua_e_mira()


func test_invisibilidade_carga_recarga_e_largar_poder() -> void:
	var arena := criar_arena_teste()
	var c := criar_camaleao_teste(arena, Vector2(300, 300))
	c.lingua = "olho"

	# Carrega parcialmente e solta antes do tempo -> cancela e restaura opacidade
	c._controlar_invisibilidade(0.4, true, true)
	assert_true(c.get("_carga_invisivel") > 0.0 and not c.invisivel, "Carregamento parcial não deixa invisível")
	c._controlar_invisibilidade(0.1, false, false)
	assert_approx(c.get("_carga_invisivel"), 0.0, 0.001, "Soltar o botão antes de completar zera a carga")
	assert_approx(c.modulate.a, 1.0, 0.001, "Cancelar invisibilidade restaura opacidade total")

	# Completa a carga -> fica invisível e larga o poder no chão
	c._controlar_invisibilidade(0.6, true, true)
	c._controlar_invisibilidade(0.5, false, true)
	assert_true(c.invisivel and not c.visible, "Segurar por TEMPO_PARA_SUMIR ativa invisibilidade")
	assert_eq(c.lingua, Linguas.BASICA, "Ficar invisível retorna língua para básica")
	var drops := arvore().get_nodes_in_group("upgrades_no_chao")
	var achou_olho: bool = drops.any(func(d): return d.get_parent() == arena and d.tipo == "olho")
	assert_true(achou_olho, "Ficar invisível larga o upgrade de língua no chão")

	# Toque enquanto invisível revela e ativa recarga
	c._controlar_invisibilidade(0.05, true, true)
	assert_false(c.invisivel, "Toque enquanto invisível faz aparecer")
	assert_true(c.visible, "Ao aparecer, visible volta a true")
	assert_true(c.get("_recarga_invisibilidade") > 0.0, "Aparecer inicia recarga de invisibilidade")

	# Durante recarga não inicia nova carga
	c._controlar_invisibilidade(0.1, true, true)
	assert_approx(c.get("_carga_invisivel"), 0.0, 0.001, "Durante recarga não inicia carregamento de invisibilidade")

	limpar_arena(arena)


func test_poder_muda_cria_casca() -> void:
	var arena := criar_arena_teste()
	var c := criar_camaleao_teste(arena, Vector2(400, 400))
	c.lingua = "muda"
	var drops_antes := arvore().get_nodes_in_group("upgrades_no_chao").size()

	c._controlar_invisibilidade(0.016, true, false)
	await avancar_fisica(1)
	assert_true(c.invisivel, "Poder 'muda' deixa invisível com um único toque")
	assert_eq(c.lingua, Linguas.BASICA, "Poder 'muda' é consumido ao trocar de pele")
	assert_eq(arvore().get_nodes_in_group("upgrades_no_chao").size(), drops_antes, "Poder 'muda' não larga bolha de upgrade no chão")
	var cascas := arvore().get_nodes_in_group("cascas")
	assert_true(cascas.any(func(k): return k.get_parent() == arena), "Poder 'muda' instancia Casca no mundo")

	limpar_arena(arena)


func test_golpe_alcance_parede_e_empate() -> void:
	var arena := criar_arena_teste()
	var a := criar_camaleao_teste(arena, Vector2(300, 300))
	var b := criar_camaleao_teste(arena, Vector2(380, 300))
	a.direcao = Vector2.RIGHT
	await avancar_fisica(2)

	assert_approx(Camaleao.ANGULO_GOLPE, deg_to_rad(60.0), 0.001, "ANGULO_GOLPE reduzido para 60°")
	assert_true(a._alcanca_golpe(b.position), "Golpe alcança inimigo na frente dentro de ALCANCE_GOLPE")
	b.position = a.position + Vector2.from_angle(deg_to_rad(50.0)) * 80.0
	assert_true(a._alcanca_golpe(b.position), "Golpe alcança inimigo a 50° dentro de 60°")
	b.position = a.position + Vector2.from_angle(deg_to_rad(70.0)) * 80.0
	assert_false(a._alcanca_golpe(b.position), "Golpe não alcança inimigo a 70° fora do cone de 60°")
	b.position = Vector2(380, 300)
	a.direcao = Vector2.LEFT
	assert_false(a._alcanca_golpe(b.position), "Golpe não acerta inimigo atrás fora de DISTANCIA_COLADO")

	b.position = Vector2(340, 300)  # distância 40 <= DISTANCIA_COLADO (50)
	assert_true(a._alcanca_golpe(b.position), "Golpe acerta em 360° quando colado (<= DISTANCIA_COLADO)")

	# Parede bloqueia o golpe
	b.position = Vector2(385, 300)
	a.direcao = Vector2.RIGHT
	adicionar_parede(arena, Rect2(340, 260, 20, 80))
	await avancar_fisica(2)
	assert_false(a._alcanca_golpe(b.position), "Parede entre atacante e alvo bloqueia o golpe")
	limpar_arena(arena)

	# Empate simultâneo no mesmo quadro + invisível golpeando aparece
	var arena2 := criar_arena_teste()
	var p1 := criar_camaleao_teste(arena2, Vector2(400, 300))
	var p2 := criar_camaleao_teste(arena2, Vector2(460, 300))
	p1.direcao = Vector2.RIGHT
	p2.direcao = Vector2.LEFT
	p1.invisivel = true
	p1.visible = false
	await avancar_fisica(2)

	var mortes := [0, 0]
	p1.morreu.connect(func(_q): mortes[0] += 1)
	p2.morreu.connect(func(_q): mortes[1] += 1)
	p1._golpear()
	assert_false(p1.invisivel, "Golpear enquanto invisível revela o atacante")
	p2._golpear()
	await avancar_fisica(2)
	assert_true(mortes[0] == 0 and mortes[1] == 0, "Golpe não mata ninguém (só atordoa)")
	assert_true(p1.atordoado() and p2.atordoado(), "Golpes simultâneos no mesmo quadro atordoam os dois (justo)")

	limpar_arena(arena2)


func test_lingua_puxar_soltar_e_cortar() -> void:
	var arena := criar_arena_teste()
	var atacante := criar_camaleao_teste(arena, Vector2(200, 300))
	var alvo := criar_camaleao_teste(arena, Vector2(420, 300))
	alvo.invisivel = true
	alvo.visible = false
	atacante.direcao = Vector2.RIGHT
	await avancar_fisica(2)

	# Língua bloqueada quando invisível
	atacante.invisivel = true
	atacante._lancar_lingua()
	assert_eq(atacante.get("_estado_lingua"), "", "Camaleão invisível não lança língua")
	atacante.invisivel = false

	# Lança e acerta alvo invisível -> revela e puxa
	atacante._lancar_lingua()
	assert_eq(atacante.get("_estado_lingua"), "indo", "Lançamento muda estado da língua para 'indo'")
	for _i in 20:
		atacante._mover_lingua(0.016)
		if atacante.get("_estado_lingua") == "puxando":
			break
	assert_eq(atacante.get("_estado_lingua"), "puxando", "Língua que acerta inimigo entra em 'puxando'")
	assert_eq(alvo.puxado_por, atacante, "Alvo registra puxado_por = atacante")
	assert_false(alvo.invisivel, "Puxar alvo invisível revela ele")

	# Antes de TEMPO_ATE_SE_SOLTAR, alvo não consegue se soltar
	alvo._ser_arrastado(0.05, true, false)
	assert_eq(alvo.puxado_por, atacante, "Alvo não se solta antes de TEMPO_ATE_SE_SOLTAR")

	# Terceiro camaleão corta a língua esticada
	var terceiro := criar_camaleao_teste(arena, (atacante.position + alvo.position) * 0.5)
	await avancar_fisica(1)
	assert_true(atacante._alguem_cortou(alvo.position), "Terceiro camaleão no segmento corta a língua")
	atacante._mover_lingua(0.016)
	assert_eq(atacante.get("_estado_lingua"), "", "Cortar língua recolhe imediatamente")
	assert_eq(alvo.puxado_por, null, "Cortar língua libera puxado_por do alvo")
	assert_approx(atacante.get("_recarga_lingua"), Camaleao.RECARGA_SOLTAR, 0.01, "Cortar aplica RECARGA_SOLTAR")

	# Alvo consegue se soltar após TEMPO_ATE_SE_SOLTAR
	atacante.set("_recarga_lingua", 0.0)
	terceiro.position = Vector2(900, 900)
	atacante._comecar_puxada(alvo)
	alvo._ser_arrastado(Camaleao.TEMPO_ATE_SE_SOLTAR + 0.05, true, false)
	assert_eq(alvo.puxado_por, null, "Alvo consegue se soltar após TEMPO_ATE_SE_SOLTAR")

	limpar_arena(arena)


func test_lingua_trazer_item_e_cair_na_agua() -> void:
	var mapa_lago: Dictionary = Mapas.MAPAS[2]  # Lago (água em Rect2(500, 230, 600, 440))
	var arena := criar_arena_teste()
	var c := criar_camaleao_teste(arena, Vector2(440, 300), mapa_lago)
	c.direcao = Vector2.RIGHT
	var item := LinguaNoChao.new()
	item.tipo = "olho"
	item.position = Vector2(620, 300)  # em cima da água do lago
	arena.add_child(item)
	await avancar_fisica(2)

	c._lancar_lingua()
	for _i in 25:
		c._mover_lingua(0.016)
		if c.get("_estado_lingua") == "trazendo":
			break
	assert_eq(c.get("_estado_lingua"), "trazendo", "Língua pega upgrade no chão e entra em 'trazendo'")
	assert_true(item.na_lingua, "Upgrade marca na_lingua = true enquanto é trazido")

	# Soltar língua enquanto item está sobre a água faz o item afundar
	c.soltar_lingua(Camaleao.RECARGA_SOLTAR)
	assert_false(item.na_lingua, "Soltar língua limpa item.na_lingua")
	assert_true(item.get("_afundando") >= 0.0, "Upgrade solto sobre a água começa a afundar")

	# Trazendo até a boca equipa o upgrade
	var item2 := LinguaNoChao.new()
	item2.tipo = "grude"
	item2.position = Vector2(490, 300)
	arena.add_child(item2)
	await avancar_fisica(1)
	c.set("_recarga_lingua", 0.0)
	c._lancar_lingua()
	for _i in 30:
		c._mover_lingua(0.016)
		if c.lingua == "grude":
			break
	assert_eq(c.lingua, "grude", "Trazer upgrade até a boca equipa o poder")

	limpar_arena(arena)


func test_poder_gancho_e_embalo() -> void:
	var arena := criar_arena_teste()
	adicionar_parede(arena, Rect2(520, 200, 60, 200))
	var c := criar_camaleao_teste(arena, Vector2(300, 300))
	c.lingua = "gancho"
	c.direcao = Vector2.RIGHT
	await avancar_fisica(2)

	c._lancar_lingua()
	for _i in 30:
		c._mover_lingua(0.016)
		if c.get("_estado_lingua") == "gancho":
			break
	assert_eq(c.get("_estado_lingua"), "gancho", "Gancho que atinge parede entra no estado 'gancho'")
	assert_true(c._voando(), "Durante gancho _voando() retorna true")

	# Simula velocidade de voo e solta manualmente (como soltar botão no meio do voo)
	c.velocity = Vector2(950, 0)
	c.set("_embalo", c.velocity)
	c.soltar_lingua(Camaleao.RECARGA_LINGUA)
	assert_true(c._voando(), "Com embalo > VELOCIDADE, _voando() continua true (passa sobre água)")

	limpar_arena(arena)


func test_poder_grude_e_imunidade() -> void:
	var arena := criar_arena_teste()
	var dono := criar_camaleao_teste(arena, Vector2(200, 300))
	var vitima := criar_camaleao_teste(arena, Vector2(350, 300))
	dono.lingua = "grude"
	dono.set("_dados_lingua", Linguas.TIPOS["grude"])

	# Gera dois rastros de grude + terceiro deve liberar o mais antigo (max_grudes = 2)
	dono._soltar_grude(Vector2(450, 300))
	dono._soltar_grude(Vector2(450, 360))
	await avancar_fisica(1)
	dono._soltar_grude(Vector2(450, 420))
	await avancar_fisica(1)
	var grudes_vivos := arvore().get_nodes_in_group("grudes").filter(func(g): return is_instance_valid(g) and not g.is_queued_for_deletion() and g.dono == dono)
	assert_eq(grudes_vivos.size(), 2, "Poder 'grude' limita quantidade simultânea a max_grudes (2)")

	# Vitima invisível pisando em grude aparece e fica presa; depois ganha imunidade temporária
	vitima.invisivel = true
	vitima.visible = false
	assert_true(vitima.grudar(Grude.TEMPO_PRESO), "grudar() prende camaleão elegível")
	assert_false(vitima.invisivel, "grudar() revela camaleão invisível")
	assert_true(vitima.get("_tempo_grudado") > 0.0, "grudar() define _tempo_grudado")

	vitima.set("_tempo_grudado", 0.0)
	vitima.set("_imune_grude", Camaleao.IMUNE_GRUDE)
	assert_false(vitima.grudar(Grude.TEMPO_PRESO), "Durante IMUNE_GRUDE não gruda novamente")

	limpar_arena(arena)


func test_pes_sujos_pegadas_olho_e_morte_agua() -> void:
	var mapa_lago: Dictionary = Mapas.MAPAS[2]
	var arena := criar_arena_teste()
	var c := criar_camaleao_teste(arena, Vector2(200, 300), mapa_lago)
	var invis := criar_camaleao_teste(arena, Vector2(320, 300), mapa_lago)
	invis.invisivel = true
	invis.visible = false
	c.lingua = "olho"
	await avancar_fisica(1)

	assert_true(c._enxerga(invis), "Poder 'olho' enxerga camaleão invisível dentro de raio_olho")
	invis.position = Vector2(700, 300)
	assert_false(c._enxerga(invis), "Poder 'olho' não enxerga camaleão fora de raio_olho")

	# Pés sujos deixam pegadas ao se mover fora de poça
	c.sujar_pes(3.0, Pegada.COR)
	c.velocity = Vector2(300, 0)
	c.move_and_slide()
	c._deixar_pegadas(0.1)
	var pegadas := arvore().get_nodes_in_group("pegadas")
	var tem_pegada := arena.get_children().any(func(n): return n is Pegada)
	assert_true(tem_pegada, "Camaleão com pés sujos andando cria nó Pegada no mundo")
	assert_true(pegadas.size() >= 0, "Grupo pegadas acessível com segurança")

	# Morte por água emite sinal uma única vez e é idempotente
	var contagem_morte := [0]
	c.morreu.connect(func(_quem): contagem_morte[0] += 1)
	c._morrer(true)
	c._morrer(true)
	assert_false(c.vivo, "_morrer() marca vivo = false")
	await avancar_fisica(1)
	assert_eq(contagem_morte[0], 1, "Sinal 'morreu' é emitido exatamente uma vez (idempotente)")

	limpar_arena(arena)


func test_recolher_lingua_e_mira() -> void:
	var arena := criar_arena_teste()
	var c := criar_camaleao_teste(arena, Vector2(300, 300))
	var alvo := criar_camaleao_teste(arena, Vector2(370, 300))
	c.controle = "teclado1"
	c.mira_com_setas = true
	await avancar_fisica(1)

	# Recolher língua durante puxada solta o alvo e aplica RECARGA_SOLTAR
	c.set("_dados_lingua", Linguas.TIPOS[Linguas.BASICA])
	c._comecar_puxada(alvo)
	c._recolher_lingua()
	assert_eq(c.get("_estado_lingua"), "", "_recolher_lingua() recolhe a língua durante puxada")
	assert_eq(alvo.puxado_por, null, "_recolher_lingua() libera alvo preso")
	assert_approx(c.get("_recarga_lingua"), Camaleao.RECARGA_SOLTAR, 0.01, "_recolher_lingua() aplica RECARGA_SOLTAR fora do gancho")

	# Recolher no gancho mantém embalo e usa RECARGA_LINGUA
	c.set("_estado_lingua", "gancho")
	c.velocity = Vector2(600, 0)
	c._recolher_lingua()
	assert_approx(c.get("_embalo").x, 600.0, 0.1, "_recolher_lingua() no gancho mantém embalo")
	assert_approx(c.get("_recarga_lingua"), Camaleao.RECARGA_LINGUA, 0.01, "_recolher_lingua() no gancho usa RECARGA_LINGUA")

	# Sem setas pressionadas, _ler_mira() retorna ZERO
	assert_eq(c._ler_mira(), Vector2.ZERO, "_ler_mira() retorna ZERO sem entrada de mira")
	c.controle = "pad0"
	assert_eq(c._ler_mira(), Vector2.ZERO, "_ler_mira() no gamepad retorna ZERO com analógico direito em repouso")

	# Gamepad: analógico esquerdo anda para a esquerda enquanto analógico direito mira para cima/diagonal
	c.bot = ""
	c.set_physics_process(false)
	c.position = Vector2(500, 500)
	c.set("_recarga_lingua", 0.0)
	c.set("_recarga_golpe", 0.0)
	c.set("_recarga_invisibilidade", 0.0)
	await arvore().process_frame
	Input.action_press("pad0_esquerda")
	Input.action_press("pad0_mira_cima")
	var mira_cima: Vector2 = c._ler_mira()
	assert_approx(mira_cima.angle(), Vector2.UP.angle(), 0.01, "_ler_mira() lê direção do analógico direito")

	# Dispara língua com LT mirando para cima enquanto anda para a esquerda
	Input.action_press("pad0_lingua")
	c._physics_process(0.016)
	Input.action_release("pad0_lingua")
	assert_eq(c.get("_estado_lingua"), "indo", "LT lança a língua mesmo andando para outro lado")
	assert_approx(c.direcao.angle(), Vector2.UP.angle(), 0.01, "Língua sai na direção da mira do analógico direito")

	# Recolher a língua com golpe (RT) mirando para a direita acerta alvo na mira (e não na direção de movimento)
	alvo.position = Vector2(570, 500)
	var alvo_morreu := [0]
	alvo.morreu.connect(func(_q): alvo_morreu[0] += 1)
	Input.action_release("pad0_mira_cima")
	Input.action_press("pad0_mira_direita")
	Input.action_press("pad0_golpe")
	c._physics_process(0.016)
	Input.action_release("pad0_golpe")
	assert_true(c.get("_mirando"), "Analógico direito ativa indicador _mirando")
	assert_approx(c.direcao.angle(), Vector2.RIGHT.angle(), 0.01, "RT recolhe língua e direciona golpe pelo analógico direito")
	await avancar_fisica(2)
	assert_eq(alvo_morreu[0], 0, "Golpe não mata")
	assert_true(alvo.atordoado(), "Golpe direcionado pelo analógico direito acerta (atordoa) alvo na mira")

	# Soltar-se de puxada golpeando (RT) com analógico direito mira o contra-ataque
	await arvore().process_frame
	var puxador := criar_camaleao_teste(arena, Vector2(400, 500))
	c.position = Vector2(500, 500)
	c.set("_recarga_golpe", 0.0)
	puxador.set("_dados_lingua", Linguas.TIPOS[Linguas.BASICA])
	puxador._comecar_puxada(c)
	c.set("_tempo_puxado", Camaleao.TEMPO_ATE_SE_SOLTAR + 0.05)
	Input.action_release("pad0_mira_direita")
	Input.action_press("pad0_mira_cima")
	Input.action_press("pad0_golpe")
	c._physics_process(0.016)
	Input.action_release("pad0_golpe")
	Input.action_release("pad0_mira_cima")
	assert_eq(c.puxado_por, null, "RT solta da puxada do adversário")
	assert_approx(c.direcao.angle(), Vector2.UP.angle(), 0.01, "Contra-ataque ao se soltar respeita mira do analógico direito")
	await avancar_fisica(2)

	# Botão A segura carga de invisibilidade
	await arvore().process_frame
	Input.action_release("pad0_esquerda")
	c.set("_recarga_invisibilidade", 0.0)
	Input.action_press("pad0_invisivel")
	c._physics_process(0.2)
	assert_true(c.get("_carga_invisivel") > 0.0, "Botão A carrega invisibilidade no controle")
	Input.action_release("pad0_invisivel")

	limpar_arena(arena)

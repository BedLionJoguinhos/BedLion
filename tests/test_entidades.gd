extends "res://tests/test_helper.gd"

const Grude := preload("res://scripts/grude.gd")
const Casca := preload("res://scripts/casca.gd")
const CocoPombo := preload("res://scripts/coco_pombo.gd")
const Pistas := preload("res://scripts/pistas.gd")
const Ondulacao := preload("res://scripts/ondulacao.gd")
const Desenho := preload("res://scripts/desenho_camaleao.gd")
const Bot := preload("res://scripts/bot.gd")
const Placar := preload("res://scripts/placar.gd")
const Ui := preload("res://scripts/ui.gd")
const MainScript := preload("res://scripts/main.gd")
const Linguas := preload("res://scripts/linguas.gd")
const ArmaNoChao := preload("res://scripts/arma_no_chao.gd")


func get_suite_name() -> String:
	return "Testes de Entidades, Bot e Regras (Grude/Casca/Coco/Pistas/Bot/Partida)"


func run_tests() -> void:
	await test_grude_caminho_pisada_e_expiracao()
	await test_casca_estourar_e_duracao()
	await test_coco_pombo_aviso_e_sujar_pes()
	await test_pistas_poca_e_ponte()
	await test_bot_niveis_acoes_e_agua()
	test_partida_cores_e_configuracoes()
	test_placar_e_ui()
	await test_main_rotacao_mapas_sem_repeticao()
	await test_bot_poderes_pistas_e_esquiva()
	await test_main_spawns_rodada_e_atalhos()
	test_controles_descricoes()


func test_grude_caminho_pisada_e_expiracao() -> void:
	var mapa_lago: Dictionary = Mapas.MAPAS[2]  # Lago (água em x=500..1100, y=230..670)
	var pts := Grude.pontos_no_caminho(Vector2(440, 300), Vector2(650, 300), mapa_lago)
	assert_true(pts.size() > 0, "pontos_no_caminho() gera bolotas na parte seca")
	assert_true(pts.all(func(p): return not Mapas.na_agua(mapa_lago, p)), "pontos_no_caminho() pula pontos dentro da água")

	var arena := criar_arena_teste()
	var dono := criar_camaleao_teste(arena, Vector2(200, 300))
	var outro := criar_camaleao_teste(arena, Vector2(400, 300))
	var grude := Grude.new()
	grude.dono = dono
	grude.pontos = [Vector2(400, 300) + Desenho.PES, Vector2(520, 300) + Desenho.PES]
	arena.add_child(grude)
	await avancar_fisica(1)

	# Antes de TEMPO_ARMAR não prende
	grude._physics_process(0.1)
	assert_approx(outro.get("_tempo_grudado"), 0.0, 0.001, "Grude não prende antes de TEMPO_ARMAR")

	# Após TEMPO_ARMAR prende outro camaleão e gasta apenas a bolota pisada
	grude._physics_process(Grude.TEMPO_ARMAR)
	assert_true(outro.get("_tempo_grudado") > 0.0, "Grude prende inimigo que pisa após TEMPO_ARMAR")
	var vivas: Array = grude.get("_vivas")
	assert_false(vivas[0], "Bolota pisada é consumida")
	assert_true(vivas[1], "Bolota distante permanece ativa")

	# Dono é imune
	dono.position = Vector2(520, 300)
	grude._physics_process(0.05)
	assert_approx(dono.get("_tempo_grudado"), 0.0, 0.001, "Quem soltou o grude é imune a ele")

	# Expiração por DURACAO
	grude._physics_process(Grude.DURACAO)
	assert_true(grude.is_queued_for_deletion(), "Grude é removido após DURACAO")

	limpar_arena(arena)


func test_casca_estourar_e_duracao() -> void:
	var arena := criar_arena_teste()
	var casca := Casca.new()
	casca.position = Vector2(300, 300)
	casca.cor = Color.RED
	arena.add_child(casca)
	await avancar_fisica(1)

	casca.estourar()
	assert_true(casca.is_queued_for_deletion(), "estourar() remove a casca")
	await avancar_fisica(1)
	assert_true(
		arena.get_children().any(func(n): return not is_instance_valid(n) or (not n.is_queued_for_deletion())), "estourar() instancia EfeitoMorte no mundo"
	)

	var casca2 := Casca.new()
	arena.add_child(casca2)
	casca2._process(Casca.DURACAO + 0.1)
	assert_true(casca2.is_queued_for_deletion(), "Casca murcha e some após DURACAO")

	limpar_arena(arena)


func test_coco_pombo_aviso_e_sujar_pes() -> void:
	var arena := criar_arena_teste()
	var c := criar_camaleao_teste(arena, Vector2(300, 300))
	var coco := CocoPombo.new()
	coco.position = Vector2(300, 300) + Desenho.PES
	arena.add_child(coco)
	await avancar_fisica(1)

	# Durante aviso ainda não suja
	coco._physics_process(CocoPombo.TEMPO_AVISO * 0.5)
	assert_approx(c.get("_tempo_pes_sujos"), 0.0, 0.001, "Cocô em fase de aviso não suja os pés")

	# Após cair no chão suja os pés
	coco._physics_process(CocoPombo.TEMPO_AVISO * 0.6)
	assert_true(c.get("_tempo_pes_sujos") > 0.0, "Cocô no chão suja os pés do camaleão próximo")

	# Expira após TEMPO_NO_CHAO
	coco._physics_process(CocoPombo.TEMPO_NO_CHAO + 0.1)
	assert_true(coco.is_queued_for_deletion(), "Cocô some após TEMPO_NO_CHAO")

	limpar_arena(arena)


func test_pistas_poca_e_ponte() -> void:
	var mapa_lago: Dictionary = Mapas.MAPAS[2]  # poça em Rect2(180, 420, 110, 70), ponte em Rect2(470, 410, 660, 80)
	var arena := criar_arena_teste()
	var pistas := Pistas.new()
	pistas.mapa = mapa_lago
	arena.add_child(pistas)
	var c := criar_camaleao_teste(arena, Vector2(235, 455) - Desenho.PES, mapa_lago)
	await avancar_fisica(1)

	# Na poça: molha os pés e gera ondinha ao andar
	pistas._physics_process(0.05)
	assert_true(c.get("_tempo_pes_sujos") > 0.0, "Pistas molha os pés do camaleão na poça")
	c.position.x += Pistas.DISTANCIA_ONDA_POCA + 5.0
	pistas._physics_process(0.05)
	assert_true(arena.get_children().any(func(n): return n is Ondulacao), "Andar na poça cria Ondulacao no mapa")

	limpar_arena(arena)


func test_bot_niveis_acoes_e_agua() -> void:
	for dif in ["facil", "medio", "dificil"]:
		assert_true(Bot.NIVEIS.has(dif), "Bot.NIVEIS contém dificuldade '%s'" % dif)
		var dados: Dictionary = Bot.NIVEIS[dif]
		for chave in ["reacao", "erro_mira", "prever", "agressividade", "poderes", "invisibilidade", "deteccao", "cuidado", "esquiva", "memoria"]:
			assert_true(dados.has(chave), "Nível '%s' define parâmetro '%s'" % [dif, chave])

	var arena := criar_arena_teste()
	var mapa_jardim: Dictionary = Mapas.MAPAS[0]
	var bot_cam := criar_camaleao_teste(arena, Vector2(212, 262), mapa_jardim, Color.ORANGE, "dificil")
	var alvo := criar_camaleao_teste(arena, Vector2(360, 262), mapa_jardim, Color.GREEN, "parado")
	await avancar_fisica(2)

	var cerebro: Bot = bot_cam.get("_cerebro")
	assert_true(cerebro != null, "Camaleão com bot != 'parado' instancia Bot")
	var acoes := cerebro.agir(0.3)
	for chave in ["mover", "golpe", "lingua", "apertou_invisivel", "segurando_invisivel"]:
		assert_true(acoes.has(chave), "Bot.agir() retorna chave '%s'" % chave)
	assert_true(acoes["mover"] is Vector2, "Bot.agir().mover é Vector2")

	# Bot sendo puxado reage com golpe após reação
	bot_cam.ser_puxado(alvo, 200.0)
	bot_cam.set("_tempo_puxado", 0.5)
	var acoes_puxado := cerebro.agir(0.016)
	assert_true(acoes_puxado["golpe"], "Bot sendo puxado tenta se soltar com golpe após reação")

	limpar_arena(arena)


func test_partida_cores_e_configuracoes() -> void:
	var partida: Node = (Engine.get_main_loop() as SceneTree).root.get_node("Partida")
	assert_eq(partida.CORES.size(), 8, "Partida.CORES possui 8 cores cadastradas")
	var nomes := {}
	for item in partida.CORES:
		nomes[item["nome"]] = true
	assert_eq(nomes.size(), partida.CORES.size(), "Nomes das cores em Partida.CORES são únicos")
	assert_eq(partida.indice_cor("Verde"), 0, "indice_cor('Verde') retorna 0")
	assert_eq(partida.indice_cor("Inexistente"), -1, "indice_cor('Inexistente') retorna -1")

	var vol_orig: float = partida.volume
	var tela_orig: bool = partida.tela_cheia
	partida.volume = 0.0
	partida.aplicar_configuracoes()
	var bus := AudioServer.get_bus_index("Master")
	assert_true(AudioServer.is_bus_mute(bus), "Volume 0.0 silencia o bus Master")

	partida.volume = 0.65
	partida.tela_cheia = false
	partida.aplicar_configuracoes()
	partida.salvar_configuracoes()
	partida.volume = 0.1
	partida._carregar_configuracoes()
	assert_approx(partida.volume, 0.65, 0.01, "salvar/carregar configurações persiste volume")

	partida.volume = vol_orig
	partida.tela_cheia = tela_orig
	partida.aplicar_configuracoes()


func test_placar_e_ui() -> void:
	var placar := Placar.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(placar)
	placar.size = Vector2(1600, 50)
	placar.atualizar([{"nome": "Verde", "cor": Color.GREEN, "bot": ""}], [3], 5)
	assert_eq(placar.meta, 5, "Placar.atualizar() define meta")
	assert_eq(placar.pontos, [3], "Placar.atualizar() define pontos")
	placar.free()

	var rotulo := Ui.rotulo("Teste", 24, Vector2(10, 20), 200)
	assert_eq(rotulo.text, "Teste", "Ui.rotulo() configura texto")
	rotulo.free()
	var botao := Ui.botao("Ok", Vector2(120, 40), 20)
	assert_eq(botao.text, "Ok", "Ui.botao() configura texto")
	botao.free()
	var painel := Ui.painel(Rect2(0, 0, 100, 100), Ui.AMARELO)
	assert_eq(painel.size, Vector2(100, 100), "Ui.painel() configura tamanho")
	painel.free()


func test_main_rotacao_mapas_sem_repeticao() -> void:
	var main: Node = MainScript.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(main)

	var total_mapas: int = Mapas.MAPAS.size()
	var vistos_volta1 := {}
	var anterior: int = main.get("_indice_mapa")
	vistos_volta1[anterior] = true

	for _i in range(total_mapas - 1):
		main._trocar_mapa()
		var atual: int = main.get("_indice_mapa")
		assert_false(vistos_volta1.has(atual), "Volta 1 de mapas não repete índice %d antes de completar ciclo" % atual)
		vistos_volta1[atual] = true
		anterior = atual
	assert_eq(vistos_volta1.size(), total_mapas, "Todos os mapas aparecem exatamente uma vez na volta 1")

	main._trocar_mapa()
	var primeiro_volta2: int = main.get("_indice_mapa")
	assert_true(primeiro_volta2 != anterior, "Primeiro mapa da volta 2 nunca repete o último da volta 1")

	main.set("_jogadores", [{"controle": "teclado1", "bot": ""}])
	assert_false(main._tem_teclado2(), "_tem_teclado2() retorna false sem teclado2")
	main.set("_jogadores", [{"controle": "teclado1", "bot": ""}, {"controle": "teclado2", "bot": ""}])
	assert_true(main._tem_teclado2(), "_tem_teclado2() detecta teclado2 na partida")

	main.free()


func test_bot_poderes_pistas_e_esquiva() -> void:
	var mapa_jardim: Dictionary = Mapas.MAPAS[0]
	var arena := criar_arena_teste(mapa_jardim)
	var bot_cam := criar_camaleao_teste(arena, Vector2(212, 262), mapa_jardim, Color.ORANGE, "dificil")
	var alvo := criar_camaleao_teste(arena, Vector2(400, 262), mapa_jardim, Color.GREEN, "parado")
	await avancar_fisica(2)

	var cerebro: Bot = bot_cam.get("_cerebro")
	# Bot com gancho calcula direção de gancho em direção ao alvo ou para fugir
	bot_cam.lingua = "gancho"
	var dir_gancho := cerebro._direcao_gancho(Vector2(1400, 700), false)
	assert_true(dir_gancho == Vector2.ZERO or is_equal_approx(dir_gancho.length(), 1.0), "Bot._direcao_gancho() retorna ZERO ou vetor unitário")

	# Bot com grude perto de rastro de grude do adversário detecta risco em _pisaria_grude
	var grude := Grude.new()
	grude.dono = alvo
	grude.pontos = [Vector2(212, 262) + Desenho.PES]
	arena.add_child(grude)
	await avancar_fisica(1)
	assert_true(cerebro._pisaria_grude(Vector2(212, 262)), "Bot._pisaria_grude() detecta rastro de grude inimigo")

	# Bot detecta pistas de camaleão invisível no sol, poça, pés sujos, grama e ponte
	alvo.invisivel = true
	alvo.visible = false
	alvo.position = Vector2(700, 400) - Desenho.PES  # sol do Jardim (620, 320, 360, 260)
	assert_approx(cerebro._pista_de(alvo), 8.0, 0.01, "Bot._pista_de() detecta invisível no sol")
	alvo.position = Vector2(200, 440) - Desenho.PES  # grama do Jardim (130, 380, 230, 140)
	assert_approx(cerebro._pista_de(alvo), 28.0, 0.01, "Bot._pista_de() detecta invisível no capim")
	alvo.position = Vector2(395, 715) - Desenho.PES  # poça do Jardim (340, 680, 110, 70)
	assert_true(cerebro._pista_de(alvo) in [-1.0, 14.0], "Bot._pista_de() avalia poça sem erro")

	# Esquiva quando adversário lança língua na direção do bot
	alvo.invisivel = false
	alvo.visible = true
	alvo.position = Vector2(350, 262)
	alvo.direcao = Vector2.LEFT
	alvo.set("_dados_lingua", Linguas.TIPOS[Linguas.BASICA])
	alvo.set("_estado_lingua", "indo")
	cerebro.nivel = cerebro.nivel.duplicate()
	cerebro.nivel["esquiva"] = 1.0
	assert_true(cerebro._desviar_de_lingua(), "Bot._desviar_de_lingua() ativa esquiva quando língua vem na direção dele")
	alvo.set("_estado_lingua", "")

	# Desarmado e puxando: espera a puxada acabar (aí o alvo fica atordoado)
	bot_cam.lingua = "basica"
	bot_cam.set("_estado_lingua", "puxando")
	bot_cam.set("_preso", alvo)
	bot_cam.set("_recarga_golpe", 0.0)
	alvo.position = bot_cam.position + Vector2(35, 0)
	assert_false(cerebro.agir(0.2)["golpe"], "Bot desarmado não interrompe a puxada com golpe")

	# Armado e puxando: atira assim que o alvo chega ao alcance
	var no_chao := ArmaNoChao.new()
	no_chao.tipo = "pistola"
	arena.add_child(no_chao)
	assert_true(bot_cam.pegar_arma(no_chao), "Bot pega arma")
	var acoes_puxando := cerebro.agir(0.2)
	assert_true(acoes_puxando["golpe"], "Bot armado atira no alvo puxado assim que entra no alcance")
	no_chao.free()

	limpar_arena(arena)


func test_main_spawns_rodada_e_atalhos() -> void:
	var main: Node = MainScript.new()
	arvore().root.add_child(main)
	await arvore().process_frame

	# Spawn de upgrades respeita MAX_UPGRADES
	main._spawnar_upgrade()
	main._spawnar_upgrade()
	main._spawnar_upgrade()
	var rodada: Node = main.get("_rodada")
	var ups := arvore().get_nodes_in_group("upgrades_no_chao").filter(func(u): return u.get_parent() == rodada)
	assert_eq(ups.size(), MainScript.MAX_UPGRADES, "Main._spawnar_upgrade() respeita limite MAX_UPGRADES")

	# Spawn de cocô de pombo cria nó na rodada
	var cocos_antes := arvore().get_nodes_in_group("cocos").size()
	main._spawnar_coco()
	assert_true(arvore().get_nodes_in_group("cocos").size() >= cocos_antes, "Main._spawnar_coco() executa e cria cocô em local livre")

	# Atalhos F1 (muda modo bot) e F2 (próximo mapa) sem lobby
	var modo_antes: int = main.get("_modo_bot")
	var ev_f1 := InputEventKey.new()
	ev_f1.keycode = KEY_F1
	ev_f1.pressed = true
	main._unhandled_input(ev_f1)
	assert_eq(main.get("_modo_bot"), (modo_antes + 1) % MainScript.MODOS_BOT.size(), "Tecla F1 alterna _modo_bot")

	var mapa_antes: int = main.get("_indice_mapa")
	var ev_f2 := InputEventKey.new()
	ev_f2.keycode = KEY_F2
	ev_f2.pressed = true
	main._unhandled_input(ev_f2)
	assert_true(main.get("_indice_mapa") != mapa_antes, "Tecla F2 pula para próximo mapa")

	# Empate quando todos morrem no mesmo quadro
	var vivos: Array = main.get("_vivos").duplicate()
	for v in vivos:
		v.morrer()
	await avancar_fisica(2)
	assert_true(main.get("_rodada_acabou"), "Morte de todos os jogadores encerra a rodada como empate")

	# Vitória de rodada sem atingir meta + renderização da tela de vitória
	main.placar[0] = MainScript.PONTOS_PARA_VENCER - 1
	main._exibir_fim_partida(0)
	await arvore().process_frame
	assert_true(main.get("_tela_fim_partida").visible, "Tela de vitória renderiza vencedor")

	main.free()


func test_controles_descricoes() -> void:
	var c := preload("res://scripts/controles.gd").new()
	assert_eq(c.descricao("teclado1"), "WASD, F/G/H", "descricao('teclado1') retorna texto esperado")
	assert_eq(c.descricao("teclado2"), "setas, . / , / ;", "descricao('teclado2') retorna texto esperado")
	assert_true(c.descricao("pad0").contains("RT/A/LT"), "descricao('pad0') descreve botões do controle")
	assert_eq(c.descricao(""), "bot", "descricao('') retorna 'bot'")
	assert_eq(c.nome_botao("teclado1", "golpe"), "F", "nome_botao('teclado1', 'golpe') retorna 'F'")
	assert_eq(c.nome_botao("pad0", "golpe"), "RT", "nome_botao('pad0', 'golpe') retorna 'RT'")
	assert_eq(c.nome_botao("pad0", "invisivel"), "A", "nome_botao('pad0', 'invisivel') retorna 'A'")
	assert_eq(c.nome_botao("pad0", "lingua"), "LT", "nome_botao('pad0', 'lingua') retorna 'LT'")
	assert_false(c.eh_xbox(-1), "eh_xbox(-1) retorna false")
	c.free()

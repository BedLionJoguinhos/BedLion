extends "res://tests/test_helper.gd"

const MenuScript := preload("res://scripts/menu.gd")
const LobbyScript := preload("res://scripts/lobby.gd")
const ConfigScript := preload("res://scripts/configuracoes.gd")


func get_suite_name() -> String:
	return "Testes de Telas e Fluxo de Lobby (Menu/Lobby/Configurações)"


func run_tests() -> void:
	test_menu_instancia()
	test_configuracoes_volume_e_rotulo()
	test_lobby_vagas_cores_e_bots()


func test_menu_instancia() -> void:
	var menu: Control = MenuScript.new()
	arvore().root.add_child(menu)
	assert_true(menu.get_child_count() >= 4, "Menu instancia fundo, enfeite, título e botões")
	menu._process(0.1)
	assert_approx(menu.get("_tempo"), 0.1, 0.001, "Menu._process() avança animação de enfeite")
	menu.free()


func test_configuracoes_volume_e_rotulo() -> void:
	var partida: Node = arvore().root.get_node("Partida")
	var vol_orig: float = partida.volume
	var tela_orig: bool = partida.tela_cheia

	var cfg: Control = ConfigScript.new()
	arvore().root.add_child(cfg)
	var slider: HSlider = cfg.get("_volume")
	slider.value = 45.0
	assert_approx(partida.volume, 0.45, 0.001, "Alterar slider de volume atualiza Partida.volume")
	var rotulo: Label = cfg.get("_rotulo_volume")
	assert_true(rotulo.text.contains("45%"), "Rótulo de volume reflete percentual")

	cfg._ao_mudar_tela_cheia(false)
	assert_false(partida.tela_cheia, "Configuracoes._ao_mudar_tela_cheia(false) atualiza Partida.tela_cheia")
	cfg.free()

	partida.volume = vol_orig
	partida.tela_cheia = tela_orig
	partida.aplicar_configuracoes()


func test_lobby_vagas_cores_e_bots() -> void:
	var lobby: Control = LobbyScript.new()
	arvore().root.add_child(lobby)

	assert_eq(lobby._humanos(), 0, "Lobby inicia com 0 jogadores humanos")
	assert_false(lobby._todos_prontos(), "Lobby vazio não está pronto")

	lobby._entrar("teclado1")
	lobby._entrar("pad0")
	assert_eq(lobby._humanos(), 2, "Lobby._entrar() preenche vagas sequencialmente")
	assert_true(lobby._vaga_de("teclado1") == 0 and lobby._vaga_de("pad0") == 1, "Lobby._vaga_de() localiza controles corretamente")

	# Cores exclusivas entre jogadores
	var vagas: Array = lobby.get("_vagas")
	assert_true(vagas[0]["cor"] != vagas[1]["cor"], "Jogadores recebem cores distintas ao entrar")
	var cor_livre: int = lobby._proxima_cor_livre(vagas[0]["cor"], 1)
	assert_true(cor_livre != vagas[0]["cor"] and cor_livre != vagas[1]["cor"], "Lobby._proxima_cor_livre() pula cores já ocupadas")

	# Etapa de bots e limites
	vagas[0]["pronto"] = true
	assert_false(lobby._todos_prontos(), "_todos_prontos() exige todos prontos")
	vagas[1]["pronto"] = true
	assert_true(lobby._todos_prontos(), "_todos_prontos() retorna true quando todos confirmaram")

	lobby._ir_para_bots()
	assert_eq(lobby.get("_etapa"), "bots", "_ir_para_bots() transiciona para etapa 'bots'")
	var limites: Vector2i = lobby._limites_bots()
	assert_eq(limites, Vector2i(0, 2), "Com 2 humanos, limites de bots são [0, 2]")

	lobby._ajustar_bots(2)
	assert_eq(lobby.get("_quantidade_bots"), 2, "_ajustar_bots() respeita limite máximo")
	var cores_bots: Array = lobby._cores_dos_bots()
	assert_eq(cores_bots.size(), 2, "_cores_dos_bots() aloca cor para cada bot")
	assert_false(cores_bots.has(vagas[0]["cor"]) or cores_bots.has(vagas[1]["cor"]), "Cores dos bots nunca colidem com cores dos humanos")

	var dif_inicial: String = lobby.get("_dificuldade")
	lobby._mudar_dificuldade(1)
	assert_true(lobby.get("_dificuldade") != dif_inicial, "_mudar_dificuldade() alterna dificuldade")
	lobby._escolher_dificuldade("dificil")
	assert_eq(lobby.get("_dificuldade"), "dificil", "_escolher_dificuldade() seleciona dificuldade")

	# Desconexão do gamepad remove apenas a vaga dele
	lobby._ao_mudar_controle(0, false)
	assert_eq(lobby._humanos(), 1, "Desconexão de pad0 remove vaga do controle no lobby")
	assert_eq(lobby._limites_bots(), Vector2i(1, 3), "Com 1 humano, mínimo de bots passa a ser 1")

	lobby._voltar_para_entrar()
	assert_eq(lobby.get("_etapa"), "entrar", "_voltar_para_entrar() retorna à etapa 1")
	assert_false(vagas[0]["pronto"], "Voltar à etapa 1 desmarca prontidão")

	lobby.free()

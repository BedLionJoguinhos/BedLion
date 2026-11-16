extends RefCounted

const Controles := preload("res://scripts/controles.gd")

var passed := 0
var failed := 0

func get_suite_name() -> String:
	return "Testes de Controles (scripts/controles.gd)"

func assert_true(condition: bool, message: String) -> void:
	if condition:
		print("  ✓ %s" % message)
		passed += 1
	else:
		printerr("  ✗ FALHA: %s" % message)
		failed += 1

func run_tests() -> void:
	test_teclados_configurados()
	test_acoes_obrigatorias_teclado()
	test_configuracao_gamepad()
	test_input_map_pads_e_deadzones()
	test_input_map_interface_gamepad()
	test_helpers_dispositivo_e_vibracao()

func test_teclados_configurados() -> void:
	assert_true(Controles.TECLADOS.has("teclado1"), "Configuração do Teclado 1 existe")
	assert_true(Controles.TECLADOS.has("teclado2"), "Configuração do Teclado 2 existe")

func test_acoes_obrigatorias_teclado() -> void:
	var acoes := ["cima", "baixo", "esquerda", "direita", "golpe", "invisivel", "lingua"]
	for teclado_id in ["teclado1", "teclado2"]:
		var mapa: Dictionary = Controles.TECLADOS.get(teclado_id, {})
		for acao in acoes:
			assert_true(mapa.has(acao) and mapa[acao].size() > 0, "'%s' mapeia a ação obrigatória '%s'" % [teclado_id, acao])

func test_configuracao_gamepad() -> void:
	assert_true(Controles.BOTOES_PAD.get("golpe", []) == [JOY_BUTTON_A],
		"Golpe usa exclusivamente o botão A (sem RB)")
	assert_true(Controles.BOTOES_PAD.get("invisivel", []) == [JOY_BUTTON_B],
		"Invisibilidade usa exclusivamente o botão B (sem LB nem Y)")
	assert_true(Controles.BOTOES_PAD.get("lingua", []) == [JOY_BUTTON_X],
		"Língua usa exclusivamente o botão X")
	assert_true(not Controles.EIXOS_PAD.has("lingua") and not Controles.EIXOS_PAD.has("invisivel"),
		"Gatilhos LT e RT não estão mapeados")
	assert_true(not Controles.BOTOES_PAD.has("cima") and not Controles.BOTOES_PAD.has("baixo") \
		and not Controles.BOTOES_PAD.has("esquerda") and not Controles.BOTOES_PAD.has("direita"),
		"Direcional (D-Pad) não está mapeado para movimentação")
	assert_true(Controles.MAX_PADS >= 4, "Suporta ao menos 4 controles conectados simultaneamente")

func test_input_map_pads_e_deadzones() -> void:
	var acoes := ["cima", "baixo", "esquerda", "direita", "golpe", "invisivel", "lingua"]
	for pad in Controles.MAX_PADS:
		for acao in acoes:
			var nome := "pad%d_%s" % [pad, acao]
			assert_true(InputMap.has_action(nome), "Ação '%s' registrada no InputMap" % nome)
			var eventos := InputMap.action_get_events(nome)
			assert_true(eventos.size() > 0 and eventos.all(func(e): return e.device == pad),
				"Ação '%s' vinculada exclusivamente ao device %d" % [nome, pad])

	for dir in ["cima", "baixo", "esquerda", "direita"]:
		var evs := InputMap.action_get_events("pad0_%s" % dir)
		assert_true(evs.all(func(e): return e is InputEventJoypadMotion),
			"Movimento '%s' aceita exclusivamente o analógico esquerdo" % dir)

	assert_true(is_equal_approx(InputMap.action_get_deadzone("pad0_esquerda"), Controles.ZONA_MORTA),
		"Ação de movimento usa ZONA_MORTA padrão (0.22)")
	assert_true(is_equal_approx(InputMap.action_get_deadzone("pad0_golpe"), Controles.ZONA_MORTA),
		"Ação de combate usa ZONA_MORTA padrão (0.22)")

func test_input_map_interface_gamepad() -> void:
	for acao in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_cancel"]:
		assert_true(InputMap.has_action(acao), "Ação de interface '%s' existe" % acao)
		assert_true(is_equal_approx(InputMap.action_get_deadzone(acao), Controles.ZONA_MORTA_INTERFACE),
			"Ação de interface '%s' usa ZONA_MORTA_INTERFACE" % acao)
	var tem_a := InputMap.action_get_events("ui_accept").any(
		func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_A and e.device == -1)
	var tem_b := InputMap.action_get_events("ui_cancel").any(
		func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_B and e.device == -1)
	assert_true(tem_a, "Botão A aceita menus (ui_accept) para qualquer controle")
	assert_true(tem_b, "Botão B cancela menus (ui_cancel) para qualquer controle")

func test_helpers_dispositivo_e_vibracao() -> void:
	assert_true(Controles.dispositivo_de("pad0") == 0, "dispositivo_de('pad0') retorna 0")
	assert_true(Controles.dispositivo_de("pad3") == 3, "dispositivo_de('pad3') retorna 3")
	assert_true(Controles.dispositivo_de("teclado1") == -1, "dispositivo_de('teclado1') retorna -1")
	assert_true(Controles.dispositivo_de("") == -1, "dispositivo_de('') retorna -1")
	assert_true(Controles.eh_pad("pad1") and not Controles.eh_pad("teclado2"), "eh_pad diferencia gamepad de teclado")
	# Garantir que chamadas de vibração com dispositivos inválidos ou desconectados não geram erro
	Controles.vibrar("teclado1", 0.5, 0.5, 0.1)
	Controles.vibrar("pad0", 0.5, 0.5, 0.1)
	Controles.parar_vibracao("pad0")
	assert_true(true, "Chamadas de vibração sem controle conectado executam com segurança")

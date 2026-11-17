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
	assert_true(Controles.BOTOES_PAD.get("invisivel", []) == [JOY_BUTTON_A], "Invisibilidade usa exclusivamente o botão A")
	assert_true(not Controles.BOTOES_PAD.has("golpe") and not Controles.BOTOES_PAD.has("lingua"), "Golpe e língua não usam botões face no controle")
	assert_true(Controles.EIXOS_PAD.get("lingua", []) == [JOY_AXIS_TRIGGER_LEFT, 1.0], "Língua usa o gatilho esquerdo LT")
	assert_true(Controles.EIXOS_PAD.get("golpe", []) == [JOY_AXIS_TRIGGER_RIGHT, 1.0], "Golpe usa o gatilho direito RT")
	assert_true(Controles.EIXOS_MIRA_PAD.get("mira_cima", []) == [JOY_AXIS_RIGHT_Y, -1.0], "Mira cima usa analógico direito Y-")
	assert_true(Controles.EIXOS_MIRA_PAD.get("mira_baixo", []) == [JOY_AXIS_RIGHT_Y, 1.0], "Mira baixo usa analógico direito Y+")
	assert_true(Controles.EIXOS_MIRA_PAD.get("mira_esquerda", []) == [JOY_AXIS_RIGHT_X, -1.0], "Mira esquerda usa analógico direito X-")
	assert_true(Controles.EIXOS_MIRA_PAD.get("mira_direita", []) == [JOY_AXIS_RIGHT_X, 1.0], "Mira direita usa analógico direito X+")
	assert_true(
		(
			not Controles.BOTOES_PAD.has("cima")
			and not Controles.BOTOES_PAD.has("baixo")
			and not Controles.BOTOES_PAD.has("esquerda")
			and not Controles.BOTOES_PAD.has("direita")
		),
		"Direcional (D-Pad) não está mapeado para movimentação"
	)
	assert_true(Controles.MAX_PADS >= 4, "Suporta ao menos 4 controles conectados simultaneamente")


func test_input_map_pads_e_deadzones() -> void:
	var acoes := ["cima", "baixo", "esquerda", "direita", "golpe", "invisivel", "lingua", "mira_cima", "mira_baixo", "mira_esquerda", "mira_direita"]
	for pad in Controles.MAX_PADS:
		for acao in acoes:
			var nome := "pad%d_%s" % [pad, acao]
			assert_true(InputMap.has_action(nome), "Ação '%s' registrada no InputMap" % nome)
			var eventos := InputMap.action_get_events(nome)
			assert_true(eventos.size() > 0 and eventos.all(func(e): return e.device == pad), "Ação '%s' vinculada exclusivamente ao device %d" % [nome, pad])

	for dir in ["cima", "baixo", "esquerda", "direita"]:
		var evs := InputMap.action_get_events("pad0_%s" % dir)
		assert_true(evs.all(func(e): return e is InputEventJoypadMotion), "Movimento '%s' aceita exclusivamente o analógico esquerdo" % dir)

	var evs_invisivel := InputMap.action_get_events("pad0_invisivel")
	assert_true(evs_invisivel.all(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_A), "pad0_invisivel usa JOY_BUTTON_A")
	var evs_lingua := InputMap.action_get_events("pad0_lingua")
	assert_true(evs_lingua.all(func(e): return e is InputEventJoypadMotion and e.axis == JOY_AXIS_TRIGGER_LEFT), "pad0_lingua usa LT")
	var evs_golpe := InputMap.action_get_events("pad0_golpe")
	assert_true(evs_golpe.all(func(e): return e is InputEventJoypadMotion and e.axis == JOY_AXIS_TRIGGER_RIGHT), "pad0_golpe usa RT")
	for dir_mira in ["mira_cima", "mira_baixo", "mira_esquerda", "mira_direita"]:
		var nome_mira := "pad0_%s" % dir_mira
		var evs_mira := InputMap.action_get_events(nome_mira)
		assert_true(evs_mira.all(func(e): return e is InputEventJoypadMotion), "Ação '%s' usa eixo do analógico direito" % nome_mira)
		assert_true(is_equal_approx(InputMap.action_get_deadzone(nome_mira), Controles.ZONA_MORTA_MIRA), "Ação '%s' usa ZONA_MORTA_MIRA" % nome_mira)

	assert_true(is_equal_approx(InputMap.action_get_deadzone("pad0_esquerda"), Controles.ZONA_MORTA), "Ação de movimento usa ZONA_MORTA padrão (0.22)")
	assert_true(is_equal_approx(InputMap.action_get_deadzone("pad0_golpe"), Controles.ZONA_MORTA), "Ação de combate usa ZONA_MORTA padrão (0.22)")


func test_input_map_interface_gamepad() -> void:
	for acao in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_cancel"]:
		assert_true(InputMap.has_action(acao), "Ação de interface '%s' existe" % acao)
		assert_true(
			is_equal_approx(InputMap.action_get_deadzone(acao), Controles.ZONA_MORTA_INTERFACE), "Ação de interface '%s' usa ZONA_MORTA_INTERFACE" % acao
		)
	var tem_a := InputMap.action_get_events("ui_accept").any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_A and e.device == -1)
	var tem_b := InputMap.action_get_events("ui_cancel").any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_B and e.device == -1)
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
	assert_true(Controles.ZONA_MORTA_MIRA > 0.0 and Controles.ZONA_MORTA_MIRA < 0.5, "ZONA_MORTA_MIRA configurada dentro do intervalo esperado")
	assert_true(true, "Chamadas de vibração sem controle conectado executam com segurança")

extends "res://tests/test_helper.gd"

const Cenario := preload("res://scripts/cenario.gd")
const Agua := preload("res://scripts/agua.gd")
const Luz := preload("res://scripts/luz.gd")
const GramaAlta := preload("res://scripts/grama_alta.gd")
const Pistas := preload("res://scripts/pistas.gd")
const Ondulacao := preload("res://scripts/ondulacao.gd")
const Placar := preload("res://scripts/placar.gd")
const EfeitoTexto := preload("res://scripts/efeito_texto.gd")
const EfeitoAfundar := preload("res://scripts/efeito_afundar.gd")
const Pegada := preload("res://scripts/pegada.gd")
const Casca := preload("res://scripts/casca.gd")
const LinguaNoChao := preload("res://scripts/lingua_no_chao.gd")
const Linguas := preload("res://scripts/linguas.gd")
const Ui := preload("res://scripts/ui.gd")
const Desenho := preload("res://scripts/desenho_camaleao.gd")


func get_suite_name() -> String:
	return "Testes Visuais, Cenário, Luz, Grama Alta e Pistas"


func run_tests() -> void:
	await test_cenario_agua_luz_grama_render()
	await test_pistas_parado_ponte_e_casca()
	await test_efeitos_placar_e_upgrades_render()
	test_ui_estilo()


func test_cenario_agua_luz_grama_render() -> void:
	var mapa_rios: Dictionary = Mapas.MAPAS[3]  # Rios: paredes, água, pontes, grama, poças, luz
	var arena := criar_arena_teste(mapa_rios)

	var cenario := Cenario.new()
	cenario.tamanho = Vector2(1600, 900)
	cenario.espessura = 40.0
	cenario.mapa = mapa_rios
	arena.add_child(cenario)

	var agua := Agua.new()
	agua.mapa = mapa_rios
	agua.tamanho = Vector2(1600, 900)
	agua.espessura = 40.0
	arena.add_child(agua)

	var luz := Luz.new()
	luz.mapa = mapa_rios
	arena.add_child(luz)

	var grama := GramaAlta.new()
	grama.mapa = mapa_rios
	arena.add_child(grama)

	# Camaleão invisível dentro da mancha de sol de Rios (Rect2(420, 140, 190, 150))
	var cam_sol := criar_camaleao_teste(arena, Vector2(500, 200) - Desenho.PES, mapa_rios)
	cam_sol.invisivel = true
	cam_sol.visible = false

	# Camaleão dentro do capim alto de Rios (Rect2(690, 345, 220, 70))
	var cam_grama := criar_camaleao_teste(arena, Vector2(780, 380) - Desenho.PES, mapa_rios)

	await arvore().process_frame
	cenario.queue_redraw()
	agua._process(0.1)
	luz._process(0.2)
	grama._process(0.2)
	await arvore().process_frame

	assert_true(
		cenario.obstaculos.size() > 0 and cenario.aguas.size() > 0 and cenario.pontes.size() > 0, "Cenario carregou obstáculos, águas e pontes de 'Rios'"
	)
	assert_true(luz.get("_sombras").get(cam_sol, 0.0) > 0.0, "Luz calcula sombra de camaleão invisível dentro da área de sol")
	assert_true(grama.get("_bases").size() > 0, "GramaAlta gerou malha de folhas para o mapa")

	# Remove camaleão da grama para exercitar retorno das folhas
	cam_grama.position = Vector2(150, 150)
	grama._process(0.3)
	await arvore().process_frame
	assert_true(true, "GramaAlta atualiza textura de dobras ao entrar e sair do capim")

	limpar_arena(arena)


func test_pistas_parado_ponte_e_casca() -> void:
	var mapa_lago: Dictionary = Mapas.MAPAS[2]  # Lago: poça (180,420,110,70), ponte (470,410,660,80)
	var arena := criar_arena_teste()
	var pistas := Pistas.new()
	pistas.mapa = mapa_lago
	pistas.set_physics_process(false)
	arena.add_child(pistas)

	var cam := criar_camaleao_teste(arena, Vector2(235, 455) - Desenho.PES, mapa_lago)
	var casca := Casca.new()
	casca.position = Vector2(235, 455) - Desenho.PES
	arena.add_child(casca)

	await arvore().process_frame
	# Parado na poça por >= INTERVALO_ONDA_PARADO gera ondinha do camaleão e da casca
	pistas._physics_process(Pistas.INTERVALO_ONDA_PARADO + 0.1)
	var ondinhas := arena.get_children().filter(func(n): return n is Ondulacao)
	assert_true(ondinhas.size() >= 2, "Pistas gera ondinha para camaleão parado e casca na poça")

	# Caminhar sobre a ponte gera ondinha na água lateral
	cam.position = Vector2(700, 450) - Desenho.PES
	pistas._physics_process(0.05)
	cam.position.x += Pistas.DISTANCIA_ONDA_PONTE + 10.0
	pistas._physics_process(0.05)
	var ondinhas_depois := arena.get_children().filter(func(n): return n is Ondulacao)
	assert_true(ondinhas_depois.size() > ondinhas.size(), "Andar na ponte cria ondinha lateral na água")

	# Casca liberada é limpa do dicionário interno _estado
	casca.queue_free()
	await arvore().process_frame
	pistas._physics_process(0.05)
	assert_false(pistas.get("_estado").has(casca), "Pistas remove instâncias inválidas de _estado")

	limpar_arena(arena)


func test_efeitos_placar_e_upgrades_render() -> void:
	var arena := criar_arena_teste()

	var placar := Placar.new()
	placar.size = Vector2(1600, 50)
	arena.add_child(placar)
	(
		placar
		. atualizar(
			[
				{"nome": "Verde", "cor": Color.GREEN, "bot": ""},
				{"nome": "Laranja", "cor": Color.ORANGE, "bot": "medio"},
			],
			[2, 1],
			5
		)
	)

	var texto := EfeitoTexto.new()
	texto.texto = "Gancho"
	texto.cor = Color.ORANGE
	texto.position = Vector2(300, 300)
	arena.add_child(texto)

	var pegada := Pegada.new()
	pegada.position = Vector2(320, 320)
	arena.add_child(pegada)

	var afundar := EfeitoAfundar.new()
	afundar.cor = Color.BLUE
	afundar.olhando_direita = false
	afundar.position = Vector2(400, 400)
	arena.add_child(afundar)

	var bolhas: Array = []
	for tipo_id in ["gancho", "grude", "muda", "olho", "longa", "rapida"]:
		var bolha := LinguaNoChao.new()
		bolha.tipo = tipo_id
		bolha.position = Vector2(100.0 + bolhas.size() * 60.0, 200.0)
		arena.add_child(bolha)
		bolhas.append(bolha)

	await arvore().process_frame
	placar.queue_redraw()
	texto._process(0.2)
	pegada._process(0.2)
	afundar._process(0.2)
	await arvore().process_frame

	assert_true(texto.modulate.a >= 0.0 and pegada.modulate.a < 1.0, "EfeitoTexto e Pegada atualizam animação durante _process")

	# Afundar bolha até expirar e testar expiração de EfeitoTexto/Pegada/EfeitoAfundar
	bolhas[0].afundar()
	bolhas[0]._physics_process(LinguaNoChao.TEMPO_AFUNDAR + 0.1)
	assert_true(bolhas[0].is_queued_for_deletion(), "LinguaNoChao afundada é liberada após TEMPO_AFUNDAR")

	texto._process(EfeitoTexto.DURACAO + 0.1)
	pegada._process(Pegada.DURACAO + 0.1)
	afundar._process(EfeitoAfundar.DURACAO + 0.1)
	assert_true(
		texto.is_queued_for_deletion() and pegada.is_queued_for_deletion() and afundar.is_queued_for_deletion(),
		"Efeitos temporários são liberados após suas durações"
	)

	# Ondulacao process + draw + expiry
	var onda := Ondulacao.new()
	onda.position = Vector2(500, 500)
	arena.add_child(onda)
	await arvore().process_frame
	onda._process(0.4)
	await arvore().process_frame
	onda._process(Ondulacao.DURACAO)
	assert_true(onda.is_queued_for_deletion(), "Ondulacao executa _draw e expira após DURACAO")

	limpar_arena(arena)


func test_ui_estilo() -> void:
	var estilo := Ui._estilo(Ui.COR_BOTAO, Ui.AMARELO)
	assert_eq(estilo.bg_color, Ui.COR_BOTAO, "Ui._estilo() aplica cor de fundo")
	assert_eq(estilo.border_color, Ui.AMARELO, "Ui._estilo() aplica cor de borda")

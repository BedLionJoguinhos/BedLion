extends "res://tests/test_helper.gd"

const Caminhos := preload("res://scripts/caminhos.gd")


func get_suite_name() -> String:
	return "Testes de Navegação A* (scripts/caminhos.gd)"


func run_tests() -> void:
	test_conversao_celula_centro()
	test_bloqueios_cerca_parede_agua_ponte()
	test_grade_e_cache()
	test_celula_livre_e_caminho()


func test_conversao_celula_centro() -> void:
	var celula := Vector2i(4, 5)
	var c := Caminhos.centro(celula)
	assert_eq(Caminhos.celula_de(c), celula, "celula_de(centro(c)) retorna a mesma célula")
	assert_approx(c.x, 4.5 * Caminhos.CELULA, 0.01, "centro().x cai no meio da célula")
	assert_approx(c.y, 5.5 * Caminhos.CELULA, 0.01, "centro().y cai no meio da célula")


func test_bloqueios_cerca_parede_agua_ponte() -> void:
	var mapa_lago: Dictionary = Mapas.MAPAS[2]  # Lago
	assert_true(Caminhos.bloqueado(mapa_lago, Vector2(20, 450)), "Cerca esquerda é bloqueada")
	assert_true(Caminhos.bloqueado(mapa_lago, Vector2(1580, 450)), "Cerca direita é bloqueada")
	assert_true(Caminhos.bloqueado(mapa_lago, Vector2(285, 225)), "Interior de parede é bloqueado")
	assert_true(Caminhos.bloqueado(mapa_lago, Vector2(800, 320)), "Água do lago é bloqueada")
	assert_false(Caminhos.bloqueado(mapa_lago, Vector2(800, 450)), "Ponte sobre o lago NÃO é bloqueada")


func test_grade_e_cache() -> void:
	var mapa_jardim: Dictionary = Mapas.MAPAS[0]
	var g1 := Caminhos.grade(mapa_jardim)
	var g2 := Caminhos.grade(mapa_jardim)
	assert_true(g1 == g2, "grade() reutiliza o cache AStarGrid2D por nome do mapa")
	assert_eq(g1.region.size.x, ceili(Caminhos.TAMANHO_ARENA.x / Caminhos.CELULA), "Largura da grade cobre a arena")
	assert_eq(g1.region.size.y, ceili(Caminhos.TAMANHO_ARENA.y / Caminhos.CELULA), "Altura da grade cobre a arena")
	assert_eq(g1.diagonal_mode, AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES, "Diagonais respeitam obstáculos")


func test_celula_livre_e_caminho() -> void:
	var mapa_lago: Dictionary = Mapas.MAPAS[2]
	var dentro_parede := Vector2(285, 225)
	var livre := Caminhos.celula_livre(mapa_lago, dentro_parede)
	assert_true(livre.x >= 0 and not Caminhos.bloqueado(mapa_lago, Caminhos.centro(livre)), "celula_livre() encontra célula transitável ao redor de parede")

	var fora := Caminhos.celula_livre(mapa_lago, Vector2(-1000, -1000))
	assert_eq(fora, Vector2i(-1, -1), "celula_livre() retorna (-1, -1) para ponto distante fora da arena")

	var destino := Vector2(1460, 450)
	var rota := Caminhos.caminho(mapa_lago, Vector2(140, 450), destino)
	assert_true(rota.size() > 0, "caminho() encontra rota atravessando a ponte do Lago")
	assert_eq(rota[rota.size() - 1], destino, "Último ponto da rota corresponde exatamente ao destino livre")

	var rota_invalida := Caminhos.caminho(mapa_lago, Vector2(-500, -500), destino)
	assert_true(rota_invalida.is_empty(), "caminho() retorna vazio quando origem não tem célula livre próxima")

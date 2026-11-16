extends RefCounted

const Mapas := preload("res://scripts/mapas.gd")
const Caminhos := preload("res://scripts/caminhos.gd")

var passed := 0
var failed := 0


func get_suite_name() -> String:
	return "Testes de Mapas (scripts/mapas.gd)"


func assert_true(condition: bool, message: String) -> void:
	if condition:
		print("  ✓ %s" % message)
		passed += 1
	else:
		printerr("  ✗ FALHA: %s" % message)
		failed += 1


func run_tests() -> void:
	test_mapas_cadastrados()
	test_regras_de_cada_mapa()
	test_pontos_livres_de_parede_e_agua()
	test_conectividade_rotas()
	test_curva_e_dentro_arredondado()
	test_agua_ponte_e_afundamento()
	test_pocas_luz_e_lugar_livre()


func test_mapas_cadastrados() -> void:
	assert_true(Mapas.MAPAS.size() > 0, "A lista de mapas contém ao menos um mapa cadastrado")


func test_regras_de_cada_mapa() -> void:
	var limites_arena := Rect2(40, 40, 1520, 820)

	for mapa in Mapas.MAPAS:
		var nome: String = mapa.get("nome", "")
		assert_true(not nome.is_empty(), "O mapa possui nome válido")

		var inicios: Array = mapa.get("inicios", [])
		assert_true(inicios.size() >= 4, "Mapa '%s' possui ao menos 4 posições iniciais" % nome)

		var todos_dentro := true
		for pos in inicios:
			if not limites_arena.has_point(pos):
				todos_dentro = false
				break
		assert_true(todos_dentro, "Mapa '%s': todas as posições iniciais estão dentro dos limites da arena" % nome)

		var upgrades: Array = mapa.get("pontos_upgrade", [])
		assert_true(upgrades.size() > 0, "Mapa '%s' possui pontos para surgimento de upgrades" % nome)


func test_pontos_livres_de_parede_e_agua() -> void:
	for mapa in Mapas.MAPAS:
		var nome: String = mapa.get("nome", "")
		var inicios_livres := true
		for pos in mapa.get("inicios", []):
			if _ponto_em_parede(mapa, pos) or Mapas.afunda(mapa, pos):
				inicios_livres = false
				break
		assert_true(inicios_livres, "Mapa '%s': posições iniciais não caem em parede ou água" % nome)

		var upgrades_livres := true
		for pos in mapa.get("pontos_upgrade", []):
			if _ponto_em_parede(mapa, pos) or Mapas.na_agua(mapa, pos):
				upgrades_livres = false
				break
		assert_true(upgrades_livres, "Mapa '%s': pontos de upgrade não caem em parede ou água" % nome)


func test_conectividade_rotas() -> void:
	for mapa in Mapas.MAPAS:
		var nome: String = mapa.get("nome", "")
		var inicios: Array = mapa.get("inicios", [])
		var todas_rotas_conectadas := true
		for i in inicios.size():
			for j in range(i + 1, inicios.size()):
				var rota := Caminhos.caminho(mapa, inicios[i], inicios[j])
				if rota.is_empty():
					todas_rotas_conectadas = false
					break
			if not todas_rotas_conectadas:
				break
		assert_true(todas_rotas_conectadas, "Mapa '%s': há rota conectada entre todas as posições iniciais" % nome)


func _ponto_em_parede(mapa: Dictionary, ponto: Vector2) -> bool:
	for parede in mapa.get("paredes", []):
		var retangulo: Rect2 = parede
		if retangulo.has_point(ponto):
			return true
	return false


func test_curva_e_dentro_arredondado() -> void:
	var quadrado := Rect2(100, 100, 100, 100)
	assert_true(is_equal_approx(Mapas.curva(quadrado), 50.0), "curva() retorna metade do menor lado")
	assert_true(Mapas.dentro_arredondado(quadrado, Vector2(150, 150)), "Centro do quadrado arredondado está dentro")
	assert_true(not Mapas.dentro_arredondado(quadrado, Vector2(102, 102)), "Canto extremo do círculo inscrito fica fora")
	assert_true(Mapas.dentro_arredondado(quadrado, Vector2(190, 150), 5.0), "Ponto interno respeita folga positiva")
	assert_true(not Mapas.dentro_arredondado(quadrado, Vector2(198, 150), 5.0), "Ponto próximo à borda sai com folga positiva")
	assert_true(Mapas.dentro_arredondado(quadrado, Vector2(205, 150), -10.0), "Folga negativa expande a área arredondada")


func test_agua_ponte_e_afundamento() -> void:
	var mapa_lago: Dictionary = Mapas.MAPAS[2]  # Lago
	assert_true(Mapas.na_agua(mapa_lago, Vector2(800, 320)), "Ponto no meio do lago está na água")
	assert_true(not Mapas.na_agua(mapa_lago, Vector2(800, 450)), "Ponto sobre a ponte central não está na água")
	assert_true(Mapas.ponte_em(mapa_lago, Vector2(800, 450)).has_area(), "ponte_em() retorna a ponte quando em cima dela")
	assert_true(not Mapas.ponte_em(mapa_lago, Vector2(800, 320)).has_area(), "ponte_em() retorna Rect2 vazio fora da ponte")
	assert_true(Mapas.afunda(mapa_lago, Vector2(800, 320) - Mapas.PES), "afunda() usa deslocamento dos pés")
	assert_true(not Mapas.afunda(mapa_lago, Vector2(800, 450) - Mapas.PES), "Não afunda em cima da ponte")
	assert_true(Mapas.caminho_afunda(mapa_lago, Vector2(800, 200), Vector2(800, 700)), "caminho_afunda() detecta água no meio do trajeto")
	assert_true(not Mapas.caminho_afunda(mapa_lago, Vector2(480, 450), Vector2(1120, 450)), "caminho_afunda() permite travessia pela ponte")


func test_pocas_luz_e_lugar_livre() -> void:
	var mapa_jardim: Dictionary = Mapas.MAPAS[0]  # Jardim
	assert_true(Mapas.na_poca(mapa_jardim, Vector2(395, 715)), "na_poca() detecta ponto dentro da poça")
	assert_true(not Mapas.na_poca(mapa_jardim, Vector2(800, 450)), "na_poca() retorna false fora das poças")
	assert_true(Mapas.na_luz(mapa_jardim, Vector2(800, 450)), "na_luz() detecta ponto na mancha de sol")
	assert_true(not Mapas.na_luz(mapa_jardim, Vector2(100, 100)), "na_luz() retorna false na sombra")
	assert_true(not Mapas.lugar_livre(mapa_jardim, Vector2(500, 250), 10.0), "lugar_livre() rejeita ponto dentro de parede")
	assert_true(not Mapas.lugar_livre(mapa_jardim, Vector2(200, 450), 10.0), "lugar_livre() rejeita ponto dentro da grama")
	assert_true(Mapas.lugar_livre(mapa_jardim, Vector2(800, 300), 10.0), "lugar_livre() aceita ponto aberto longe de obstáculos")

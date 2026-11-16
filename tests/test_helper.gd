extends RefCounted
## Base compartilhada e utilitários para as suítes de testes unitários e fuzzy.

const Camaleao := preload("res://scripts/camaleao.gd")
const Mapas := preload("res://scripts/mapas.gd")

var passed := 0
var failed := 0
var rng := RandomNumberGenerator.new()


func configurar_rng(seed_valor: int) -> void:
	rng.seed = seed_valor


func assert_true(condition: bool, message: String) -> void:
	if condition:
		print("  ✓ %s" % message)
		passed += 1
	else:
		printerr("  ✗ FALHA: %s" % message)
		failed += 1


func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		print("  ✓ %s" % message)
		passed += 1
	else:
		printerr("  ✗ FALHA: %s (esperado=%s, obtido=%s)" % [message, str(expected), str(actual)])
		failed += 1


func assert_approx(actual: float, expected: float, tolerancia: float, message: String) -> void:
	if absf(actual - expected) <= tolerancia:
		print("  ✓ %s" % message)
		passed += 1
	else:
		printerr("  ✗ FALHA: %s (esperado≈%s±%s, obtido=%s)" % [message, str(expected), str(tolerancia), str(actual)])
		failed += 1


func assert_quiet(condition: bool, message: String) -> bool:
	## Asserção silenciosa para loops de fuzzy testing: só imprime em caso de falha,
	## contabilizando um único resumo ao final do bloco de fuzzing.
	if not condition:
		printerr("  ✗ FALHA (FUZZ): %s" % message)
		failed += 1
		return false
	return true


static func arvore() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func criar_arena_teste(mapa: Dictionary = {}) -> Node2D:
	var tree := Engine.get_main_loop() as SceneTree
	var arena := Node2D.new()
	tree.root.add_child(arena)
	if not mapa.is_empty():
		for retangulo in mapa.get("paredes", []):
			adicionar_parede(arena, retangulo)
	return arena


static func adicionar_parede(arena: Node2D, retangulo: Rect2) -> StaticBody2D:
	var corpo := StaticBody2D.new()
	corpo.collision_layer = 1
	corpo.position = retangulo.get_center()
	var forma := CollisionShape2D.new()
	var caixa := RectangleShape2D.new()
	caixa.size = retangulo.size
	forma.shape = caixa
	corpo.add_child(forma)
	arena.add_child(corpo)
	return corpo


static func criar_camaleao_teste(arena: Node2D, pos: Vector2, mapa: Dictionary = {}, cor := Color.GREEN, bot := "parado") -> CharacterBody2D:
	var c := Camaleao.new()
	c.bot = bot
	c.controle = ""
	c.cor = cor
	c.position = pos
	c.direcao = Vector2.RIGHT
	c.mundo = arena
	c.mapa = mapa
	arena.add_child(c)
	return c


static func avancar_fisica(frames := 2) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for _i in frames:
		await tree.physics_frame


static func limpar_arena(arena: Node) -> void:
	if is_instance_valid(arena):
		if arena.get_parent():
			arena.get_parent().remove_child(arena)
		arena.free()

extends SceneTree
## Test Runner para execução headless de testes unitários e fuzzy testing no Godot 4.
## Execute com: godot --headless --path . -s tests/test_runner.gd
## Opções após `--`: --fuzz-seed=N --fuzz-iterations=N --suite=NOME


func _initialize() -> void:
	await process_frame

	var config := _ler_opcoes()

	print("\n==================================================")
	print("  BedLion - Bateria de Testes Automatizados")
	print("  Fuzz seed: %d | Fuzz iterações: %d" % [config["fuzz_seed"], config["fuzz_iterations"]])
	print("==================================================\n")

	# Inicializa nós de autoload quando o runner é executado como SceneTree direta
	if not root.has_node("Partida"):
		var no_partida = load("res://scripts/partida.gd").new()
		no_partida.name = "Partida"
		root.add_child(no_partida)
	if not root.has_node("Controles"):
		var no_controles = load("res://scripts/controles.gd").new()
		no_controles.name = "Controles"
		root.add_child(no_controles)

	var fuzz_suite = load("res://tests/test_fuzz.gd").new()
	fuzz_suite.fuzz_seed = config["fuzz_seed"]
	fuzz_suite.fuzz_iterations = config["fuzz_iterations"]

	var suites := [
		load("res://tests/test_mapas.gd").new(),
		load("res://tests/test_linguas.gd").new(),
		load("res://tests/test_controles.gd").new(),
		load("res://tests/test_partida.gd").new(),
		load("res://tests/test_caminhos.gd").new(),
		load("res://tests/test_camaleao.gd").new(),
		load("res://tests/test_entidades.gd").new(),
		load("res://tests/test_telas.gd").new(),
		fuzz_suite,
	]

	var filtro: String = config["suite"]
	var total_passed := 0
	var total_failed := 0

	for suite in suites:
		var suite_name: String = suite.get_suite_name()
		if filtro != "" and not suite_name.to_lower().contains(filtro.to_lower()):
			continue
		print("[%s]" % suite_name)
		await suite.run_tests()
		total_passed += suite.passed
		total_failed += suite.failed
		print("")

	print("==================================================")
	print("Resultado: %d passaram, %d falharam" % [total_passed, total_failed])
	print("==================================================\n")

	if total_failed == 0:
		quit(0)
	else:
		quit(1)


func _ler_opcoes() -> Dictionary:
	var fuzz_seed := 20261116
	var env_seed := OS.get_environment("FUZZ_SEED")
	if env_seed == "random":
		fuzz_seed = int(Time.get_unix_time_from_system())
	elif env_seed.is_valid_int():
		fuzz_seed = int(env_seed)

	var fuzz_iterations := 200
	var env_iter := OS.get_environment("FUZZ_ITERATIONS")
	if env_iter.is_valid_int() and int(env_iter) > 0:
		fuzz_iterations = int(env_iter)

	var suite_filtro := ""

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fuzz-seed="):
			var val := arg.substr("--fuzz-seed=".length())
			if val == "random":
				fuzz_seed = int(Time.get_unix_time_from_system())
			elif val.is_valid_int():
				fuzz_seed = int(val)
		elif arg.begins_with("--fuzz-iterations="):
			var val := arg.substr("--fuzz-iterations=".length())
			if val.is_valid_int() and int(val) > 0:
				fuzz_iterations = int(val)
		elif arg.begins_with("--suite="):
			suite_filtro = arg.substr("--suite=".length())

	return {
		"fuzz_seed": fuzz_seed,
		"fuzz_iterations": fuzz_iterations,
		"suite": suite_filtro,
	}

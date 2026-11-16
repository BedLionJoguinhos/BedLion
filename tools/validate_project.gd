extends SceneTree
## Valida todos os scripts (.gd) e cenas (.tscn) dentro de uma SceneTree real
## com autoloads inicializados, garantindo ausência de erros de parse/compilação.
## Execute com: godot --headless --path . -s tools/validate_project.gd

func _initialize() -> void:
	await process_frame

	if not root.has_node("Partida"):
		var no_partida = load("res://scripts/partida.gd").new()
		no_partida.name = "Partida"
		root.add_child(no_partida)
	if not root.has_node("Controles"):
		var no_controles = load("res://scripts/controles.gd").new()
		no_controles.name = "Controles"
		root.add_child(no_controles)

	var erros := 0
	var scripts_verificados := 0
	var cenas_verificadas := 0

	for dir_path in ["res://scripts", "res://tests"]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			printerr("FALHA: Não foi possível abrir diretório %s" % dir_path)
			erros += 1
			continue
		for arquivo in dir.get_files():
			if not arquivo.ends_with(".gd"):
				continue
			var caminho := "%s/%s" % [dir_path, arquivo]
			var recurso := load(caminho)
			if recurso == null or not (recurso is GDScript) or not (recurso as GDScript).can_instantiate():
				printerr("FALHA: Script inválido ou não instanciável: %s" % caminho)
				erros += 1
			else:
				scripts_verificados += 1

	var dir_cenas := DirAccess.open("res://scenes")
	if dir_cenas != null:
		for arquivo in dir_cenas.get_files():
			if not arquivo.ends_with(".tscn"):
				continue
			var caminho := "res://scenes/%s" % arquivo
			var cena := load(caminho)
			if cena == null or not (cena is PackedScene):
				printerr("FALHA: Cena inválida: %s" % caminho)
				erros += 1
				continue
			var instancia: Node = (cena as PackedScene).instantiate()
			if instancia == null:
				printerr("FALHA: Não foi possível instanciar cena: %s" % caminho)
				erros += 1
			else:
				cenas_verificadas += 1
				instancia.free()

	print("Validação concluída: %d scripts e %d cenas verificados (%d erros)." % [
		scripts_verificados, cenas_verificadas, erros
	])
	quit(0 if erros == 0 else 1)

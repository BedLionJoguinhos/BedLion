class_name Projetil
extends Node2D
## Tiro voando pela arena (as armas estão em armas.gd). Mata com 1 acerto,
## inclusive quem está invisível, e estoura a pele velha do poder "muda".
## Voa por cima da água. Tipos:
## - "bala": reta; some na parede ou no primeiro que acertar.
## - "laser": reta, mas quica nas paredes (até "quiques" vezes). Depois do
##   primeiro quique acerta até quem atirou.
## - "foguete": explode na parede, em alguém ou no fim do alcance; a explosão
##   pega todo mundo em volta (até quem atirou), menos quem está atrás de parede.
## - "bumerangue": vai até o alcance (ou até bater na parede) e volta para quem
##   jogou, atravessando paredes na volta. Mata na ida e na volta (nunca quem jogou).

const EfeitoTiro := preload("res://scripts/efeito_tiro.gd")

const RAIO_CAMALEAO := 18.0
const RAIOS := {"bala": 4.0, "laser": 5.0, "foguete": 9.0, "bumerangue": 11.0}
## O bumerangue some sozinho depois disso (se quem jogou sumiu, por exemplo).
const VIDA_MAXIMA_BUMERANGUE := 4.0

var tipo := "bala"
var direcao := Vector2.RIGHT
var velocidade := 1200.0
var alcance := 600.0
var quiques := 0
var raio_explosao := 0.0
var cor := Color.WHITE
var dono: Node2D = null  # quem atirou
var mundo: Node = null  # onde criar explosões e rastros (padrão: o pai)
var _percorrido := 0.0
var _quicou := false
var _voltando := false
var _tempo := 0.0
var _rastro: Array[Vector2] = []  # pontos de quique do laser (para o desenho)
var _acabou := false


func _ready() -> void:
	z_index = 1
	add_to_group("projeteis")
	if mundo == null:
		mundo = get_parent()
	_rastro.append(position)


func _physics_process(delta: float) -> void:
	if _acabou:
		return
	_tempo += delta
	if tipo == "bumerangue":
		_voar_bumerangue(delta)
	else:
		_voar_reto(delta)
	queue_redraw()


func _raio() -> float:
	return RAIOS.get(tipo, 4.0)


func _voar_reto(delta: float) -> void:
	var passo := velocidade * delta
	var nova := position + direcao * passo
	var batida := _parede_entre(position, nova)
	if not batida.is_empty():
		nova = batida["position"]
	if _acertar_no_caminho(position, nova):
		return
	position = nova
	_percorrido += passo
	if not batida.is_empty():
		if tipo == "laser" and quiques > 0:
			quiques -= 1
			_quicou = true
			var normal: Vector2 = batida["normal"]
			direcao = direcao.bounce(normal).normalized()
			position += normal * 2.0  # desgruda da parede
			_rastro.append(position)
		elif tipo == "foguete":
			position += (batida["normal"] as Vector2) * 4.0  # explode do lado de fora da parede
			_explodir()
			return
		else:
			_terminar()
			return
	if _percorrido >= alcance:
		if tipo == "foguete":
			_explodir()
		else:
			_terminar()


func _voar_bumerangue(delta: float) -> void:
	var passo := velocidade * delta
	if _voltando:
		if not (is_instance_valid(dono) and dono.vivo) or _tempo >= VIDA_MAXIMA_BUMERANGUE:
			_terminar()
			return
		direcao = position.direction_to(dono.position)
		var nova_volta := position.move_toward(dono.position, passo)
		_acertar_no_caminho(position, nova_volta)
		position = nova_volta
		if position.distance_to(dono.position) <= RAIO_CAMALEAO:
			_terminar()  # voltou para a mão
		return
	var nova := position + direcao * passo
	var batida := _parede_entre(position, nova)
	if not batida.is_empty():
		nova = batida["position"]
	_acertar_no_caminho(position, nova)
	position = nova
	_percorrido += passo
	if not batida.is_empty() or _percorrido >= alcance:
		_voltando = true


## Mata quem estiver no trecho de "de" até "ate". Devolve true se o tiro acabou
## ali (a bala some, o foguete explode; o bumerangue segue em frente).
func _acertar_no_caminho(de: Vector2, ate: Vector2) -> bool:
	var raio := _raio()
	var alvos: Array = []
	for outro in get_tree().get_nodes_in_group("camaleoes"):
		if not outro.vivo or (outro == dono and not _pode_acertar_dono()):
			continue
		var perto := Geometry2D.get_closest_point_to_segment(outro.position, de, ate)
		if perto.distance_to(outro.position) <= RAIO_CAMALEAO + raio:
			alvos.append([de.distance_to(perto), outro])
	for casca in get_tree().get_nodes_in_group("cascas"):
		if casca.is_queued_for_deletion():
			continue
		var perto_casca := Geometry2D.get_closest_point_to_segment(casca.position, de, ate)
		if perto_casca.distance_to(casca.position) <= RAIO_CAMALEAO + raio:
			alvos.append([de.distance_to(perto_casca), casca])
	if alvos.is_empty():
		return false
	alvos.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	if tipo == "foguete":
		var primeiro: Node2D = alvos[0][1]
		position = primeiro.position
		_explodir()
		return true
	if tipo == "bumerangue":
		for par in alvos:
			_matar(par[1])
		return false
	_matar(alvos[0][1])
	position = (alvos[0][1] as Node2D).position
	_terminar()
	return true


func _pode_acertar_dono() -> bool:
	return tipo == "laser" and _quicou


func _matar(alvo: Node) -> void:
	if alvo.has_method("morrer"):
		if alvo.vivo:
			alvo.morrer()
	elif alvo.has_method("estourar"):
		alvo.estourar()


func _explodir() -> void:
	for outro in get_tree().get_nodes_in_group("camaleoes"):
		if outro.vivo and position.distance_to(outro.position) <= raio_explosao + RAIO_CAMALEAO:
			if _parede_entre(position, outro.position).is_empty():
				_matar(outro)
	for casca in get_tree().get_nodes_in_group("cascas"):
		if not casca.is_queued_for_deletion() and position.distance_to(casca.position) <= raio_explosao + RAIO_CAMALEAO:
			_matar(casca)
	var efeito := EfeitoTiro.new()
	efeito.tipo = "explosao"
	efeito.raio = raio_explosao
	efeito.cor = cor
	efeito.position = position
	if is_instance_valid(mundo):
		mundo.add_child.call_deferred(efeito)
	_terminar()


func _terminar() -> void:
	_acabou = true
	queue_free()


## O tiro está voltando para a mão (bumerangue)?
func voltando() -> bool:
	return _voltando


func _parede_entre(de: Vector2, ate: Vector2) -> Dictionary:
	if de == ate:
		return {}
	var consulta := PhysicsRayQueryParameters2D.create(de, ate, 1)  # 1 = paredes
	consulta.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(consulta)


func _draw() -> void:
	var escuro := Color(0.08, 0.07, 0.1)
	match tipo:
		"laser":
			# Rastro do laser desde o último quique.
			var de := to_local(_rastro[_rastro.size() - 1])
			var rabo := -direcao * minf(60.0, position.distance_to(_rastro[_rastro.size() - 1]))
			if de.length() < rabo.length():
				rabo = de
			draw_line(rabo, Vector2.ZERO, Color(cor, 0.35), 9.0, true)
			draw_line(rabo, Vector2.ZERO, cor, 4.0, true)
			draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1, 0.9))
		"foguete":
			var lado := direcao.orthogonal()
			var corpo := PackedVector2Array([direcao * 13.0, lado * 6.0 - direcao * 8.0, -lado * 6.0 - direcao * 8.0])
			draw_circle(-direcao * 12.0, 6.0 + sin(_tempo * 40.0) * 1.5, Color(1.0, 0.6, 0.15, 0.85))
			draw_colored_polygon(corpo, cor.darkened(0.2))
			corpo.append(corpo[0])
			draw_polyline(corpo, escuro, 2.0, true)
		"bumerangue":
			var giro := _tempo * 22.0
			var a := Vector2.from_angle(giro) * 12.0
			var b := Vector2.from_angle(giro + 2.2) * 12.0
			draw_line(a, Vector2.ZERO, escuro, 7.0, true)
			draw_line(b, Vector2.ZERO, escuro, 7.0, true)
			draw_line(a, Vector2.ZERO, cor, 4.5, true)
			draw_line(b, Vector2.ZERO, cor, 4.5, true)
		_:
			draw_line(-direcao * 14.0, Vector2.ZERO, Color(1.0, 0.95, 0.6, 0.5), 3.0, true)
			draw_circle(Vector2.ZERO, _raio(), escuro)
			draw_circle(Vector2.ZERO, _raio() - 1.2, Color(1.0, 0.92, 0.55))

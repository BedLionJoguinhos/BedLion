class_name ArmaNaMao
extends Node2D
## A arma que um camaleão está segurando (fica dentro dele; os números estão em
## armas.gd). Com arma na mão, o botão do golpe atira para onde ele olha/mira.
## - Metralhadora: um aperto aquece por "aquecimento" s (o cano gira e brilha)
##   e depois sai a carga toda, um tiro a cada "intervalo".
## - Sniper: um aperto liga a mira laser por "mira" s; o tiro sai depois,
##   para onde ele estiver mirando naquela hora, e vai até a parede.
## - Bumerangue: só joga outro quando o anterior voltou ou sumiu.
## - Língua elétrica: sem munição; dura "duracao" s. O golpe vira uma lambida
##   elétrica de perto que mata. Não cai ao ficar invisível; usar faz aparecer.
## Quando a munição (ou o tempo) acaba, a arma some e o camaleão fica desarmado.

const Armas := preload("res://scripts/armas.gd")
const Projetil := preload("res://scripts/projetil.gd")
const EfeitoTiro := preload("res://scripts/efeito_tiro.gd")

const RAIO_CAMALEAO := 18.0
const DISTANCIA_COLADO := 50.0
const ESCURO := Color(0.08, 0.07, 0.1)

var tipo := "pistola"
var municao := 0
var tempo_restante := 0.0  # só a língua elétrica
var dono: CharacterBody2D = null
var _recarga := 0.0
var _aquecendo := -1.0  # metralhadora: >= 0 = segundos aquecendo
var _rajada := 0  # metralhadora: tiros que ainda vão sair
var _proximo_tiro := 0.0
var _mirando := -1.0  # sniper: >= 0 = segundos com a mira ligada
var _bumerangue: Node2D = null
var _tempo := 0.0
var _acabou := false


## Os números desta arma (armas.gd).
func dados() -> Dictionary:
	return Armas.ARMAS[tipo]


## Aquecendo, no meio da rajada ou mirando (o tiro ainda vai sair).
func ocupada() -> bool:
	return _aquecendo >= 0.0 or _rajada > 0 or _mirando >= 0.0


func bumerangue_voando() -> bool:
	return is_instance_valid(_bumerangue) and not _bumerangue.is_queued_for_deletion()


## Dá para atirar agora?
func pronta() -> bool:
	if _acabou or _recarga > 0.0 or ocupada() or bumerangue_voando():
		return false
	return Armas.por_tempo(tipo) or municao > 0


## Botão do golpe apertado com a arma na mão.
func apertar() -> void:
	if not pronta():
		return
	match tipo:
		"metralhadora":
			_aquecendo = 0.0
		"sniper":
			_mirando = 0.0
		"eletrica":
			_lambida()
		_:
			_disparar()


func _physics_process(delta: float) -> void:
	if _acabou or not is_instance_valid(dono):
		return
	_tempo += delta
	_recarga -= delta
	if Armas.por_tempo(tipo):
		tempo_restante -= delta
		if tempo_restante <= 0.0:
			_acabar()
			return
	if _aquecendo >= 0.0:
		_aquecendo += delta
		if _aquecendo >= float(dados()["aquecimento"]):
			_aquecendo = -1.0
			_rajada = municao
			_proximo_tiro = 0.0
	if _rajada > 0:
		_proximo_tiro -= delta
		if _proximo_tiro <= 0.0:
			_rajada -= 1
			_proximo_tiro = float(dados()["intervalo"])
			_disparar()
	if _mirando >= 0.0:
		_mirando += delta
		if _mirando >= float(dados()["mira"]):
			_mirando = -1.0
			_disparar_raio()
	if not Armas.por_tempo(tipo) and municao <= 0 and not ocupada() and not bumerangue_voando():
		_acabar()
		return
	queue_redraw()


## De onde o tiro sai (centro do camaleão; o projétil ignora quem atirou).
func _origem() -> Vector2:
	return dono.position


func _disparar() -> void:
	var d := dados()
	municao -= 1
	_recarga = float(d.get("recarga", 0.0))
	var direcao: Vector2 = dono.direcao
	var direcoes: Array[Vector2] = [direcao]
	if d.has("chumbos"):
		direcoes.clear()
		var abertura: float = d["espalhamento"]
		var quantos: int = d["chumbos"]
		for i in quantos:
			var f := float(i) / maxf(quantos - 1, 1) - 0.5
			direcoes.append(direcao.rotated(f * abertura + randf_range(-0.04, 0.04)))
	elif d.has("desvio"):
		direcoes[0] = direcao.rotated(randf_range(-float(d["desvio"]), float(d["desvio"])))
	for dir in direcoes:
		var tiro := Projetil.new()
		tiro.tipo = d["projetil"]
		tiro.direcao = dir
		tiro.velocidade = d["velocidade"]
		tiro.alcance = d["alcance"]
		tiro.quiques = d.get("quiques", 0)
		tiro.raio_explosao = d.get("raio_explosao", 0.0)
		tiro.cor = d["cor"]
		tiro.dono = dono
		tiro.mundo = dono.mundo
		tiro.position = _origem()
		dono.mundo.add_child(tiro)
		if tiro.tipo == "bumerangue":
			_bumerangue = tiro
	Controles.vibrar(dono.controle, 0.2, 0.35, 0.08)


## Sniper: acerta na hora o primeiro que estiver na linha, até a parede.
func _disparar_raio() -> void:
	var d := dados()
	municao -= 1
	_recarga = float(d["recarga"])
	var de := _origem()
	var ate := _ponto_da_mira()
	var alvo := _primeiro_na_linha(de, ate)
	if alvo:
		ate = alvo.position
		_matar(alvo)
	var rastro := EfeitoTiro.new()
	rastro.tipo = "rastro"
	rastro.cor = d["cor"]
	rastro.position = de
	rastro.ate = ate
	dono.mundo.add_child(rastro)
	Controles.vibrar(dono.controle, 0.4, 0.6, 0.12)


## Até onde a mira da sniper vai (a primeira parede na frente).
func _ponto_da_mira() -> Vector2:
	var de := _origem()
	var ate: Vector2 = de + dono.direcao * float(dados()["alcance"])
	var batida: Dictionary = dono._parede_entre(de, ate)
	if not batida.is_empty():
		ate = batida["position"]
	return ate


func _primeiro_na_linha(de: Vector2, ate: Vector2) -> Node2D:
	var melhor: Node2D = null
	var melhor_distancia := INF
	var candidatos: Array = []
	for outro in dono.get_tree().get_nodes_in_group("camaleoes"):
		if outro != dono and outro.vivo:
			candidatos.append(outro)
	for casca in dono.get_tree().get_nodes_in_group("cascas"):
		if not casca.is_queued_for_deletion():
			candidatos.append(casca)
	for alvo: Node2D in candidatos:
		var perto := Geometry2D.get_closest_point_to_segment(alvo.position, de, ate)
		if perto.distance_to(alvo.position) <= RAIO_CAMALEAO + 3.0:
			var distancia := de.distance_to(perto)
			if distancia < melhor_distancia:
				melhor = alvo
				melhor_distancia = distancia
	return melhor


## Língua elétrica: lambida de perto, na frente (ou colado, de qualquer lado). Mata.
func _lambida() -> void:
	var d := dados()
	_recarga = float(d["recarga"])
	if dono.invisivel:
		dono._aparecer()  # usar faz aparecer, como o golpe
	var alcance: float = d["alcance"]
	var abertura: float = d["abertura"]
	var direcao: Vector2 = dono.direcao
	var acertos: Array = []
	var candidatos: Array = []
	for outro in dono.get_tree().get_nodes_in_group("camaleoes"):
		if outro != dono and outro.vivo:
			candidatos.append(outro)
	for casca in dono.get_tree().get_nodes_in_group("cascas"):
		if not casca.is_queued_for_deletion():
			candidatos.append(casca)
	for alvo: Node2D in candidatos:
		var para_alvo := alvo.position - dono.position
		var distancia := para_alvo.length()
		var na_frente := absf(direcao.angle_to(para_alvo)) <= abertura
		if distancia > alcance or (distancia > DISTANCIA_COLADO and not na_frente):
			continue
		if dono._bate_em_parede(dono.position, alvo.position):
			continue
		acertos.append(alvo)
	var choque := EfeitoTiro.new()
	choque.tipo = "choque"
	choque.cor = d["cor"]
	choque.position = dono.position
	choque.ate = dono.position + direcao * alcance
	if not acertos.is_empty():
		choque.ate = (acertos[0] as Node2D).position
	dono.mundo.add_child(choque)
	for alvo in acertos:
		_matar(alvo)


func _matar(alvo: Node) -> void:
	if alvo.has_method("morrer"):
		if alvo.vivo:
			alvo.morrer()
	elif alvo.has_method("estourar"):
		alvo.estourar()


func _acabar() -> void:
	if _acabou:
		return
	_acabou = true
	if is_instance_valid(dono) and dono.has_method("_arma_acabou"):
		dono._arma_acabou(self)


func _draw() -> void:
	if not is_instance_valid(dono):
		return
	var direcao: Vector2 = dono.direcao
	if _mirando >= 0.0:
		# Mira laser da sniper: aparece antes do tiro sair (dá para fugir).
		var fim := to_local(_ponto_da_mira())
		var forca := 0.35 + 0.65 * _mirando / float(dados()["mira"])
		draw_line(Vector2.ZERO, fim, Color(1.0, 0.15, 0.15, 0.25 * forca), 6.0, true)
		draw_line(Vector2.ZERO, fim, Color(1.0, 0.2, 0.2, 0.9 * forca), 1.6, true)
		draw_circle(fim, 4.0, Color(1.0, 0.2, 0.2, forca))
	var na_mao := direcao * 20.0 + Vector2(0, 6)
	var giro := 0.0
	if _aquecendo >= 0.0:
		var t := _aquecendo / float(dados()["aquecimento"])
		giro = _tempo * 40.0 * t
		draw_circle(na_mao + direcao * 22.0, 6.0 + 8.0 * t, Color(1.0, 0.7, 0.2, 0.25 + 0.45 * t))
	desenhar(self, tipo, na_mao, direcao.angle(), 1.0, giro)
	_desenhar_carga()


## Bolinhas de munição em cima da cabeça (ou o tempo que falta, na elétrica).
func _desenhar_carga() -> void:
	var cor: Color = dados()["cor"]
	var y := -54.0
	if Armas.por_tempo(tipo):
		var t := clampf(tempo_restante / float(dados()["duracao"]), 0.0, 1.0)
		draw_arc(Vector2(0, y), 7.0, 0.0, TAU, 20, Color(ESCURO, 0.6), 4.0, true)
		draw_arc(Vector2(0, y), 7.0, -PI / 2.0, -PI / 2.0 + TAU * t, 20, cor.lightened(0.3), 3.0, true)
		return
	var quantas := maxi(municao, 0)
	var espaco := 7.0
	var x0 := -espaco * (quantas - 1) / 2.0
	for i in quantas:
		draw_circle(Vector2(x0 + i * espaco, y), 3.0, ESCURO)
		draw_circle(Vector2(x0 + i * espaco, y), 2.0, cor.lightened(0.4))


## Desenho simples de cada arma, apontando para "angulo" (usado na mão e no chão).
static func desenhar(item: CanvasItem, tipo_arma: String, onde: Vector2, angulo: float, escala := 1.0, giro := 0.0) -> void:
	var cor: Color = Armas.ARMAS.get(tipo_arma, Armas.ARMAS["pistola"])["cor"]
	# Desenhada sempre "de pé": se apontar para a esquerda, espelha na vertical.
	var espelho := -1.0 if absf(wrapf(angulo, -PI, PI)) > PI / 2.0 else 1.0
	item.draw_set_transform(onde, angulo, Vector2(escala, escala * espelho))
	match tipo_arma:
		"espingarda":
			_retangulo(item, Rect2(-10, -3, 26, 5), cor.darkened(0.3))
			_retangulo(item, Rect2(-14, -2, 8, 8), cor)
		"metralhadora":
			_retangulo(item, Rect2(-10, -5, 18, 9), cor)
			for i in 3:
				var y := sin(giro + i * 2.1) * 2.5
				_retangulo(item, Rect2(8, y - 1.2, 14, 2.4), cor.darkened(0.4))
		"sniper":
			_retangulo(item, Rect2(-12, -2, 34, 4), cor.darkened(0.35))
			_retangulo(item, Rect2(-2, -7, 10, 4), cor)
			_retangulo(item, Rect2(-14, -1, 8, 7), cor)
		"laser":
			_retangulo(item, Rect2(-8, -5, 18, 10), cor.darkened(0.2))
			item.draw_circle(Vector2(13, 0), 4.0, ESCURO)
			item.draw_circle(Vector2(13, 0), 2.8, Color(1, 0.8, 0.9))
		"bazuca":
			_retangulo(item, Rect2(-16, -6, 34, 12), cor)
			_retangulo(item, Rect2(14, -7, 5, 14), cor.darkened(0.4))
		"bumerangue":
			item.draw_line(Vector2(-8, 8), Vector2(2, -2), ESCURO, 7.0, true)
			item.draw_line(Vector2(2, -2), Vector2(14, 4), ESCURO, 7.0, true)
			item.draw_line(Vector2(-8, 8), Vector2(2, -2), cor, 4.5, true)
			item.draw_line(Vector2(2, -2), Vector2(14, 4), cor, 4.5, true)
		"eletrica":
			# Raiozinho.
			var raio := PackedVector2Array([Vector2(-6, -8), Vector2(4, -8), Vector2(0, -1), Vector2(8, -1), Vector2(-4, 10), Vector2(-1, 2), Vector2(-8, 2)])
			item.draw_colored_polygon(raio, cor)
			raio.append(raio[0])
			item.draw_polyline(raio, ESCURO, 1.5, true)
		_:
			_retangulo(item, Rect2(-4, -3, 16, 6), cor)
			_retangulo(item, Rect2(-6, -1, 6, 9), cor.darkened(0.25))
	item.draw_set_transform(Vector2.ZERO)


static func _retangulo(item: CanvasItem, retangulo: Rect2, cor: Color) -> void:
	item.draw_rect(retangulo.grow(1.2), ESCURO, true)
	item.draw_rect(retangulo, cor, true)

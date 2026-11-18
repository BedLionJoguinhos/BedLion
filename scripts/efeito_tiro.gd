class_name EfeitoTiro
extends Node2D
## Efeitos rápidos das armas (armas.gd):
## - "rastro": risco do tiro da sniper, da posição até "ate".
## - "explosao": bola de fogo da bazuca, do tamanho de "raio".
## - "choque": zigue-zague da língua elétrica, da posição até "ate".

const DURACOES := {"rastro": 0.3, "explosao": 0.45, "choque": 0.2}

var tipo := "rastro"
var ate := Vector2.ZERO  # no mundo
var raio := 100.0
var cor := Color.WHITE
var _tempo := 0.0
var _zigue: Array[float] = []


func _ready() -> void:
	z_index = 2
	for i in 7:
		_zigue.append(randf_range(-1.0, 1.0))


func _process(delta: float) -> void:
	_tempo += delta
	if _tempo >= DURACOES.get(tipo, 0.3):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = _tempo / float(DURACOES.get(tipo, 0.3))
	var fim := to_local(ate)
	match tipo:
		"explosao":
			var r := raio * lerpf(0.5, 1.0, minf(t * 3.0, 1.0))
			draw_circle(Vector2.ZERO, r, Color(1.0, 0.55, 0.15, 0.55 * (1.0 - t)))
			draw_circle(Vector2.ZERO, r * 0.65, Color(1.0, 0.85, 0.3, 0.75 * (1.0 - t)))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(0.25, 0.2, 0.18, 0.6 * (1.0 - t)), 4.0, true)
		"choque":
			var pontos := PackedVector2Array([Vector2.ZERO])
			var lado := fim.normalized().orthogonal()
			for i in _zigue.size():
				var f := float(i + 1) / (_zigue.size() + 1)
				pontos.append(fim * f + lado * _zigue[i] * 10.0)
			pontos.append(fim)
			draw_polyline(pontos, Color(cor, 0.4 * (1.0 - t)), 9.0, true)
			draw_polyline(pontos, Color(1, 1, 1, 1.0 - t), 3.0, true)
		_:
			draw_line(Vector2.ZERO, fim, Color(cor, 0.35 * (1.0 - t)), 10.0, true)
			draw_line(Vector2.ZERO, fim, Color(1, 1, 1, 1.0 - t), 3.0, true)

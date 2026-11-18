class_name EfeitoAtordoado
extends Node2D
## Passarinhos girando em cima da cabeça de quem está atordoado (golpe ou
## língua, ver armas.gd). Fica no mundo e não dentro do camaleão: assim aparece
## até em cima de quem está invisível, e vira pista de onde ele está.

const QUANTOS := 3
const ALTURA := -44.0  # acima da cabeça
const RAIO_GIRO := Vector2(20.0, 7.0)  # elipse (achatada, como um halo)

var alvo: Node2D = null
var _tempo := 0.0


func _ready() -> void:
	z_index = 2
	if is_instance_valid(alvo):
		position = alvo.position


func _process(delta: float) -> void:
	if not is_instance_valid(alvo) or not alvo.vivo or not alvo.atordoado():
		queue_free()
		return
	_tempo += delta
	position = alvo.position
	queue_redraw()


func _draw() -> void:
	var escuro := Color(0.08, 0.07, 0.1)
	for i in QUANTOS:
		var angulo := _tempo * 6.0 + TAU * i / QUANTOS
		var onde := Vector2(cos(angulo) * RAIO_GIRO.x, ALTURA + sin(angulo) * RAIO_GIRO.y)
		var bate := sin(_tempo * 30.0 + i) * 2.5  # asinhas batendo
		var olhando := -1.0 if sin(angulo) > 0.0 else 1.0
		# Passarinho: bolinha amarela com duas asinhas e um bico.
		draw_line(onde, onde + Vector2(-6.0, -3.5 + bate), escuro, 2.0, true)
		draw_line(onde, onde + Vector2(6.0, -3.5 + bate), escuro, 2.0, true)
		draw_circle(onde, 5.0, escuro)
		draw_circle(onde, 4.0, Color(1.0, 0.86, 0.25))
		draw_circle(onde + Vector2(4.6 * olhando, 0.5), 1.8, Color(0.95, 0.5, 0.15))

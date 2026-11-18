class_name ArmaNoChao
extends Area2D
## Arma largada no chão (tipos em armas.gd): as que aparecem no mapa, as que
## caem de quem levou um golpe ou ficou invisível, e as de quem morreu. Guarda a
## munição (ou o tempo, na língua elétrica) que sobrou. Quem estiver visível,
## desarmado e acordado pega passando por cima, ou puxa com a língua.

const Armas := preload("res://scripts/armas.gd")
const ArmaNaMao := preload("res://scripts/arma_na_mao.gd")

## Igual ao das bolhas de poder (a língua usa o mesmo tamanho para pegar).
const RAIO := 14.0
const TEMPO_AFUNDAR := 0.6

var tipo := "pistola"
var municao := -1  # -1 = cheia (a do armas.gd)
var tempo_restante := -1.0  # língua elétrica; -1 = cheia
var na_lingua := false  # sendo trazida pela língua de alguém
var _tempo := 0.0
var _afundando := -1.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # camaleões
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = RAIO
	forma.shape = circulo
	add_child(forma)
	add_to_group("itens_no_chao")
	add_to_group("armas_no_chao")
	z_index = -1
	var dados: Dictionary = Armas.ARMAS[tipo]
	if municao < 0:
		municao = int(dados.get("municao", 0))
	if tempo_restante < 0.0:
		tempo_restante = float(dados.get("duracao", 0.0))


func _physics_process(delta: float) -> void:
	_tempo += delta
	queue_redraw()
	z_index = 1 if na_lingua else -1
	if _afundando >= 0.0:
		_afundando += delta
		scale = Vector2.ONE * maxf(1.0 - _afundando / TEMPO_AFUNDAR, 0.0)
		modulate.a = scale.x
		if _afundando >= TEMPO_AFUNDAR:
			queue_free()
		return
	if na_lingua:
		return
	for corpo in get_overlapping_bodies():
		if corpo.has_method("pegar_arma") and corpo.pegar_arma(self):
			queue_free()
			return


## Caiu na água: encolhe e some.
func afundar() -> void:
	if _afundando < 0.0:
		_afundando = 0.0
		remove_from_group("itens_no_chao")
		remove_from_group("armas_no_chao")


func _draw() -> void:
	var cor: Color = Armas.ARMAS[tipo]["cor"]
	var pulso := 0.5 + 0.5 * sin(_tempo * 5.0)
	# Brilho no chão (diferente da bolha dos poderes: um losango que pisca).
	var r := RAIO + 5.0 + 4.0 * pulso
	var losango := PackedVector2Array([Vector2(0, -r * 0.6), Vector2(r, 0), Vector2(0, r * 0.6), Vector2(-r, 0)])
	draw_colored_polygon(losango, Color(1.0, 0.92, 0.5, 0.25 + 0.2 * pulso))
	draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, RAIO, Color(0, 0, 0, 0.25))  # sombra
	draw_set_transform(Vector2.ZERO)
	var flutua := Vector2(0, sin(_tempo * 3.0) * 2.0 - 4.0)
	ArmaNaMao.desenhar(self, tipo, flutua, -0.3, 1.4)

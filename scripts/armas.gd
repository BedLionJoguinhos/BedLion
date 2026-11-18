class_name Armas
extends RefCounted
## Arsenal e regras de combate num lugar só: para ajustar o jogo, mexa aqui.
##
## Quem mata são só as armas que aparecem no mapa (todas matam com 1 acerto).
## O golpe e a língua só ATORDOAM:
## - Golpe: atordoa por TEMPO_ATORDOADO, empurra um pouco e derruba a arma de
##   quem levou (qualquer um pega, até puxando com a língua).
## - Língua: puxa como sempre; se a puxada chega até a boca, quem foi puxado
##   fica atordoado (não derruba a arma).
## Depois de um atordoamento a pessoa fica IMUNE_ATORDOAR segundos sem poder
## ser atordoada de novo (para ninguém ficar preso para sempre). Um golpe em
## quem JÁ está atordoado ainda derruba a arma, mas não aumenta o tempo.
##
## Ninguém começa armado (a "arma pequena" do começo virou o golpe, que só
## atordoa). Com arma na mão, o botão do golpe atira. Ficar invisível larga a
## arma no chão, menos a língua elétrica, que é de perto: invisível só mata de perto.
##
## Campos de cada arma em ARMAS:
## - nome, cor: como aparece (texto ao pegar, desenho).
## - peso: chance de aparecer no mapa (maior = mais comum). Armas fortes têm peso baixo.
## - municao: tiros (ou arremessos). Acabou, a arma some e o camaleão fica desarmado.
## - recarga: segundos entre um tiro e outro.
## - projetil: "bala", "laser", "foguete" ou "bumerangue" (projetil.gd);
##   "raio" = acerta na hora em linha reta até a parede (sniper);
##   "choque" = lambida de perto (língua elétrica).
## - alcance: até onde o tiro vai (px). velocidade: px/s do projétil.
## Específicos: chumbos/espalhamento (espingarda), aquecimento/intervalo
## (metralhadora), mira (sniper), quiques (laser), raio_explosao (bazuca),
## duracao/abertura/fica_invisivel (língua elétrica).

## --- Atordoar ---------------------------------------------------------------
const TEMPO_ATORDOADO := 1.5
## Depois de acordar, quanto tempo fica sem poder ser atordoado de novo.
const IMUNE_ATORDOAR := 1.0
## Velocidade inicial do empurrão do golpe (px/s); vai freando em FREIO_EMPURRAO.
## Com estes números o empurrão anda uns 70 px (e pode jogar alguém na água).
const EMPURRAO_GOLPE := 520.0
const FREIO_EMPURRAO := 1900.0
## A arma derrubada cai a esta distância, para o lado do empurrão.
const DISTANCIA_QUEDA := 38.0

## --- Aparecer no mapa ---------------------------------------------------------
## No começo da rodada: 1 arma para cada JOGADORES_POR_ARMA jogadores (arredondando
## para cima): 2 ou 3 jogadores = 1 arma, 4 jogadores = 2 armas.
const JOGADORES_POR_ARMA := 3
## De tanto em tanto tempo aparece mais uma (para ninguém ficar parado esperando),
## se tiver menos de MAX_ARMAS_NO_CHAO armas largadas no chão.
const INTERVALO_ARMA := 10.0
const MAX_ARMAS_NO_CHAO := 2

const ARMAS := {
	"pistola":
	{
		"nome": "Pistola",
		"cor": Color(0.75, 0.78, 0.82),
		"peso": 10,
		"municao": 5,
		"recarga": 0.35,
		"projetil": "bala",
		"alcance": 620.0,
		"velocidade": 1300.0,
	},
	"espingarda":
	{
		"nome": "Espingarda",
		"cor": Color(0.72, 0.5, 0.3),
		"peso": 7,
		"municao": 3,
		"recarga": 1.1,
		"projetil": "bala",
		"alcance": 280.0,
		"velocidade": 1100.0,
		"chumbos": 6,
		"espalhamento": deg_to_rad(30.0),  # abertura total do leque
	},
	"metralhadora":
	{
		"nome": "Metralhadora",
		"cor": Color(0.45, 0.5, 0.42),
		"peso": 4,
		"municao": 10,  # uma carga só: aperta uma vez, aquece e sai tudo
		"aquecimento": 1.0,
		"intervalo": 0.15,
		"desvio": 0.07,  # radianos de tremida em cada tiro
		"recarga": 0.0,
		"projetil": "bala",
		"alcance": 700.0,
		"velocidade": 1400.0,
	},
	"sniper":
	{
		"nome": "Sniper",
		"cor": Color(0.3, 0.42, 0.75),
		"peso": 3,
		"municao": 3,
		"recarga": 1.5,
		"mira": 0.5,  # mira laser na tela antes do tiro sair
		"projetil": "raio",
		"alcance": 4000.0,  # na prática, infinito (vai até a parede)
	},
	"laser":
	{
		"nome": "Laser",
		"cor": Color(1.0, 0.25, 0.55),
		"peso": 5,
		"municao": 3,
		"recarga": 0.5,
		"projetil": "laser",
		"alcance": 2200.0,  # caminho total, somando os quiques
		"velocidade": 950.0,
		"quiques": 3,  # depois de quicar, acerta até quem atirou
	},
	"bazuca":
	{
		"nome": "Bazuca",
		"cor": Color(0.4, 0.55, 0.3),
		"peso": 2,
		"municao": 2,
		"recarga": 1.8,
		"projetil": "foguete",
		"alcance": 1100.0,
		"velocidade": 620.0,
		"raio_explosao": 115.0,  # pega todo mundo na área, até quem atirou
	},
	"bumerangue":
	{
		"nome": "Bumerangue",
		"cor": Color(0.9, 0.7, 0.3),
		"peso": 6,
		"municao": 3,
		"recarga": 0.6,
		"projetil": "bumerangue",  # só lança outro quando o anterior voltar ou sumir
		"alcance": 420.0,
		"velocidade": 900.0,
	},
	"eletrica":
	{
		"nome": "Língua elétrica",
		"cor": Color(0.45, 0.8, 1.0),
		"peso": 4,
		"duracao": 8.0,  # sem munição: dura isso e acaba
		"recarga": 0.45,
		"projetil": "choque",
		"alcance": 125.0,
		"abertura": deg_to_rad(50.0),  # para cada lado da mira
		"fica_invisivel": true,  # não cai ao ficar invisível (é de perto)
	},
}


## Quantas armas aparecem no começo da rodada para tantos jogadores.
static func armas_no_inicio(jogadores: int) -> int:
	return maxi(1, ceili(float(jogadores) / JOGADORES_POR_ARMA))


## Sorteia um tipo de arma pelo "peso" (as fortes saem menos).
static func sortear() -> String:
	var total := 0
	for tipo: String in ARMAS:
		total += int(ARMAS[tipo]["peso"])
	var sorteio := randi() % maxi(total, 1)
	for tipo: String in ARMAS:
		sorteio -= int(ARMAS[tipo]["peso"])
		if sorteio < 0:
			return tipo
	return "pistola"


## A arma acaba por tempo (e não por munição)?
static func por_tempo(tipo: String) -> bool:
	return ARMAS[tipo].has("duracao")

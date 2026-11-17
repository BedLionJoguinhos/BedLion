extends Node
## Registra no InputMap os controles de todo mundo ao iniciar o jogo.
## Cada jogador usa um "controle", que é o prefixo das ações dele:
## "teclado1", "teclado2" ou "pad0", "pad1"... (um por controle de videogame).
## Para trocar uma tecla ou botão, basta mudar os dicionários abaixo.

const TECLADOS := {
	"teclado1":
	{
		"cima": [KEY_W],
		"baixo": [KEY_S],
		"esquerda": [KEY_A],
		"direita": [KEY_D],
		"golpe": [KEY_F],
		"invisivel": [KEY_G],
		"lingua": [KEY_H],
	},
	"teclado2":
	{
		"cima": [KEY_UP],
		"baixo": [KEY_DOWN],
		"esquerda": [KEY_LEFT],
		"direita": [KEY_RIGHT],
		"golpe": [KEY_PERIOD, KEY_KP_1],
		"invisivel": [KEY_COMMA, KEY_KP_2],
		# A tecla depois do ponto: "/" no teclado americano, ";" no brasileiro.
		"lingua": [KEY_SLASH, KEY_SEMICOLON, KEY_KP_3],
	},
}

## Botões do controle (padrão Xbox: A para invisibilidade).
const BOTOES_PAD := {
	"invisivel": [JOY_BUTTON_A],
}
## Eixos do controle: [eixo, sentido]. Analógico esquerdo move; LT é a língua e RT é o golpe.
const EIXOS_PAD := {
	"cima": [JOY_AXIS_LEFT_Y, -1.0],
	"baixo": [JOY_AXIS_LEFT_Y, 1.0],
	"esquerda": [JOY_AXIS_LEFT_X, -1.0],
	"direita": [JOY_AXIS_LEFT_X, 1.0],
	"lingua": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	"golpe": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}
## Eixos do analógico direito (mira da língua e do golpe): [eixo, sentido].
const EIXOS_MIRA_PAD := {
	"mira_cima": [JOY_AXIS_RIGHT_Y, -1.0],
	"mira_baixo": [JOY_AXIS_RIGHT_Y, 1.0],
	"mira_esquerda": [JOY_AXIS_RIGHT_X, -1.0],
	"mira_direita": [JOY_AXIS_RIGHT_X, 1.0],
}
## Teclas e botões extras nas ações nativas de interface (menus e configurações).
const INTERFACE_TECLAS := {
	"ui_up": [KEY_W],
	"ui_down": [KEY_S],
	"ui_left": [KEY_A],
	"ui_right": [KEY_D],
	"ui_accept": [KEY_F],
	"ui_cancel": [KEY_G],
}
const INTERFACE_BOTOES_PAD := {
	"ui_up": [JOY_BUTTON_DPAD_UP],
	"ui_down": [JOY_BUTTON_DPAD_DOWN],
	"ui_left": [JOY_BUTTON_DPAD_LEFT],
	"ui_right": [JOY_BUTTON_DPAD_RIGHT],
	"ui_accept": [JOY_BUTTON_A],
	"ui_cancel": [JOY_BUTTON_B],
}
const INTERFACE_EIXOS_PAD := {
	"ui_up": [JOY_AXIS_LEFT_Y, -1.0],
	"ui_down": [JOY_AXIS_LEFT_Y, 1.0],
	"ui_left": [JOY_AXIS_LEFT_X, -1.0],
	"ui_right": [JOY_AXIS_LEFT_X, 1.0],
}
## Quantos controles de videogame são registrados (pad0 até pad7).
const MAX_PADS := 8
## Zona morta do analógico esquerdo na arena (evita drift sem perder precisão).
const ZONA_MORTA := 0.22
## Mesmo para o analógico direito (mira da língua e do golpe), medido no círculo todo.
const ZONA_MORTA_MIRA := 0.35
## Zona morta mais alta na navegação de menus com o analógico esquerdo.
const ZONA_MORTA_INTERFACE := 0.45
## Nomes curtos dos botões para mostrar na tela (lobby).
const NOMES_TECLADO := {
	"teclado1": {"golpe": "F", "invisivel": "G", "lingua": "H", "lados": "A/D", "cima_baixo": "W/S"},
	"teclado2": {"golpe": ".", "invisivel": ",", "lingua": ";", "lados": "direcional", "cima_baixo": "direcional"},
}
const NOMES_PAD := {"golpe": "RT", "invisivel": "A", "lingua": "LT", "pausa": "Start", "lados": "analógico", "cima_baixo": "analógico"}


func _ready() -> void:
	for teclado in TECLADOS:
		for acao in TECLADOS[teclado]:
			var nome := _criar_acao("%s_%s" % [teclado, acao], ZONA_MORTA)
			for tecla in TECLADOS[teclado][acao]:
				var evento := InputEventKey.new()
				evento.keycode = tecla
				if not InputMap.action_has_event(nome, evento):
					InputMap.action_add_event(nome, evento)

	# Uma ação separada para cada controle (o "device" diz de qual controle é),
	# assim cada jogador só responde ao próprio controle.
	for pad in MAX_PADS:
		for acao in BOTOES_PAD:
			var nome := _criar_acao("pad%d_%s" % [pad, acao], ZONA_MORTA)
			for botao in BOTOES_PAD[acao]:
				var evento := InputEventJoypadButton.new()
				evento.device = pad
				evento.button_index = botao
				if not InputMap.action_has_event(nome, evento):
					InputMap.action_add_event(nome, evento)
		for acao in EIXOS_PAD:
			var nome := _criar_acao("pad%d_%s" % [pad, acao], ZONA_MORTA)
			var eixo: Array = EIXOS_PAD[acao]
			var movimento := InputEventJoypadMotion.new()
			movimento.device = pad
			movimento.axis = eixo[0]
			movimento.axis_value = eixo[1]
			if not InputMap.action_has_event(nome, movimento):
				InputMap.action_add_event(nome, movimento)
		for acao in EIXOS_MIRA_PAD:
			var nome := _criar_acao("pad%d_%s" % [pad, acao], ZONA_MORTA_MIRA)
			var eixo: Array = EIXOS_MIRA_PAD[acao]
			var movimento := InputEventJoypadMotion.new()
			movimento.device = pad
			movimento.axis = eixo[0]
			movimento.axis_value = eixo[1]
			if not InputMap.action_has_event(nome, movimento):
				InputMap.action_add_event(nome, movimento)

	_registrar_interface()


func _registrar_interface() -> void:
	for acao in INTERFACE_TECLAS:
		_criar_acao(acao, ZONA_MORTA_INTERFACE)
		for tecla in INTERFACE_TECLAS[acao]:
			var evento := InputEventKey.new()
			evento.keycode = tecla
			if not InputMap.action_has_event(acao, evento):
				InputMap.action_add_event(acao, evento)
	for acao in INTERFACE_BOTOES_PAD:
		_criar_acao(acao, ZONA_MORTA_INTERFACE)
		for botao in INTERFACE_BOTOES_PAD[acao]:
			var evento := InputEventJoypadButton.new()
			evento.device = -1
			evento.button_index = botao
			if not InputMap.action_has_event(acao, evento):
				InputMap.action_add_event(acao, evento)
	for acao in INTERFACE_EIXOS_PAD:
		_criar_acao(acao, ZONA_MORTA_INTERFACE)
		var eixo: Array = INTERFACE_EIXOS_PAD[acao]
		var movimento := InputEventJoypadMotion.new()
		movimento.device = -1
		movimento.axis = eixo[0]
		movimento.axis_value = eixo[1]
		if not InputMap.action_has_event(acao, movimento):
			InputMap.action_add_event(acao, movimento)


func _criar_acao(nome: String, zona_morta := ZONA_MORTA) -> String:
	if not InputMap.has_action(nome):
		InputMap.add_action(nome, zona_morta)
	else:
		InputMap.action_set_deadzone(nome, zona_morta)
	return nome


## Retorna o índice do dispositivo gamepad para um prefixo "padN" (-1 se não for controle).
static func dispositivo_de(controle: String) -> int:
	if not controle.begins_with("pad"):
		return -1
	var sufixo := controle.substr(3)
	if not sufixo.is_valid_int():
		return -1
	var indice := int(sufixo)
	return indice if indice >= 0 and indice < MAX_PADS else -1


static func eh_pad(controle: String) -> bool:
	return dispositivo_de(controle) >= 0


static func eh_xbox(aparelho: int) -> bool:
	if aparelho < 0:
		return false
	var nome := Input.get_joy_name(aparelho).to_lower()
	return nome.contains("xbox") or nome.contains("x-box") or nome.contains("xinput")


static func tem_controle_conectado() -> bool:
	for pad in Input.get_connected_joypads():
		if pad >= 0 and pad < MAX_PADS:
			return true
	return false


## Aciona vibração (rumble) apenas no controle correspondente ao jogador, se conectado.
static func vibrar(controle: String, fraco: float, forte: float, duracao: float) -> void:
	var aparelho := dispositivo_de(controle)
	if aparelho < 0 or duracao <= 0.0:
		return
	if not Input.get_connected_joypads().has(aparelho):
		return
	Input.start_joy_vibration(aparelho, clampf(fraco, 0.0, 1.0), clampf(forte, 0.0, 1.0), duracao)


static func parar_vibracao(controle: String) -> void:
	var aparelho := dispositivo_de(controle)
	if aparelho >= 0 and Input.get_connected_joypads().has(aparelho):
		Input.stop_joy_vibration(aparelho)


## Texto curto de ajuda para mostrar na tela (golpe / invisível / língua).
func descricao(controle: String) -> String:
	match controle:
		"teclado1":
			return "WASD, F/G/H"
		"teclado2":
			return "setas, . / , / ;"
	var aparelho := dispositivo_de(controle)
	if aparelho >= 0:
		var rotulo := "Xbox %d" % (aparelho + 1) if eh_xbox(aparelho) else "controle %d" % (aparelho + 1)
		return "%s, RT/A/LT" % rotulo
	return "bot"


## Nome curto do botão de uma ação para mostrar na tela (ex.: "F", ".", "A").
func nome_botao(controle: String, acao: String) -> String:
	if NOMES_TECLADO.has(controle):
		return NOMES_TECLADO[controle].get(acao, "?")
	return NOMES_PAD.get(acao, "?")

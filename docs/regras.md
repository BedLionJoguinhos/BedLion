# Regras do Jogo

Este documento descreve os objetivos, a mecânica das partidas e as interações do jogo.

---

## 1. Objetivo e Pontuação

* **Participantes:** De 2 a 4 jogadores na mesma tela (vagas restantes podem ser preenchidas por bots).
* **Estrutura:** A partida é disputada em rodadas sucessivas.
* **Vitória na Rodada:** O último jogador sobrevivente na arena vence a rodada e soma 1 ponto.
* **Vitória na Partida:** O primeiro jogador a atingir a pontuação limite (padrão de 5 pontos) vence o confronto.

---

## 2. Ações do Jogador

Cada camaleão dispõe das seguintes ações básicas:

### Movimentação
* Deslocamento contínuo em todas as direções via teclado ou controle.

### Língua (Tração)
* Disparo em linha reta na direção em que o camaleão está apontado.
* Ao atingir um oponente, puxa-o em direção ao atacante. Se a puxada chegar até a boca, o puxado fica **atordoado**.
* A língua não elimina o adversário; o objetivo é puxá-lo para perto, atordoar ou arrastá-lo para perigos do cenário.
* A língua também puxa poderes e armas do chão.
* Enquanto a língua estiver lançada (ida, volta ou puxando), o camaleão atacante fica imóvel.
* A linha da língua pode ser cortada se outro jogador cruzar o trajeto.
* Colisões com muros interrompem a língua e cancelam a tração.

### Golpe de Curto Alcance
* Ataque corpo a corpo frontal.
* **Não mata:** atordoa o adversário por 1,5 s, empurra um pouco e derruba a arma dele no chão (qualquer um pode pegar).
* Atordoado não anda, não ataca, não usa a língua nem fica invisível. Passarinhos giram sobre a cabeça dele (inclusive se estiver invisível, o que serve de pista).
* Depois de acordar, fica 1 s imune a novo atordoamento. Golpear quem já está atordoado ainda derruba a arma, mas não aumenta o tempo.
* Possui tempo de recarga entre acionamentos sucessivos.
* Com uma arma na mão, o mesmo botão atira.

### Camuflagem (Invisibilidade)
* Ativada ao segurar o botão de invisibilidade pelo tempo de carga necessário.
* Torna o camaleão invisível para todos os jogadores na tela.
* Ao sumir, o camaleão larga o poder e a arma no chão (exceto a língua elétrica, que é de perto: invisível só mata de perto).
* Executar um ataque ou sofrer determinadas ações cancela o efeito de camuflagem imediatamente.

---

## 3. Armas

Só as armas matam (sempre com 1 acerto). Ninguém começa armado: a rodada começa com 1 arma no mapa (2 com quatro jogadores) e aparece mais uma a cada 10 s, se houver menos de 2 largadas no chão. Armas fortes aparecem menos. Quando a munição acaba, a arma some. Quem morre larga a arma.

| Arma | Munição | Recarga | Como funciona |
| :--- | :---: | :---: | :--- |
| Pistola | 5 | 0,35 s | Alcance médio. |
| Espingarda | 3 | 1,1 s | Leque de 6 chumbos, alcance curto. |
| Metralhadora | 10 (uma carga) | — | 1 s aquecendo (o cano gira e brilha), depois um tiro a cada 0,15 s. |
| Sniper | 3 | 1,5 s | Mira laser visível por 0,5 s antes do tiro; vai até a parede. |
| Laser | 3 | 0,5 s | Quica até 3 vezes nas paredes; depois de quicar acerta até quem atirou. |
| Bazuca | 2 | 1,8 s | Explosão em área (pega até quem atirou, se estiver perto). |
| Bumerangue | 3 | 0,6 s | Vai e volta; mata na ida e na volta. Só lança outro quando o anterior voltar. |
| Língua elétrica | — (dura 8 s) | 0,45 s | Lambida de perto que mata. Funciona invisível. |

Todos os números ficam em `scripts/armas.gd`.

---

## 4. Elementos do Cenário

Os mapas contêm elementos interativos com efeitos específicos:

* **Muros e Pedras:** Bloqueiam movimentação e interceptam a trajetória da língua.
* **Água (Lagos e Rios):** Superfície letal. Qualquer camaleão que pisar ou for arrastado para dentro da água é eliminado por afogamento.
* **Pontes:** Permitem travessia segura sobre rios e lagos.
* **Poças de Água:** Deixam pegadas molhadas temporárias no chão, revelando a posição de jogadores camuflados.
* **Capim Alto:** Oculta parte do corpo do camaleão, mas a movimentação agita a vegetação e indica a rota de passagem.
* **Manchas de Luz:** Projetam a sombra do jogador no chão, mesmo que ele esteja invisível.

---

## 5. Poderes e Coletáveis

Durante a partida, orbes de poderes surgem na arena. Cada jogador pode carregar apenas um poder por vez:

* **Gancho:** Ao atingir uma parede com a língua, o próprio camaleão é puxado em alta velocidade até a estrutura.
* **Grude:** Disparos de língua que não atingem alvos deixam uma gosma no solo que imobiliza temporariamente quem pisar.
* **Muda de Pele:** Ativa camuflagem instantânea, deixando para trás uma réplica estática no local.
* **Detecção:** Revela o contorno de oponentes invisíveis que entrarem no raio de visão do camaleão.
* **Cocô:** Obstáculo no solo que suja os pés do jogador ao contato, deixando pegadas visíveis durante a movimentação.

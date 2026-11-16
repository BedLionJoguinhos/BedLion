# Testes Automatizados, Fuzzy Testing e Code Review

Bateria de testes unitários e fuzzy testing executada diretamente pelo Godot Engine em modo headless, além de ferramentas de cobertura de código e análise estática para CI/CD.

---

## Como Executar

Na raiz do projeto, execute no terminal:

```bash
godot --headless --path . -s tests/test_runner.gd
```

Opções extras para fuzzy testing determinístico ou filtro de suíte (após `--`):

```bash
godot --headless --path . -s tests/test_runner.gd -- --fuzz-seed=20261116 --fuzz-iterations=200
godot --headless --path . -s tests/test_runner.gd -- --suite=fuzzy
```

* **Sucesso:** Retorna código de saída `0` e exibe `✓` para cada asserção.
* **Falha:** Retorna código de saída `1` e detalha a asserção que falhou.

### Cobertura de Código (LCOV + Resumo) e Code Review Local

```bash
# Validação de scripts e cenas em SceneTree real
godot --headless --path . -s tools/validate_project.gd

# Cobertura de linhas GDScript (gera coverage/lcov.info, coverage.json e summary.md)
python3 tools/gd_coverage.py --min-coverage 40

# Análise de boas práticas e revisão de código
python3 tools/gd_review.py --coverage-json coverage/coverage.json --validate-status pass
```

---

## Estrutura dos Arquivos

* `test_runner.gd`: Ponto de entrada que orquestra todas as suítes, lê flags de fuzzing e contabiliza os resultados.
* `test_helper.gd`: Utilitários de asserção, criação de arena/camaleões headless e passo de física.
* `test_mapas.gd`: Validações de limites, conectividade e funções geométricas em `scripts/mapas.gd`.
* `test_linguas.gd`: Validações de alcance, velocidade, tempo de tração e integridade de poderes em `scripts/linguas.gd`.
* `test_controles.gd`: Validações de mapeamento de ações, deadzones e helpers em `scripts/controles.gd`.
* `test_partida.gd`: Validações de tremor de câmera, menu de pausa, tela de vitória e desconexão de controle em `scripts/main.gd`.
* `test_caminhos.gd`: Testes unitários de navegação A* (`AStarGrid2D`), bloqueios e células livres em `scripts/caminhos.gd`.
* `test_camaleao.gd`: Testes unitários de combate, língua, gancho, grude, muda de pele, invisibilidade, pegadas e morte na água em `scripts/camaleao.gd`.
* `test_entidades.gd`: Testes unitários de `Grude`, `Casca`, `CocoPombo`, `Pistas`, `Bot`, `Partida`, `Placar`, `Ui` e rotação de mapas em `Main`.
* `test_telas.gd`: Testes unitários de `Menu`, `Configuracoes` e fluxo de vagas/cores/bots do `Lobby`.
* `test_fuzz.gd`: Suíte de fuzzy testing determinístico (com seed reproduzível) cobrindo geometria de mapas, rotas A*, parsing de controles e simulação de combate headless em arena.

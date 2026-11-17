# Diretrizes do Projeto BedLion (Godot 4.7+ / GDScript)

## Padrões de Código e Estilo
- Use tipagem estática explícita em parâmetros, tipos de retorno (`-> void` ou tipo) e declarações (`:=` ou `: Tipo`).
- Use `class_name` e comentários de documentação `##` no cabeçalho dos scripts em `scripts/`.
- Nunca use `load()` dinâmico dentro de `_process`, `_physics_process` ou `_draw`; declare `const ... := preload(...)` no topo.
- Siga a ordem de definições configurada em `.gdlintrc` (`consts` antes de `staticvars`, depois `var`s e funções), sem `else` após `return` e sem espaços no fim das linhas.
- Mantenha formatação compatível com `gdformat --line-length 160` e valide com `gdlint scripts tests`.

## Regras para Testes Headless (`tests/`)
- Novos arquivos de suíte devem usar `extends "res://tests/test_helper.gd"` e `preload(...)` para scripts auxiliares, evitando depender de `.godot/` pré-importado em CI.
- Ao usar `Engine.get_main_loop()` com `:=`, faça cast explícito `(Engine.get_main_loop() as SceneTree)`.
- Não chame `node._ready()` manualmente após `add_child(node)` (a árvore já executa `_ready()`).
- Antes de acessar propriedades de um nó que invocou `queue_free()` após `await avancar_fisica(...)`, verifique `is_instance_valid(no)` ou valide os sinais/estados antes do `await`.

## Verificação Obrigatória Após Alterações
1. `HOME=/tmp godot --headless --path . -s tools/validate_project.gd`
2. `HOME=/tmp godot --headless --path . -s tests/test_runner.gd`
3. Se houver alteração de regras/lógica em `scripts/`, valide cobertura com `python3 tools/gd_coverage.py --min-coverage 80`.

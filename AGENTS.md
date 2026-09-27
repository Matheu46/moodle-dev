# Moodle Development Agent Guide (moodle-dev)

Você é um Engenheiro de Software Sênior especialista no ecossistema Moodle (Moodle 4.x e 5.x) atuando neste workspace `moodle-dev`.

---

## 1. Arquitetura do Workspace

- **`meus-plugins/`**: Diretório onde residem todos os plugins customizados desenvolvidos por você/usuário (ex: `meus-plugins/mod_coder`). Cada subpasta é um repositório ou pasta de plugin independente.
- **`moodle/`**: Código-fonte do Moodle Core. Use-o para consultar implementações de referência de classes, hooks, forms e renderers oficiais do Moodle.
- **`momopda/`**: Base de conhecimento modular de desenvolvimento Moodle (prompts, padrões arquiteturais, checklists de segurança).
- **`moodle-docker/`**: Orquestrador Docker do ambiente de desenvolvimento.

---

## 2. Regras Mandatórias ao Trabalhar em Plugins (`meus-plugins/`)

Sempre que o usuário solicitar criação, alteração, refatoração ou correção em qualquer plugin dentro de `meus-plugins/`:

### ETAPA 1: Identificação do Plugin e Tipo
Identifique o componente pelo nome da pasta (convenção de nomenclatura Moodle):
- `mod_*` → Tipo: `mod` (Activity module)
- `block_*` → Tipo: `block` (Bloco)
- `local_*` → Tipo: `local` (Plugin local)
- `theme_*` → Tipo: `theme` (Tema)
- `enrol_*` → Tipo: `enrol` (Inscrição)
- `filter_*` → Tipo: `filter` (Filtro de texto)
- `qtype_*` → Tipo: `qtype` (Tipo de questão)
- `qbank_*` → Tipo: `qbank` (Banco de questões)
- `tiny_*` → Tipo: `tiny` (Plugin do editor TinyMCE)
- `report_*` → Tipo: `report` (Relatório)

### ETAPA 2: Leitura Obrigatória de Diretrizes do MoMoPDA
**Antes de gerar ou alterar código**, você DEVE ler e seguir os arquivos pertinentes em `momopda/.prompts/`:
1. **Core e Segurança (Sempre):**
   - `momopda/.prompts/core/base-instructions.md` (Princípios fundamentais, version.php, namespaces)
   - `momopda/.prompts/core/security-checklist.md` (Sesskey, capabilities, SQL injection `$DB`, limpeza de parâmetros com `PARAM_*`)
2. **Específico do Tipo de Plugin:**
   - `momopda/.prompts/plugins/<tipo>.md`
   - `momopda/.prompts/plugins/<tipo>_patterns.md` (se existir)
3. **Se envolver Frontend / UI / Mustache:**
   - `momopda/.prompts/core/moodle-design-principles.md`
4. **Se envolver JavaScript / AMD Modules:**
   - `momopda/.prompts/core/moodle-javascript-standards.md`
   - O código-fonte SEMPRE fica em `amd/src/<nome>.js` (nunca edite `amd/build/` manualmente).

---

## 3. Validação e Ferramentas Docker (Obrigatório)

Este ambiente possui contêineres Docker pré-configurados. **NÃO** tente rodar PHP ou Node diretamente no host sem os scripts do ambiente. Use sempre os scripts utilitários da raiz:

1. **Novos Plugins:**
   - Ao criar uma nova pasta de plugin em `meus-plugins/<nome>`, execute imediatamente:
     ```bash
     ./link-plugins.sh
     ```
     Isso cria os links simbólicos necessários dentro da árvore do Moodle Core respeitando branches com ou sem pasta `public/`.

2. **JavaScript / CSS / SCSS (Build e Lint):**
   - Sempre que alterar código JS em `amd/src/`, recompile **APENAS** o plugin atual para economizar tempo (nunca rode globalmente):
     ```bash
     ./run-grunt.sh amd --root=<tipo>/<nome_do_plugin>
     ```
   - Sempre que alterar arquivos de estilo (CSS / SCSS) em algum plugin, recompile também passando o tipo e nome do plugin:
     ```bash
     ./run-grunt.sh css --root=<tipo>/<nome_do_plugin>
     ```
     *(Ex: `./run-grunt.sh amd --root=local/quicknote` ou `./run-grunt.sh css --root=theme/union_govbr`)*
     O script já traduz automaticamente para `public/` se necessário. Isso compila os arquivos e valida o código com o ESLint/Stylelint oficial do Moodle.

3. **Validação de Código PHP (Moodle CodeChecker / PHPCS):**
   - Valide se o código segue os padrões do Moodle (o script aceita `meus-plugins/<nome>`, `public/<tipo>/<nome>` ou `<tipo>/<nome>`):
     ```bash
     ./run-phpcs.sh meus-plugins/<nome_do_plugin>
     # ou
     ./run-phpcs.sh public/local/<nome_do_plugin>
     ```
   - Para corrigir erros triviais de formatação automaticamente:
     ```bash
     ./run-phpcbf.sh meus-plugins/<nome_do_plugin>
     ```

4. **Limpeza de Caches (Purge Caches):**
   - Sempre que alterar strings de idioma (`lang/`), capacidades (`db/access.php`), eventos/hooks (`db/events.php`), templates Mustache ou tabelas (`db/install.xml` / `upgrade.php`), limpe os caches para o Moodle refletir as mudanças:
     ```bash
     cd moodle-docker && bin/moodle-docker-compose exec -T webserver php admin/cli/purge_caches.php
     ```

5. **Testes Automatizados (PHPUnit):**
   - Se criar ou rodar testes unitários:
     ```bash
     ./run-phpunit.sh meus-plugins/<nome_do_plugin>/tests
     ```


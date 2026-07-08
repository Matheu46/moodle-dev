# Moodle Dev Environment

Um ambiente de desenvolvimento Moodle para a criação de plugins. Este projeto utiliza o [moodle-docker](https://github.com/moodlehq/moodle-docker), adicionando facilidades para controle de versão, troca de branches, compilação de assets e análise de código (Linting).

## 🚀 Estrutura do Projeto

*   **`setup_moodle_env.sh`**: O script principal de instalação. Ele clona os repositórios oficiais do Moodle e do moodle-docker, aplica as configurações customizadas e prepara o banco de dados.
*   **`start-moodle.sh`**: Script para iniciar os contêineres Docker do ambiente Moodle de forma segura.
*   **`switch-moodle-version.sh`**: Script para trocar a versão do Moodle (ex: de `4.5` para `5.2`). Ele lida com a troca de branches no repositório, limpeza de cache e recriação do banco de dados quando necessário.
*   **`link-plugins.sh`**: Responsável por fazer o mapeamento dos seus plugins externos (localizados em `~/meus-plugins`) para dentro da estrutura do Moodle via symlinks.
*   **`custom-configs/local.yml`**: Configuração customizada injetada no `moodle-docker` para garantir que as pastas dos plugins externos sejam mapeadas no contêiner do servidor web.
*   **`dummy-config.php`**: Arquivo auxiliar que resolve problemas de escopo de caminhos (`require_once`) quando plugins acessam o `config.php` a partir de symlinks externos.

## 🛠 Ferramentas de Desenvolvimento

Para facilitar a aderência aos padrões de código do Moodle, este ambiente inclui scripts que isolam a complexidade do Docker:

*   **`run-phpcs.sh <caminho>`**: Roda o analisador estático (PHP CodeSniffer) com o padrão de código do MoodleHQ.
    *   *Uso:* `./run-phpcs.sh local/meuplugin`
*   **`run-phpcbf.sh <caminho>`**: Aplica correções automáticas (PHP Code Beautifier and Fixer) para erros de formatação encontrados pelo PHPCS.
    *   *Uso:* `./run-phpcbf.sh local/meuplugin`
*   **`run-grunt.sh [opções]`**: Sobe um micro-contêiner isolado com `Node 22` para compilar módulos AMD (Javascript) nativamente, injetando as pastas no contêiner para contornar limitações do Rollup com symlinks.
    *   *Uso:* `./run-grunt.sh amd --root=local/meuplugin`

## 💻 Fluxo de Trabalho Ideal

1. **Inicie o ambiente:**
   ```bash
   ./start-moodle.sh
   ```
2. **Desenvolva seus plugins:**
   Crie ou edite seus plugins na pasta externa `~/meus-plugins`. O ambiente já está configurado para refletir as alterações no Moodle em tempo real.
3. **Compile o Javascript (se houver):**
   ```bash
   ./run-grunt.sh amd --root=local/seu-plugin
   ```
4. **Verifique a Qualidade do Código:**
   ```bash
   ./run-phpcbf.sh local/seu-plugin # Corrige formatação automática
   ./run-phpcs.sh local/seu-plugin  # Exibe erros manuais a serem corrigidos
   ```
5. **Troque de Versão (Testes de Compatibilidade):**
   ```bash
   ./switch-moodle-version.sh MOODLE_502_STABLE
   ```

## ⚠️ Requisitos

*   Docker e Docker Compose
*   Sistema Operacional baseado em Unix (Linux/macOS) ou WSL2 no Windows.

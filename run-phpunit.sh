#!/bin/bash

# Helper script to easily run PHPUnit tests in Moodle
if [ -f "$HOME/moodle-dev/.moodle-env" ]; then
    source "$HOME/moodle-dev/.moodle-env"
fi

export MOODLE_DOCKER_WWWROOT="$HOME/moodle-dev/moodle"
export MOODLE_DOCKER_DB=pgsql

cd "$HOME/moodle-dev/moodle-docker"

if [ "$1" == "--init" ]; then
    echo "Inicializando ambiente de testes do PHPUnit (isso pode demorar alguns minutos)..."
    echo "--------------------------------------------------------"
    echo "Resolvendo problemas de permissão do git (dubious ownership)..."
    bin/moodle-docker-compose exec webserver git config --global --add safe.directory /var/www/html

    if [ -f "$MOODLE_DOCKER_WWWROOT/admin/tool/phpunit/cli/init.php" ]; then
        INIT_SCRIPT="admin/tool/phpunit/cli/init.php"
    else
        INIT_SCRIPT="public/admin/tool/phpunit/cli/init.php"
    fi
    bin/moodle-docker-compose exec webserver php $INIT_SCRIPT
    exit $?
fi

if [ -z "$1" ]; then
    echo "Dica: Você está rodando a suíte completa de testes (o que pode demorar muito)."
    echo "Para inicializar os testes na primeira vez, use: ./run-phpunit.sh --init"
    echo "Para rodar um plugin específico, use: ./run-phpunit.sh meus-plugins/local_quicknote"
    echo "Você também pode passar opções do PHPUnit, ex: ./run-phpunit.sh --filter test_name meus-plugins/local_quicknote"
    echo "--------------------------------------------------------"
fi

# Pega o último argumento (geralmente o caminho alvo)
TARGET_PATH="${@: -1}"
# Todos os argumentos menos o último
PHPUNIT_ARGS="${@:1:$#-1}"

if [ $# -eq 0 ]; then
    TARGET_PATH=""
    PHPUNIT_ARGS=""
fi

HAS_PUBLIC=false
if [ -d "$MOODLE_DOCKER_WWWROOT/public" ]; then
    HAS_PUBLIC=true
fi

# Mapeia meus-plugins/ para a estrutura interna do Moodle
if [[ "$TARGET_PATH" == meus-plugins/* ]]; then
    REMAINDER="${TARGET_PATH#meus-plugins/}"
    PLUGIN_NAME_DIR=$(echo "$REMAINDER" | cut -d'/' -f1)
    SUBPATH="${REMAINDER#*/}"
    
    TYPE="${PLUGIN_NAME_DIR%%_*}"
    NAME="${PLUGIN_NAME_DIR#*_}"
    
    case "$TYPE" in
        "local")   TARGET_DIR="local" ;;
        "mod")     TARGET_DIR="mod" ;;
        "block")   TARGET_DIR="blocks" ;;
        "theme")   TARGET_DIR="theme" ;;
        "format")  TARGET_DIR="course/format" ;;
        "enrol")   TARGET_DIR="enrol" ;;
        "auth")    TARGET_DIR="auth" ;;
        "tool")    TARGET_DIR="admin/tool" ;;
        "report")  TARGET_DIR="report" ;;
        "qtype")   TARGET_DIR="question/type" ;;
        *)         TARGET_DIR="$TYPE" ;;
    esac
    
    if [ "$SUBPATH" != "$PLUGIN_NAME_DIR" ]; then
        MAPPED_PATH="$TARGET_DIR/$NAME/$SUBPATH"
    else
        MAPPED_PATH="$TARGET_DIR/$NAME"
    fi
    
    if [ "$HAS_PUBLIC" = true ]; then
        TARGET_PATH="public/$MAPPED_PATH"
    else
        TARGET_PATH="$MAPPED_PATH"
    fi
elif [[ "$TARGET_PATH" != /* ]] && [ -n "$TARGET_PATH" ] && [[ "$TARGET_PATH" != -* ]]; then
    if [ "$HAS_PUBLIC" = true ] && [[ "$TARGET_PATH" != public/* ]]; then
        if [ -e "$MOODLE_DOCKER_WWWROOT/public/$TARGET_PATH" ]; then
            TARGET_PATH="public/$TARGET_PATH"
        fi
    fi
fi

echo "Rodando PHPUnit..."
echo "Alvo: $TARGET_PATH"
echo "--------------------------------------------------------"
if [ -n "$TARGET_PATH" ] && [[ "$TARGET_PATH" != -* ]]; then
    bin/moodle-docker-compose exec webserver vendor/bin/phpunit --test-suffix _test.php $PHPUNIT_ARGS "$TARGET_PATH"
else
    bin/moodle-docker-compose exec webserver vendor/bin/phpunit --test-suffix _test.php "$@"
fi

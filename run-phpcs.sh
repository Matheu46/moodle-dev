#!/bin/bash

# Helper script to easily run PHPCS against a Moodle plugin
if [ -z "$1" ]; then
    echo "Uso: ./run-phpcs.sh <caminho_do_plugin>"
    echo "Exemplo: ./run-phpcs.sh local/quicknote"
    exit 1
fi

PLUGIN_INPUT=$1

export MOODLE_DOCKER_WWWROOT="$HOME/moodle-dev/moodle"
export MOODLE_DOCKER_DB=pgsql

if [ -f "$HOME/moodle-dev/.moodle-env" ]; then
    source "$HOME/moodle-dev/.moodle-env"
fi

# Detecta se a branch atual usa diretório public
HAS_PUBLIC=false
if [ -d "$MOODLE_DOCKER_WWWROOT/public" ]; then
    HAS_PUBLIC=true
fi

# Localiza o binário do CodeChecker
if [ "$HAS_PUBLIC" = true ] && [ -f "$MOODLE_DOCKER_WWWROOT/public/local/codechecker/vendor/bin/phpcs" ]; then
    PHPCS_BIN="public/local/codechecker/vendor/bin/phpcs"
elif [ -f "$MOODLE_DOCKER_WWWROOT/local/codechecker/vendor/bin/phpcs" ]; then
    PHPCS_BIN="local/codechecker/vendor/bin/phpcs"
else
    PHPCS_BIN="/home/matheus/moodle-dev/meus-plugins/local_codechecker/vendor/bin/phpcs"
fi

# Normaliza o caminho do plugin/arquivo para o container
TARGET_PATH="$PLUGIN_INPUT"
if [[ "$TARGET_PATH" == meus-plugins/* ]]; then
    TARGET_PATH="$HOME/moodle-dev/$TARGET_PATH"
elif [[ "$TARGET_PATH" != /* ]]; then
    if [ "$HAS_PUBLIC" = true ] && [[ "$TARGET_PATH" != public/* ]]; then
        if [ -e "$MOODLE_DOCKER_WWWROOT/public/$TARGET_PATH" ]; then
            TARGET_PATH="public/$TARGET_PATH"
        fi
    fi
fi

cd "$HOME/moodle-dev/moodle-docker"

echo "Rodando PHPCS (Moodle Code Checker) para: $TARGET_PATH..."
echo "--------------------------------------------------------"
bin/moodle-docker-compose exec webserver $PHPCS_BIN --standard=moodle "$TARGET_PATH"

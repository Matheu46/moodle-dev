#!/bin/bash

# Helper script to easily run PHPCS against a Moodle plugin
if [ -z "$1" ]; then
    echo "Uso: ./run-phpcs.sh <caminho_do_plugin>"
    echo "Exemplo: ./run-phpcs.sh local/quicknote"
    exit 1
fi

PLUGIN_PATH=$1

export MOODLE_DOCKER_WWWROOT="$HOME/moodle-dev/moodle"
export MOODLE_DOCKER_DB=pgsql

cd "$HOME/moodle-dev/moodle-docker"

echo "Rodando PHPCS (Moodle Code Checker) para: $PLUGIN_PATH..."
echo "--------------------------------------------------------"
bin/moodle-docker-compose exec webserver local/codechecker/vendor/bin/phpcs --standard=moodle "$PLUGIN_PATH"

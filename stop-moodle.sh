#!/bin/bash

export MOODLE_DOCKER_WWWROOT="$HOME/moodle-dev/moodle"
export MOODLE_DOCKER_DB=pgsql

cd "$HOME/moodle-dev/moodle-docker"

echo "Parando os contêineres do Moodle..."
echo "-----------------------------------"

# Parar os contêineres sem destruir o banco de dados (stop)
# Se quiser destruir tudo (reset completo), você poderia usar: bin/moodle-docker-compose down
bin/moodle-docker-compose stop

echo "-----------------------------------"
echo "✅ Ambiente Moodle pausado com sucesso!"

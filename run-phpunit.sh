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
    echo "Para rodar um plugin específico, use: ./run-phpunit.sh local/seuplugin"
    echo "Você também pode passar opções do PHPUnit, ex: ./run-phpunit.sh --filter test_name local/seuplugin"
    echo "--------------------------------------------------------"
fi

echo "Rodando PHPUnit..."
echo "--------------------------------------------------------"
bin/moodle-docker-compose exec webserver vendor/bin/phpunit --test-suffix _test.php "$@"

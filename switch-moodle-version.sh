#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Uso: ./switch-moodle-version.sh <branch_name> [--reset-db]"
    echo "Exemplo: ./switch-moodle-version.sh MOODLE_502_STABLE --reset-db"
    exit 1
fi

BRANCH=$1
RESET_DB=false

if [ "$2" == "--reset-db" ]; then
    RESET_DB=true
fi

export MOODLE_DOCKER_WWWROOT="$HOME/moodle-dev/moodle"
export MOODLE_DOCKER_DB=pgsql
DOCKER_DIR="$HOME/moodle-dev/moodle-docker"

# Define a versão do PHP com base na branch
case "$BRANCH" in
    MOODLE_400_STABLE|MOODLE_401_STABLE|MOODLE_402_STABLE)
        PHP_VERSION="8.0"
        ;;
    MOODLE_403_STABLE|MOODLE_404_STABLE)
        PHP_VERSION="8.1"
        ;;
    *)
        PHP_VERSION="8.3"
        ;;
esac

echo "export MOODLE_DOCKER_PHP_VERSION=\"$PHP_VERSION\"" > "$HOME/moodle-dev/.moodle-env"
source "$HOME/moodle-dev/.moodle-env"

echo "=========================================="
echo "Mudando Moodle para a branch: $BRANCH"
echo "Versão do PHP configurada para: $PHP_VERSION"
echo "=========================================="

# 1. Mudar a branch no repositório Moodle
echo "--> Alterando branch no git..."
cd "$MOODLE_DOCKER_WWWROOT"
git fetch origin
git checkout "$BRANCH"
git pull origin "$BRANCH" || echo "A branch local pode já estar atualizada."

# 1.5 Refazer links dos plugins
echo "--> Refazendo links dos plugins conforme a estrutura da branch..."
"$HOME/moodle-dev/link-plugins.sh"

cd "$DOCKER_DIR"

# Recria o servidor web com a imagem do PHP correta e garante rotas do Apache
echo "--> Recriando webserver (PHP $PHP_VERSION)..."
bin/moodle-docker-compose up -d webserver

# 2. Instalar as dependências do Composer (Essencial no Moodle 5.x)
echo "--> Resolvendo dependências do Composer..."
bin/moodle-docker-compose exec -T webserver bash -c '
    git config --global --add safe.directory /var/www/html
    cd /var/www/html
    if [ ! -f composer.phar ]; then
        curl -sS https://getcomposer.org/installer | php
    fi
    php composer.phar install --no-interaction
'

# 3. Limpar caches (Evita erros de hooks/classes perdidas)
echo "--> Limpando caches do Moodle e muc..."
bin/moodle-docker-compose exec -T webserver rm -rf /var/www/moodledata/cache /var/www/moodledata/localcache /var/www/moodledata/muc
bin/moodle-docker-compose exec -T webserver php admin/cli/purge_caches.php

# 4. Atualizar banco de dados ou Resetar
if [ "$RESET_DB" = true ]; then
    echo "--> Resetando o banco de dados do zero..."
    bin/moodle-docker-compose down -v
    bin/moodle-docker-compose up -d
    
    echo "Aguardando o banco iniciar..."
    bin/moodle-docker-wait-for-db
    
    echo "Instalando o banco de dados do Moodle..."
    bin/moodle-docker-compose exec -T webserver php admin/cli/install_database.php --agree-license --fullname="Docker Moodle" --shortname="docker_moodle" --adminpass="test" --adminemail="admin@example.com"
else
    echo "--> Tentando atualizar o banco de dados atual..."
    # Atualiza o banco; se falhar porque a versão é mais antiga, avisa o usuário
    if ! bin/moodle-docker-compose exec -T webserver php admin/cli/upgrade.php --non-interactive; then
        echo -e "\n⚠️ AVISO: Falha ao atualizar o banco de dados."
        echo "Isso normalmente ocorre quando você muda para uma versão mais ANTIGA do Moodle."
        echo "Recomendação: Rode este comando novamente adicionando '--reset-db' no final para reinstalar o Moodle."
        exit 1
    fi
fi

echo "=========================================="
echo "✅ Concluído! O Moodle agora está na versão $BRANCH"
echo "=========================================="

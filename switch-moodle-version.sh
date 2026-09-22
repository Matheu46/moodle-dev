#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Uso: ./switch-moodle-version.sh <branch_name> [--reset-db | --restore-db]"
    echo "Exemplo: ./switch-moodle-version.sh MOODLE_502_STABLE --restore-db"
    exit 1
fi

BRANCH=$1
RESET_DB=false
RESTORE_DB=false

if [ "$2" == "--reset-db" ]; then
    RESET_DB=true
elif [ "$2" == "--restore-db" ]; then
    RESTORE_DB=true
fi

export MOODLE_DOCKER_WWWROOT="$HOME/moodle-dev/moodle"
export MOODLE_DOCKER_DB=pgsql
DOCKER_DIR="$HOME/moodle-dev/moodle-docker"
mkdir -p "$HOME/moodle-dev/moodledata/filedir" && chmod -R 777 "$HOME/moodle-dev/moodledata" 2>/dev/null || true

# Define a versão do PHP e do PostgreSQL com base na branch
case "$BRANCH" in
    MOODLE_400_STABLE|MOODLE_401_STABLE|MOODLE_402_STABLE)
        PHP_VERSION="8.0"
        DB_VERSION="16"
        ;;
    MOODLE_403_STABLE|MOODLE_404_STABLE)
        PHP_VERSION="8.1"
        DB_VERSION="16"
        ;;
    MOODLE_405_STABLE|MOODLE_500_STABLE|MOODLE_501_STABLE|MOODLE_502_STABLE)
        PHP_VERSION="8.3"
        DB_VERSION="16"
        ;;
    main|master|MOODLE_50[3-9]_STABLE|MOODLE_5[1-9][0-9]_STABLE)
        PHP_VERSION="8.3"
        DB_VERSION="17"
        ;;
    *)
        PHP_VERSION="8.3"
        DB_VERSION="16"
        ;;
esac

cat << EOF > "$HOME/moodle-dev/.moodle-env"
export MOODLE_DOCKER_PHP_VERSION="$PHP_VERSION"
export MOODLE_DOCKER_DB_VERSION="$DB_VERSION"
EOF
source "$HOME/moodle-dev/.moodle-env"

echo "=========================================="
echo "Mudando Moodle para a branch: $BRANCH"
echo "Versão do PHP configurada para: $PHP_VERSION"
echo "Versão do PostgreSQL configurada para: $DB_VERSION"
echo "=========================================="

# 1. Mudar a branch no repositório Moodle
echo "--> Alterando branch no git..."
cd "$MOODLE_DOCKER_WWWROOT"

# Pega o nome da branch atual
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Faz backup do banco atual antes de trocar de branch
RUNNING_DB_VERSION=""
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    echo "--> Verificando banco de dados para backup da branch $CURRENT_BRANCH..."
    cd "$DOCKER_DIR"
    if bin/moodle-docker-compose ps db | grep -q "Up"; then
        RUNNING_DB_VERSION=$(bin/moodle-docker-compose exec -T db psql -U moodle -d moodle -t -A -c "SHOW server_version;" 2>/dev/null | cut -d'.' -f1 || true)
        echo "--> Realizando backup do banco da branch atual ($CURRENT_BRANCH)..."
        mkdir -p "$HOME/moodle-dev/db-backups"
        if [ -f "$HOME/moodle-dev/db-backups/${CURRENT_BRANCH}.sql" ]; then
            cp "$HOME/moodle-dev/db-backups/${CURRENT_BRANCH}.sql" "$HOME/moodle-dev/db-backups/${CURRENT_BRANCH}.sql.bak"
        fi
        if bin/moodle-docker-compose exec -T db pg_dump -U moodle -d moodle -c > "$HOME/moodle-dev/db-backups/${CURRENT_BRANCH}.sql"; then
            sed -i '/^Including local options from/d' "$HOME/moodle-dev/db-backups/${CURRENT_BRANCH}.sql"
            echo "    Backup salvo com sucesso em ~/moodle-dev/db-backups/${CURRENT_BRANCH}.sql"
        else
            echo "    Aviso: Falha ao realizar backup do banco de dados."
        fi
    fi
fi

# Se a versão major do PostgreSQL mudou, não é possível reaproveitar o volume de dados sem reset/restore
if [ -n "$RUNNING_DB_VERSION" ] && [ "$RUNNING_DB_VERSION" != "$DB_VERSION" ]; then
    if [ "$RESET_DB" = false ] && [ "$RESTORE_DB" = false ]; then
        echo "⚠️ Detectada mudança de versão do PostgreSQL ($RUNNING_DB_VERSION -> $DB_VERSION)."
        echo "O PostgreSQL não suporta upgrade in-place entre versões major."
        if [ -f "$HOME/moodle-dev/db-backups/${BRANCH}.sql" ]; then
            echo "--> Restaurando backup da branch '$BRANCH' automaticamente..."
            RESTORE_DB=true
        else
            echo "--> Nenhum backup encontrado para '$BRANCH'. Reinicializando banco (--reset-db)..."
            RESET_DB=true
        fi
    fi
fi

cd "$MOODLE_DOCKER_WWWROOT"
git fetch origin || echo "Aviso: Não foi possível buscar atualizações remotas no momento."
git checkout "$BRANCH"
git pull origin "$BRANCH" || echo "A branch local pode já estar atualizada."

# 1.5 Refazer links dos plugins
echo "--> Refazendo links dos plugins conforme a estrutura da branch..."
"$HOME/moodle-dev/link-plugins.sh"

cd "$DOCKER_DIR"

# 2. Atualizar banco de dados, Restaurar ou Resetar
if [ "$RESTORE_DB" = true ]; then
    BACKUP_FILE="$HOME/moodle-dev/db-backups/${BRANCH}.sql"
    echo "--> Verificando se existe backup para a branch $BRANCH..."
    if [ -f "$BACKUP_FILE" ]; then
        echo "--> Restaurando o banco de dados a partir do backup $BACKUP_FILE..."
        bin/moodle-docker-compose down -v
        bin/moodle-docker-compose up -d
        
        echo "Aguardando o banco iniciar..."
        until bin/moodle-docker-compose exec -T db pg_isready -U moodle > /dev/null 2>&1; do
            sleep 1
        done
        
        echo "Aplicando backup..."
        cat "$BACKUP_FILE" | bin/moodle-docker-compose exec -T db psql -U moodle -d moodle
        echo "Backup restaurado com sucesso!"
    else
        echo "⚠️ Nenhum backup encontrado para a branch $BRANCH."
        echo "Caindo para a instalação padrão (--reset-db)..."
        RESET_DB=true
    fi
fi

if [ "$RESET_DB" = true ]; then
    echo "--> Resetando o banco de dados do zero..."
    bin/moodle-docker-compose down -v
    bin/moodle-docker-compose up -d
    
    echo "Aguardando o banco iniciar..."
    until bin/moodle-docker-compose exec -T db pg_isready -U moodle > /dev/null 2>&1; do
        sleep 1
    done
    
    echo "Instalando o banco de dados do Moodle..."
    bin/moodle-docker-compose exec -T webserver php admin/cli/install_database.php --agree-license --fullname="Docker Moodle" --shortname="docker_moodle" --adminpass="test" --adminemail="admin@example.com"
    
    echo "Instalando os tipos de conteúdo H5P padrão..."
    bin/moodle-docker-compose exec -T webserver php admin/cli/scheduled_task.php --execute='\core\task\h5p_get_content_types_task' || true
elif [ "$RESTORE_DB" = false ]; then
    # Recria o servidor web com a imagem do PHP correta e garante rotas do Apache
    echo "--> Recriando webserver (PHP $PHP_VERSION)..."
    bin/moodle-docker-compose up -d webserver

    echo "Aguardando o banco iniciar..."
    until bin/moodle-docker-compose exec -T db pg_isready -U moodle > /dev/null 2>&1; do
        sleep 1
    done

    echo "--> Tentando atualizar o banco de dados atual..."
    # Atualiza o banco; se falhar porque a versão é mais antiga, avisa o usuário
    if ! bin/moodle-docker-compose exec -T webserver php admin/cli/upgrade.php --non-interactive; then
        echo -e "\n⚠️ AVISO: Falha ao atualizar o banco de dados."
        echo "Isso normalmente ocorre quando você muda para uma versão mais ANTIGA do Moodle."
        echo "Recomendação: Rode este comando novamente adicionando '--restore-db' (para restaurar backup) ou '--reset-db' (para reinstalar)."
        exit 1
    fi
fi

# 2.5 Garantir integridade de imagens referenciadas no banco (evita Whoops em imagens ausentes)
echo "--> Verificando integridade de arquivos de imagem no moodledata..."
bin/moodle-docker-compose exec -T webserver php -r '
    define("CLI_SCRIPT", true);
    require("config.php");
    global $DB;
    $images = $DB->get_records_sql("SELECT DISTINCT contenthash, mimetype FROM {files} WHERE mimetype LIKE \x27image/%\x27 AND filesize > 0");
    foreach ($images as $img) {
        $hash = $img->contenthash;
        $dir = "/var/www/moodledata/filedir/" . substr($hash, 0, 2) . "/" . substr($hash, 2, 2);
        $target = "$dir/$hash";
        if (!file_exists($target)) {
            if (!is_dir($dir)) {
                @mkdir($dir, 0777, true);
            }
            if (strpos($img->mimetype, "png") !== false) {
                $im = @imagecreatetruecolor(100, 100);
                @imagepng($im, $target);
                @imagedestroy($im);
            } elseif (strpos($img->mimetype, "svg") !== false) {
                @file_put_contents($target, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"100\"></svg>");
            } else {
                $im = @imagecreatetruecolor(100, 100);
                @imagejpeg($im, $target);
                @imagedestroy($im);
            }
        }
    }
' 2>/dev/null || true

# 3. Instalar as dependências do Composer (Essencial no Moodle 5.x)
echo "--> Resolvendo dependências do Composer..."
bin/moodle-docker-compose exec -T webserver bash -c '
    git config --global --add safe.directory /var/www/html
    cd /var/www/html
    if [ -f composer.json ]; then
        if [ ! -f composer.phar ]; then
            curl -sS https://getcomposer.org/installer | php
        fi
        php composer.phar install --no-interaction
    fi
'

# 4. Limpar caches (Evita erros de hooks/classes perdidas)
echo "--> Limpando caches do Moodle e muc..."
bin/moodle-docker-compose exec -T webserver rm -rf /var/www/moodledata/cache /var/www/moodledata/localcache /var/www/moodledata/muc
bin/moodle-docker-compose exec -T webserver php admin/cli/purge_caches.php

echo "=========================================="
echo "✅ Concluído! O Moodle agora está na versão $BRANCH"
echo "=========================================="

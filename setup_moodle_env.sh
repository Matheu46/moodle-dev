#!/bin/bash
set -e

echo "Setting up Moodle development environment..."

# 1. Create a base directory called moodle-dev in the home folder and navigate into it
BASE_DIR="$HOME/moodle-dev"
mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

# 2. Clone the official Moodle core repository
if [ ! -d "moodle" ]; then
    echo "Cloning Moodle core repository..."
    git clone git://git.moodle.org/moodle.git moodle
else
    echo "Directory 'moodle' already exists, skipping clone."
fi

# 3. Clone the official Moodle Docker orchestration repository
if [ ! -d "moodle-docker" ]; then
    echo "Cloning Moodle Docker repository..."
    git clone https://github.com/moodlehq/moodle-docker.git moodle-docker
else
    echo "Directory 'moodle-docker' already exists, skipping clone."
fi

# 3.5 Injetar configurações customizadas do Docker
if [ -d "$BASE_DIR/custom-configs" ]; then
    echo "Copiando arquivos de configuração customizada para o moodle-docker..."
    cp -r "$BASE_DIR/custom-configs/"* "$BASE_DIR/moodle-docker/"
fi

# 4. Process all plugins inside the freelance plugins directory dynamically
PLUGINS_BASE_DIR="$HOME/meus-plugins"
mkdir -p "$PLUGINS_BASE_DIR"

echo "Executando o link dos plugins de acordo com a versão do Moodle..."
"$BASE_DIR/link-plugins.sh"

# 6. Create the start-moodle.sh helper script
START_SCRIPT="$BASE_DIR/start-moodle.sh"
echo "Creating start-moodle.sh helper script..."

cat << 'EOF' > "$START_SCRIPT"
#!/bin/bash
set -e

export MOODLE_DOCKER_WWWROOT="$HOME/moodle-dev/moodle"
export MOODLE_DOCKER_DB=pgsql

cd "$HOME/moodle-dev/moodle-docker"

if [ ! -f "$MOODLE_DOCKER_WWWROOT/config.php" ]; then
    echo "Creating config.php from template..."
    cp config.docker-template.php "$MOODLE_DOCKER_WWWROOT/config.php"
fi

echo "Starting Moodle Docker containers..."
bin/moodle-docker-compose up -d

echo "Setting up Moodle..."
bin/moodle-docker-wait-for-db
bin/moodle-docker-compose exec webserver php admin/cli/install_database.php --agree-license --fullname="Docker Moodle" --shortname="docker_moodle" --adminpass="test" --adminemail="admin@example.com"

echo "Moodle setup complete! Your site should be running."
EOF

# 7. Add executable permissions to the helper script
chmod +x "$START_SCRIPT"

echo "Setup script finished successfully!"
echo "Your Moodle development environment is ready in $BASE_DIR."
echo "To start Moodle, run: $START_SCRIPT"

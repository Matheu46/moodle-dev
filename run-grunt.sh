#!/bin/bash

# Helper script to run Moodle's Grunt using a Node 22 Docker container
# This guarantees that you don't need to update Node.js on your local machine.

MOODLE_DIR="$HOME/moodle-dev/moodle"
IMAGE_NAME="node:22"

echo "Usando o Moodle Grunt via Docker ($IMAGE_NAME)..."

# If node_modules doesn't exist or is empty, run npm install first
if [ ! -d "$MOODLE_DIR/node_modules" ] || [ -z "$(ls -A "$MOODLE_DIR/node_modules" 2>/dev/null)" ]; then
    echo "Baixando as dependências do Node.js (Isso pode demorar um pouco na primeira vez)..."
    docker run --rm -v "$MOODLE_DIR:/moodle" -w /moodle $IMAGE_NAME npm install
fi

# Build dynamic volumes for all external plugins
VOLUMES="-v $MOODLE_DIR:/moodle"
for plugin in $HOME/meus-plugins/*; do
    if [ -d "$plugin" ]; then
        plugin_name=$(basename "$plugin")
        plugin_type="${plugin_name%%_*}"
        plugin_subname="${plugin_name#*_}"
        if [ -n "$plugin_type" ] && [ -n "$plugin_subname" ] && [ "$plugin_type" != "$plugin_name" ]; then
            VOLUMES="$VOLUMES -v $plugin:/moodle/$plugin_type/$plugin_subname"
        fi
    fi
done

# Pass any arguments provided to grunt (e.g., amd, watch)
if [ $# -eq 0 ]; then
    echo "Executando: npx grunt amd (padrão)"
    docker run --rm $VOLUMES -w /moodle $IMAGE_NAME npx grunt amd
else
    echo "Executando: npx grunt $@"
    if [ "$1" = "watch" ]; then
        docker run -it --rm $VOLUMES -w /moodle $IMAGE_NAME npx grunt "$@"
    else
        docker run --rm $VOLUMES -w /moodle $IMAGE_NAME npx grunt "$@"
    fi
fi

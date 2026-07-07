#!/bin/bash
set -e

BASE_DIR="$HOME/moodle-dev"
PLUGINS_BASE_DIR="$HOME/meus-plugins"
MOODLE_DIR="$BASE_DIR/moodle"

cd "$MOODLE_DIR"

# Determina se a versão atual do Moodle (branch) usa o diretório 'public' nativamente
# Verifica se a pasta public existe no repositório git atual (Moodle 5.1+)
if git ls-tree HEAD public | grep -q tree; then
    WEBROOT="$MOODLE_DIR/public"
else
    WEBROOT="$MOODLE_DIR"
    # Se public existe mas não é nativo do repositório (resíduo), removemos
    if [ -d "$MOODLE_DIR/public" ]; then
        echo "Removendo diretório 'public' residual da branch anterior..."
        rm -rf "$MOODLE_DIR/public"
    fi
fi

echo "Diretório base de plugins definido como: ${WEBROOT}"

for PLUGIN_PATH in "$PLUGINS_BASE_DIR"/*; do
    [ -d "$PLUGIN_PATH" ] || continue
    
    PLUGIN_DIRNAME=$(basename "$PLUGIN_PATH")
    
    PLUGIN_TYPE="${PLUGIN_DIRNAME%%_*}"
    PLUGIN_NAME="${PLUGIN_DIRNAME#*_}"
    
    if [ "$PLUGIN_TYPE" = "$PLUGIN_DIRNAME" ]; then
        continue
    fi
    
    case "$PLUGIN_TYPE" in
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
        *)         continue ;;
    esac
    
    SYMLINK_TARGET="$WEBROOT/$TARGET_DIR/$PLUGIN_NAME"
    
    echo "Configurando plugin $PLUGIN_DIRNAME -> $SYMLINK_TARGET"
    
    mkdir -p "$WEBROOT/$TARGET_DIR"
    
    # Se já existir um symlink, remove antes para garantir que está correto
    if [ -L "$SYMLINK_TARGET" ]; then
        rm "$SYMLINK_TARGET"
    fi
    
    # Se não existir um diretório real lá (para não sobrescrever código core)
    if [ ! -e "$SYMLINK_TARGET" ]; then
        ln -s "$PLUGIN_PATH" "$SYMLINK_TARGET"
    fi
done

echo "Todos os plugins foram vinculados com sucesso ao diretório correto!"

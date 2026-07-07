<?php
// Arquivo de redirecionamento para o ambiente Docker de desenvolvimento.
// Como os plugins são symlinks a partir de /home/matheus/meus-plugins,
// os caminhos relativos como ../../config.php resolvem para /home/matheus/config.php.
// Este arquivo direciona para o config real.
require_once('/var/www/html/config.php');

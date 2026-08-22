fx_version 'adamant'
game 'gta5'

author 'Bastien MAGAN'
description 'Police Nationale — Métier complet'
version '1.0.0'

dependencies {
    'lslegacy',
    'mdt',
}

ui_page 'html/radio.html'

files {
    'html/radio.html',
    'html/css/*.css',
    'html/js/*.js',
}

shared_scripts {
    'config.lua',
    'config_mdt.lua',
    'languages/fr.lua',
}

client_scripts {
    'client/bootstrap.lua',
    'client/main.lua',
    'client/actions.lua',
    'client/radio.lua',
    'client/investigation.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bootstrap.lua',
    'server/main.lua',
    'server/actions.lua',
    'server/prison.lua',
    'server/investigation.lua',
}

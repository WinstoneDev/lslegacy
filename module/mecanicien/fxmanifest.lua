fx_version 'adamant'
game 'gta5'

author 'Bastien MAGAN'
description 'Mécanicien — Métier complet'
version '1.0.0'

dependencies {
    'lslegacy',
    'ox_lib',
    'ox_target',
}

shared_scripts {
    'config.lua',
    'languages/fr.lua',
}

client_scripts {
    'client/main.lua',
    'client/actions.lua',
    'client/parts.lua',
    'client/tow.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/actions.lua',
    'server/parts.lua',
}

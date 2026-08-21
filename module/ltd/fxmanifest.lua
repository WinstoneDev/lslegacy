fx_version 'adamant'
game 'gta5'

author 'Bastien MAGAN'
description 'LTD — Métier complet'
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
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/stock.lua',
}

fx_version 'adamant'
game 'gta5'

author 'Bastien MAGAN'
description 'SAMU — Métier complet'
version '1.0.0'

dependencies {
    'lslegacy',
    'mdt',
    'tfsandbulance',
}

shared_scripts {
    'config.lua',
    'config_samu.lua',
    'languages/fr.lua',
}

client_scripts {
    'client/bootstrap.lua',
    'client/main.lua',
    'client/actions.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bootstrap.lua',
    'server/main.lua',
    'server/actions.lua',
}

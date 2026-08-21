fx_version 'adamant'
game 'gta5'

author 'Bastien MAGAN'
description 'Farm — Activités de récolte (bûcheron/mineur/pêcheur/agriculteur/culture)'
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
}

server_scripts {
    'server/main.lua',
}

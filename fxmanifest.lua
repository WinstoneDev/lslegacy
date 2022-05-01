fx_version 'adamant'
game 'gta5'

files {
    'inventory/html/*.html',
    'inventory/html/js/*.js',
    'inventory/html/css/*.css',
    'inventory/html/locales/*.js',
    'inventory/html/img/hud/*.png',
    'inventory/html/img/*.png',
    'inventory/html/img/items/*.png'
}

ui_page 'inventory/html/ui.html'

client_scripts {
    'client/function.lua',
	'dependencies/RageUI/RMenu.lua',
    'dependencies/RageUI/menu/RageUI.lua',
    'dependencies/RageUI/menu/Menu.lua',
    'dependencies/RageUI/menu/MenuController.lua',
    'dependencies/RageUI/components/*.lua',
    'dependencies/RageUI/menu/elements/*.lua',
    'dependencies/RageUI/menu/items/*.lua',
    'dependencies/RageUI/menu/panels/*.lua',
    'dependencies/RageUI/menu/windows/*.lua',
    'client/zones.lua',
    'client/richpresence.lua',
    'client/command.lua',
    'client/player/player.lua',
    'client/player/spawn.lua',
    'client/player/pickup.lua',
    'inventory/utils.lua',
    'inventory/client/main.lua',
    'module/interaction/cl_interact.lua',
    'module/adminmenu/cl_admin.lua',
    'module/skincreator/cl_camera.lua',
    'module/skincreator/cl_charcreator.lua',
    'module/identity/cl_identity.lua',
    'module/clothshop/cl_clothshop.lua',
    'module/bank/cl_bank.lua'
}

shared_scripts {
    'shared/*.lua',
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/*.lua',
    'server/player/*.lua',
    'inventory/server/main.lua',
    'module/interaction/sv_interact.lua',
    'module/adminmenu/sv_admin.lua',
    'module/skincreator/sv_charcreator.lua',
    'module/identity/sv_identity.lua',
    'module/clothshop/sv_clothshop.lua',
    'module/bank/sv_bank.lua'
}

exports {
    "GetPlayerInventoryItems",
    "GetPlayerInventoryWeight",
    "GetOriginalLabel"
}
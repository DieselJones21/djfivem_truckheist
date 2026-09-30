fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'djfivem_truckheist'
author 'DieselJones21'
description 'Qbox truck and trailer heist with ox_lib, ox_target, GPS routing, and a live mission progress bar'
version '1.0.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
}

client_scripts {
    'client/hud.lua',
    'client/gps.lua',
    'client/main.lua',
}

server_scripts {
    'config/server.lua',
    'server/main.lua',
}

ui_page 'web/index.html'

files {
    'locales/*.json',
    'web/index.html',
    'web/style.css',
    'web/script.js',
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'qbx_core',
}

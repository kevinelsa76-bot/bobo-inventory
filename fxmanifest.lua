fx_version 'cerulean'
game 'gta5'

description 'bobo-inventory - Inventaire custom (ESX / QBCore / QBox)'
version '0.3.0'

-- -----------------------------------------------------------------------
-- Scripts partagés (chargés côté client ET serveur)
-- config.lua AVANT bridge.lua (Bridge lit Config.Framework au démarrage)
-- -----------------------------------------------------------------------
shared_scripts {
    'config.lua',
    'shared/bridge.lua',
}

-- -----------------------------------------------------------------------
-- Scripts serveur
-- oxmysql DOIT être en premier (MySQL global dispo dès main.lua)
-- -----------------------------------------------------------------------
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/vehicle.lua',
}

-- -----------------------------------------------------------------------
-- Scripts client
-- main.lua AVANT vehicle.lua (Hotbar et inventoryOpen définis dans main)
-- -----------------------------------------------------------------------
client_scripts {
    'client/main.lua',
    'client/vehicle.lua',
}

-- -----------------------------------------------------------------------
-- Interface NUI
-- -----------------------------------------------------------------------
ui_page 'html/ui.html'

files {
    'html/ui.html',
    'html/css/main.css',
    'html/js/app.js',
    'html/images/*.png',
    'html/images/*.svg',
}

lua54 'yes'

-- -----------------------------------------------------------------------
-- Dépendances
-- oxmysql et bobo-items sont obligatoires.
-- Le framework est détecté automatiquement (qb-core, qbx_core ou es_extended).
-- illenium-appearance est requis pour les slots de vêtements.
-- -----------------------------------------------------------------------
dependencies {
    'oxmysql',
    'bobo-items',
}

optional_dependencies {
    'qb-core',
    'qbx_core',
    'es_extended',
    'illenium-appearance',
    'ox_lib',
}
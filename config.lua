-- =====================================================================
-- bobo-inventory | config.lua
-- =====================================================================

Config = {}

-- -----------------------------------------------------------------------
-- FRAMEWORK
-- -----------------------------------------------------------------------
-- Choix du framework : 'auto', 'qbcore', 'qbox', 'esx'
-- 'auto' détecte automatiquement lequel est démarré sur ton serveur.
-- Mets manuellement si tu as des conflits.
-- -----------------------------------------------------------------------
Config.Framework = 'auto'

-- -----------------------------------------------------------------------
-- INVENTAIRE
-- -----------------------------------------------------------------------

-- Poids maximum qu'un joueur peut porter (en grammes). 120000 = 120kg
Config.MaxInventoryWeight = 120000

-- Nombre de slots (cases) dans l'inventaire du joueur
Config.MaxInventorySlots = 41

-- -----------------------------------------------------------------------
-- NOTIFICATIONS
-- Type : 'framework' (utilise le framework détecté) ou 'ox' (ox_lib)
-- -----------------------------------------------------------------------
Config.Notify = 'framework'

-- -----------------------------------------------------------------------
-- CONTRÔLES
-- -----------------------------------------------------------------------

-- Touche pour ouvrir l'inventaire (voir https://docs.fivem.net/docs/game-references/controls/)
Config.OpenKey = 'TAB'

-- Touche pour ouvrir le coffre (derrière le véhicule)
Config.TrunkKey = 'G'

-- Touche pour ouvrir la boîte à gants (dans le véhicule)
Config.GloveboxKey = 'I'

-- -----------------------------------------------------------------------
-- COFFRE DE VÉHICULE
-- -----------------------------------------------------------------------
Config.MaxTrunkWeight = 100000  -- 100kg
Config.MaxTrunkSlots  = 30

-- -----------------------------------------------------------------------
-- BOÎTE À GANTS
-- -----------------------------------------------------------------------
Config.MaxGloveboxWeight = 20000  -- 20kg
Config.MaxGloveboxSlots  = 10

-- -----------------------------------------------------------------------
-- LANGUE
-- Choix de la langue : 'fr', 'en', 'es'
-- -----------------------------------------------------------------------
Config.Language = 'fr'

local Langs = {
    fr = {
        noaccess   = "Vous ne pouvez pas accéder à cet inventaire !",
        itemexist  = "Cet objet n'existe pas",
        notenough  = "Vous n'avez pas assez de place",
        tooheavy   = "C'est trop lourd à porter",
        equipped   = "Vêtement équipé",
        unequipped = "Vêtement retiré",
        maskOn     = "Masque remis",
        maskOff    = "Masque retiré",
        wrongslot  = "Ce vêtement ne va pas dans cette case",
        noplayer   = "Aucun joueur à proximité",
        noitem     = "Vous n'avez plus cet objet",
        invfull    = "Inventaire plein",
        toofar     = "Trop loin pour ramasser",
        novest     = "Vous n'avez pas de gilet pare-balles",
        veston     = "Vous portez déjà un gilet",
        vestequip  = "Gilet pare-balles équipé",
        vestremove = "Gilet retiré",
        vestdestroy= "Votre gilet pare-balles est détruit",
        gave       = "Vous avez donné %dx %s",
        received   = "Vous avez reçu %dx %s",
        dropped    = "Vous avez jeté %dx %s",
        picked     = "Vous avez ramassé %dx %s",
        invalidqty = "Quantité invalide",
        targetfull       = "L'autre joueur n'a pas assez de place",
        noVehicleNearby  = "Aucun véhicule à proximité",
        notBehindVehicle = "Vous devez être derrière le véhicule",
        notInVehicle     = "Vous devez être dans un véhicule",
        tooFarVehicle    = "Vous vous êtes éloigné du véhicule",
    },
    en = {
        noaccess   = "You cannot access this inventory!",
        itemexist  = "This item does not exist",
        notenough  = "You don't have enough space",
        tooheavy   = "This is too heavy to carry",
        equipped   = "Clothing equipped",
        unequipped = "Clothing removed",
        maskOn     = "Mask put back on",
        maskOff    = "Mask removed",
        wrongslot  = "This clothing doesn't fit in this slot",
        noplayer   = "No player nearby",
        noitem     = "You no longer have this item",
        invfull    = "Inventory full",
        toofar     = "Too far to pick up",
        novest     = "You don't have a bulletproof vest",
        veston     = "You are already wearing a vest",
        vestequip  = "Bulletproof vest equipped",
        vestremove = "Vest removed",
        vestdestroy= "Your bulletproof vest is destroyed",
        gave       = "You gave %dx %s",
        received   = "You received %dx %s",
        dropped    = "You dropped %dx %s",
        picked     = "You picked up %dx %s",
        invalidqty = "Invalid quantity",
        targetfull       = "The other player doesn't have enough space",
        noVehicleNearby  = "No vehicle nearby",
        notBehindVehicle = "You must be behind the vehicle",
        notInVehicle     = "You must be in a vehicle",
        tooFarVehicle    = "You moved too far from the vehicle",
    },
    es = {
        noaccess   = "¡No puedes acceder a este inventario!",
        itemexist  = "Este objeto no existe",
        notenough  = "No tienes suficiente espacio",
        tooheavy   = "Esto es demasiado pesado para cargar",
        equipped   = "Ropa equipada",
        unequipped = "Ropa retirada",
        maskOn     = "Máscara puesta",
        maskOff    = "Máscara retirada",
        wrongslot  = "Esta ropa no encaja en este espacio",
        noplayer   = "Ningún jugador cerca",
        noitem     = "Ya no tienes este objeto",
        invfull    = "Inventario lleno",
        toofar     = "Demasiado lejos para recoger",
        novest     = "No tienes un chaleco antibalas",
        veston     = "Ya llevas un chaleco puesto",
        vestequip  = "Chaleco antibalas equipado",
        vestremove = "Chaleco retirado",
        vestdestroy= "Tu chaleco antibalas está destruido",
        gave       = "Has dado %dx %s",
        received   = "Has recibido %dx %s",
        dropped    = "Has tirado %dx %s",
        picked     = "Has recogido %dx %s",
        invalidqty = "Cantidad inválida",
        targetfull       = "El otro jugador no tiene suficiente espacio",
        noVehicleNearby  = "Ningún vehículo cerca",
        notBehindVehicle = "Debes estar detrás del vehículo",
        notInVehicle     = "Debes estar en un vehículo",
        tooFarVehicle    = "Te has alejado demasiado del vehículo",
    },
}

-- Charge la langue choisie (fallback sur 'en' si langue inconnue)
Config.Lang = Langs[Config.Language] or Langs['en']

-- =====================================================================
-- SLOTS D'ÉQUIPEMENT
-- =====================================================================
Config.EquipmentSlots = {
    hat     = { kind = "prop",      id = 0,  label = "Chapeau",    icon = "fa-hat-cowboy",        order = 1 },
    glasses = { kind = "prop",      id = 1,  label = "Lunettes",   icon = "fa-glasses",           order = 2 },
    mask    = { kind = "component", id = 1,  label = "Masque",     icon = "fa-mask",              order = 3 },
    top     = { kind = "component", id = 11, label = "Haut",       icon = "fa-shirt",             order = 4 },
    jacket  = { kind = "component", id = 3,  label = "Veste",      icon = "fa-vest",              order = 5 },
    pants   = { kind = "component", id = 4,  label = "Pantalon",   icon = "fa-person-half-dress", order = 6 },
    shoes   = { kind = "component", id = 6,  label = "Chaussures", icon = "fa-shoe-prints",       order = 7 },
    bag     = { kind = "component", id = 5,  label = "Sac à dos",  icon = "fa-bag-shopping",      order = 8 },
    gloves  = { kind = "component", id = 8,  label = "Gants",      icon = "fa-mitten",            order = 9 },
    watch   = { kind = "prop",      id = 6,  label = "Montre",     icon = "fa-clock",             order = 10 },
    bracelet= { kind = "prop",      id = 7,  label = "Bracelet",   icon = "fa-ring",              order = 11 },
}

-- =====================================================================
-- VALEURS "NU" — apparence sans vêtement équipé
-- =====================================================================
Config.NakedComponents = {
    [1]  = 0,
    [3]  = 15,
    [4]  = 21,
    [5]  = 0,
    [6]  = 34,
    [8]  = 15,
    [11] = 15,
}

Config.NakedProps = {
    [0] = -1,
    [1] = -1,
    [6] = -1,
    [7] = -1,
}

-- =====================================================================
-- CONSOMMABLES
-- Définit les effets des items mangeables / buvables.
-- 'anim'   : 'eat' ou 'drink' (animation jouée côté client)
-- 'hunger' : points de faim restaurés (0-100)
-- 'thirst' : points de soif restaurés (0-100)
-- 'time'   : durée de l'animation en ms (défaut 3000)
-- =====================================================================
Config.Consumables = {
    -- Exemples — adapte les noms à tes items qb-core / ESX
    sandwich = { anim = 'eat',   hunger = 35, thirst = 5,  time = 3000 },
    water    = { anim = 'drink', hunger = 0,  thirst = 40, time = 2500 },
    beer     = { anim = 'drink', hunger = 0,  thirst = 20, time = 2000 },
    taco     = { anim = 'eat',   hunger = 25, thirst = 0,  time = 3000 },
    donut    = { anim = 'eat',   hunger = 20, thirst = 0,  time = 2000 },
    candy    = { anim = 'eat',   hunger = 10, thirst = 0,  time = 1500 },
    coffee   = { anim = 'drink', hunger = 5,  thirst = 25, time = 2500 },
    juice    = { anim = 'drink', hunger = 0,  thirst = 30, time = 2000 },
}

-- -----------------------------------------------------------------------
-- DEBUG
-- Met à true pour voir les logs dans la console serveur/client
-- -----------------------------------------------------------------------
Config.Debug = false
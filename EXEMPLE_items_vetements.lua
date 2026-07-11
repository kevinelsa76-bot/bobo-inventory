-- =====================================================================
-- bobo-inventory | ITEMS DE VÊTEMENTS D'EXEMPLE
-- =====================================================================
-- Copie ces lignes dans ton fichier qb-core/shared/items.lua,
-- À L'INTÉRIEUR de la table QBShared.Items = { ... }
--
-- IMPORTANT : la clé "info" doit contenir :
--   slot         = la case d'équipement visée (voir Config.EquipmentSlots)
--   drawable     = le numéro du modèle GTA (le vêtement lui-même)
--   texture      = la variante de couleur (0 par défaut)
--   component_id = optionnel, sinon déduit du slot
--
-- Les images (tshirt_blanc.png, etc.) doivent exister dans
-- ps-inventory/html/images/  OU  bobo-inventory/html/images/
-- Sinon la case affichera un carré vide (pas grave pour tester).
-- =====================================================================

-- === HAUT (torse, component 11) ===
['tshirt_blanc'] = {
    ['name'] = 'tshirt_blanc',
    ['label'] = 'T-shirt blanc',
    ['weight'] = 300,
    ['type'] = 'item',
    ['image'] = 'tshirt_blanc.png',
    ['unique'] = true,          -- unique = true pour les vêtements (chacun distinct)
    ['useable'] = false,
    ['shouldClose'] = false,
    ['combinable'] = nil,
    ['description'] = 'Un t-shirt blanc tout simple',
    ['info'] = { slot = 'top', drawable = 4, texture = 0 },
},

-- === PANTALON (jambes, component 4) ===
['jean_bleu'] = {
    ['name'] = 'jean_bleu',
    ['label'] = 'Jean bleu',
    ['weight'] = 600,
    ['type'] = 'item',
    ['image'] = 'jean_bleu.png',
    ['unique'] = true,
    ['useable'] = false,
    ['shouldClose'] = false,
    ['combinable'] = nil,
    ['description'] = 'Un jean bleu classique',
    ['info'] = { slot = 'pants', drawable = 4, texture = 0 },
},

-- === CHAUSSURES (pieds, component 6) ===
['baskets_noires'] = {
    ['name'] = 'baskets_noires',
    ['label'] = 'Baskets noires',
    ['weight'] = 500,
    ['type'] = 'item',
    ['image'] = 'baskets_noires.png',
    ['unique'] = true,
    ['useable'] = false,
    ['shouldClose'] = false,
    ['combinable'] = nil,
    ['description'] = 'Une paire de baskets noires',
    ['info'] = { slot = 'shoes', drawable = 10, texture = 0 },
},

-- === CHAPEAU (prop 0) ===
['casquette'] = {
    ['name'] = 'casquette',
    ['label'] = 'Casquette',
    ['weight'] = 150,
    ['type'] = 'item',
    ['image'] = 'casquette.png',
    ['unique'] = true,
    ['useable'] = false,
    ['shouldClose'] = false,
    ['combinable'] = nil,
    ['description'] = 'Une casquette stylée',
    ['info'] = { slot = 'hat', drawable = 5, texture = 0 },
},

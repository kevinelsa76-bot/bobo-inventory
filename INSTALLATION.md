# bobo-inventory — Guide d'installation

Inventaire custom FiveM avec équipement de vêtements, coffre de véhicule,
boîte à gants, hotbar, système de drops au sol et support multi-framework.

---

## Compatibilité

| Framework | Version         | Supporté |
|-----------|-----------------|----------|
| QBCore    | 1.x et supérieur | ✅       |
| QBox      | Toutes versions  | ✅       |
| ESX       | Legacy           | ✅       |

---

## Dépendances

| Resource             | Obligatoire | Remarque                                  |
|----------------------|-------------|-------------------------------------------|
| `oxmysql`            | ✅ Oui      | Base de données                           |
| `bobo-items`         | ✅ Oui      | Gestion des actions items                 |
| `bobo-compat`        | ✅ Oui      | Compatibilité avec les autres inventaires |
| `illenium-appearance`| ⚠️ Oui*    | Requis pour les slots de vêtements. Optionnel si tu n'utilises pas l'équipement de tenue. |
| `ox_lib`             | ❌ Non      | Optionnel si `Config.Notify = 'ox'`       |

---

## Fonctionnalités

- 📦 Inventaire joueur avec grille de slots, poids, recherche
- 👕 Slots d'équipement (haut, pantalon, chaussures, masque, etc.)
- 🎽 Gilet pare-balles avec barre de durabilité en temps réel
- 🚗 Coffre de véhicule avec ouverture physique (touche `G`)
- 🧤 Boîte à gants (touche `I` depuis l'habitacle)
- 🌱 Drops au sol partagés entre joueurs
- ⌨️ Hotbar (raccourcis 1 à 5)
- 💸 Affichage de l'argent physique et de l'argent sale
- 🌐 3 langues intégrées : Français, Anglais, Espagnol
- 🔄 Compatible ESX / QBCore / QBox (détection automatique)

---

## Installation

### Étape 1 — Copier les fichiers

Place les dossiers dans ton répertoire de resources :

```
resources/
└── [bobo]/
    ├── bobo-inventory/
    ├── bobo-items/
    └── bobo-compat/
```

> ⚠️ `bobo-items` et `bobo-compat` doivent être dans le même dossier que `bobo-inventory`.

---

### Étape 2 — Importer la base de données

Dans **phpMyAdmin** (ou ton client SQL), importe le fichier :

```
bobo-inventory/bobo-inventory.sql
```

Ce fichier crée les tables suivantes :

| Table               | Description                                      |
|---------------------|--------------------------------------------------|
| `bobo_equipment`    | Tenue équipée du joueur (sauvegardée à la reco)  |
| `bobo_hotbar`       | Raccourcis 1-5 de chaque joueur                  |
| `bobo_trunkitems`   | Contenu des coffres de véhicule (par plaque)     |
| `bobo_gloveboxitems`| Contenu des boîtes à gants (par plaque)          |

> ✅ Toutes les tables utilisent `CREATE TABLE IF NOT EXISTS` — aucun risque d'écraser des données existantes.

---

### Étape 3 — Copier les images des items

Les images des items ne sont pas incluses dans le script. Copie-les depuis ton inventaire actuel (ex. `ps-inventory` ou `qb-inventory`) :

```
[source]/html/images/  →  bobo-inventory/html/images/
```

> Sans cette étape, les cases seront vides mais l'inventaire fonctionnera quand même.

---

### Étape 4 — Retirer l'ancien inventaire

Dans ton `server.cfg`, **commente ou supprime** la ligne de ton ancien inventaire :

```cfg
# ensure ps-inventory     ← à commenter
# ensure qb-inventory     ← ou celui-ci selon ton serveur
```

> ⚠️ Ne fais jamais tourner deux inventaires en même temps. Ils utilisent tous la même touche TAB et la même colonne `inventory` en base.

---

### Étape 5 — Configurer le server.cfg

Ajoute les scripts dans cet ordre **précis** :

```cfg
ensure oxmysql
ensure qb-core            # ou es_extended / qbx_core
ensure illenium-appearance
ensure ox_lib             # optionnel
ensure bobo-items         # toujours AVANT bobo-inventory
ensure bobo-inventory
ensure bobo-compat        # toujours APRÈS bobo-inventory
```

> ⚠️ L'ordre est important. `bobo-items` avant `bobo-inventory`, `bobo-compat` en dernier.

---

### Étape 6 — Configuration

Ouvre `bobo-inventory/config.lua` et ajuste selon ton serveur :

```lua
-- Framework : 'auto' détecte automatiquement (recommandé)
Config.Framework = 'auto'   -- 'auto' | 'qbcore' | 'qbox' | 'esx'

-- Langue
Config.Language = 'fr'      -- 'fr' | 'en' | 'es'

-- Notifications
Config.Notify = 'framework' -- 'framework' | 'ox'

-- Debug (logs console)
Config.Debug = false        -- true pour voir les logs détaillés

-- Inventaire joueur
Config.MaxInventoryWeight = 120000  -- poids max en grammes (120kg)
Config.MaxInventorySlots  = 41      -- nombre de slots

-- Coffre de véhicule
Config.MaxTrunkWeight = 100000      -- 100kg
Config.MaxTrunkSlots  = 30

-- Boîte à gants
Config.MaxGloveboxWeight = 20000    -- 20kg
Config.MaxGloveboxSlots  = 10

-- Touches
Config.OpenKey     = 'TAB'  -- ouvrir l'inventaire joueur
Config.TrunkKey    = 'G'    -- ouvrir le coffre (derrière le véhicule)
Config.GloveboxKey = 'I'    -- ouvrir la boîte à gants (dans le véhicule)
```

Ouvre ensuite `bobo-items/config.lua` et configure de la même façon :

```lua
Config.Framework = 'auto'
Config.Language  = 'fr'
Config.Notify    = 'framework'
Config.Debug     = false  -- true pour voir les logs en console
```

---

### Étape 7 — Démarrer le serveur

Redémarre ton serveur. Dans les logs tu dois voir :

```
[bobo-inventory] Framework détecté : qbcore
[bobo-inventory] Serveur chargé (qbcore).
[bobo-inventory] Module véhicule serveur chargé.
[bobo-items] Framework détecté : qbcore
[bobo-items] Registre serveur prêt (qbcore).
[bobo-items] Consommables enregistrés : 13
[bobo-items] Soins enregistrés : 4
[bobo-items] Armures enregistrées : 3
[bobo-items] Armes enregistrées : 68
[bobo-items] Divers enregistrés : parachute, véhicules, nitro, fireworks, moneybag, lockpick, binoculars
[bobo-compat] Bridge serveur chargé — ps-inventory, qb-inventory, ox_inventory, qs-inventory...
[bobo-compat] Bridge client chargé.
```

---

## Compatibilité avec d'autres scripts (bobo-compat)

`bobo-compat` est inclus dans le pack et permet à tous tes scripts existants de fonctionner sans modification. Il simule automatiquement les exports des inventaires les plus populaires et les redirige vers `bobo-inventory`.

### Inventaires supportés

| Inventaire         | Exports couverts                                              |
|--------------------|---------------------------------------------------------------|
| `ps-inventory`     | AddItem, RemoveItem, HasItem, GetItemByName, GetSlotsByItem, GetItemBySlot, ClearInventory, GetInventory |
| `qb-inventory`     | Idem ps-inventory                                             |
| `ox_inventory`     | AddItem, RemoveItem, Search, GetItem, GetInventoryItems, GetItemCount, GetSlot |
| `qs-inventory`     | AddItem, RemoveItem, HasItem, GetItemsByName, GetItemTotalCount |
| `core_inventory`   | addItem, removeItem, hasItem, getItem, getItemCount           |
| `origen_inventory` | AddItem, RemoveItem, HasItem, GetItemByName, getItemAmount    |
| `tgiann-inventory` | AddItem, RemoveItem, HasItem, GetItemByName, GetSlotsByItem   |

### Events de compatibilité supportés

```lua
-- QBCore
RegisterNetEvent('inventory:server:GiveItem')

-- ESX
RegisterNetEvent('esx:addInventoryItem')
RegisterNetEvent('esx:removeInventoryItem')

-- ox_inventory
RegisterNetEvent('ox_inventory:useItem')
```

> ℹ️ Si un script utilise des fonctionnalités très spécifiques à un inventaire (métadonnées complexes, UI custom...), il faudra peut-être l'adapter manuellement. Les fonctions de base (AddItem, RemoveItem, HasItem) sont couvertes à 100%.

---

## Items requis

Pour que l'inventaire fonctionne correctement, les items suivants doivent exister dans ton framework.

### Items de base

| Nom          | Label        | Description                        |
|--------------|--------------|------------------------------------|
| `money`      | Argent       | Argent physique                    |
| `black_money`| Argent sale  | Argent sale physique               |
| `bulletproof_vest` | Gilet pare-balles | Armure 100%              |

> ℹ️ Si tu utilises `bobo-items` comme gestionnaire d'items, ces items sont déjà gérés nativement. Tu n'as pas besoin de les déclarer dans QBCore.

### Items de vêtements (optionnel)

Pour utiliser les slots d'équipement, un item de vêtement doit avoir ce format dans son `info` :

```lua
info = {
    slot        = "top",         -- correspond à une clé de Config.EquipmentSlots
    component_id = 11,           -- ID GTA du composant
    drawable    = 12,
    texture     = 0,
}
```

Les slots disponibles sont : `hat`, `glasses`, `mask`, `top`, `jacket`, `pants`, `shoes`, `bag`, `gloves`, `watch`, `bracelet`.

---

## Utilisation en jeu

| Action                     | Contrôle                          |
|----------------------------|-----------------------------------|
| Ouvrir l'inventaire        | `TAB`                             |
| Fermer l'inventaire        | `TAB` ou `Echap`                  |
| Déplacer un item           | Glisser-déposer                   |
| Menu contextuel            | Clic droit sur un item            |
| Donner un item             | Glisser sur la case "Donner"      |
| Ouvrir le coffre           | `G` (derrière le véhicule)        |
| Ouvrir la boîte à gants    | `I` (dans l'habitacle)            |
| Déposer dans le coffre     | Glisser un item vers le coffre    |
| Reprendre du coffre        | Clic gauche sur l'item            |
| Raccourcis hotbar          | Touches `1` à `5`                 |
| Assigner hotbar            | Glisser un item sur un slot 1-5   |
| Retirer hotbar             | Clic droit sur un slot 1-5        |

---

## Commandes admin

| Commande                        | Description                              |
|---------------------------------|------------------------------------------|
| `/giveitem [id] [item] [qté]`   | Donner un item à un joueur               |
| `clearinv [id]`                 | Vider l'inventaire d'un joueur (console) |
| `listeitems`                    | Lister les items enregistrés (console)   |

---

## Dépannage

**L'inventaire ne s'ouvre pas**
Vérifie que l'ancien inventaire (`ps-inventory`, `qb-inventory`) est bien désactivé dans le `server.cfg`. Regarde aussi la console F8 en jeu pour les erreurs en rouge.

**Les images sont vides**
Tu n'as pas copié les images. Voir Étape 3.

**"Framework non détecté"**
Vérifie que `qb-core`, `es_extended` ou `qbx_core` démarre avant `bobo-inventory`. Si le problème persiste, force le framework manuellement dans `config.lua` : `Config.Framework = 'qbcore'`.

**Les items disparaissent au redémarrage**
`bobo-inventory` accepte tous les items même s'ils ne sont pas dans `QBCore.Shared.Items`. Si des items disparaissent quand même, vérifie que `bobo-items` démarre bien avant `bobo-inventory`.

**Le coffre ne s'ouvre pas**
Vérifie que tu es bien à moins de 3.5 mètres du véhicule. Si le message "Aucun véhicule à proximité" apparaît encore, augmente `TRUNK_DISTANCE` dans `client/vehicle.lua`.

**La boîte à gants bloque la souris**
Assure-toi d'être conducteur ou passager dans le véhicule avant d'appuyer sur `I`.

**Un script externe ne trouve pas ses exports d'inventaire**
Vérifie que `bobo-compat` démarre bien après `bobo-inventory` dans le `server.cfg`. C'est lui qui simule les exports de `ps-inventory`, `ox_inventory`, etc.

**Le coffre du véhicule ne s'ouvre pas physiquement**
Certains véhicules modifiés n'ont pas de bone "coffre" (door 5). C'est une limitation GTA V, pas un bug du script.

**L'argent sale n'est pas synchronisé**
Vérifie que le nom de ton item argent sale est bien `black_money`. Si c'est un autre nom, modifie la fonction `getDirtyTotal()` dans `html/js/app.js`.

---

## Support

Pour toute question ou bug, rejoins notre Discord ou ouvre une issue sur le dépôt.

---

*bobo-inventory v0.3.0 — bobo-items v2.1.0 — bobo-compat v1.0.0*
*Compatible ESX / QBCore / QBox*
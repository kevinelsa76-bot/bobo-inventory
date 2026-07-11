# bobo-inventory

Inventaire custom FiveM — 41 slots, système de poids, drag & drop, hotbar 1-5, drops au sol partagés, argent physique, vêtements et masque toggle, coffre véhicule, boîte à gants.

Compatible **ESX**, **QBCore** et **QBox** via bridge automatique.

---

## Dépendances

| Ressource | Obligatoire |
|---|---|
| [oxmysql](https://github.com/overextended/oxmysql) | ✅ Oui |
| [bobo-items](https://github.com/bobo/bobo-items) | ✅ Oui |
| [illenium-appearance](https://github.com/iLLeniumStudios/illenium-appearance) | ✅ Pour les slots vêtements |
| qb-core / qbx_core / es_extended | ✅ Un des trois |
| ox_lib | ⚙️ Optionnel (notifications) |

---

## Installation

### 1. Base de données

Importer le fichier `bobo-inventory.sql` fourni dans votre dossier `sql/` via HeidiSQL, phpMyAdmin ou la ligne de commande :

```bash
mysql -u root -p ma_base < bobo-inventory.sql
```

Ce fichier crée les tables suivantes (toutes en `IF NOT EXISTS`, sans risque) :

| Table | Description |
|---|---|
| `bobo_equipment` | Vêtements équipés par joueur |
| `bobo_hotbar` | Raccourcis hotbar 1-5 par joueur |
| `bobo_trunkitems` | Items dans les coffres de véhicules (par plaque) |
| `bobo_gloveboxitems` | Items dans les boîtes à gants (par plaque) |
| `bobo_stashitems` | Items dans les stashs/conteneurs fixes |

> L'inventaire du joueur est stocké dans la colonne `inventory` de la table `players` fournie par votre framework — aucune modification de cette table n'est nécessaire.

### 2. Ressources

Placer `bobo-inventory`, `bobo-items` et `bobo-compat` dans votre dossier `resources`.

### 3. server.cfg

```cfg
ensure oxmysql
ensure bobo-items
ensure bobo-compat
ensure bobo-inventory
```

> `bobo-inventory` doit être chargé **après** votre framework (ESX / QBCore / QBox).

---

## Configuration

Tout se configure dans `config.lua` :

```lua
Config.Framework         = 'auto'    -- 'auto', 'esx', 'qbcore', 'qbox'
Config.MaxInventoryWeight = 120000   -- Poids max en grammes
Config.MaxInventorySlots  = 41       -- Nombre de slots
Config.OpenKey            = 'TAB'    -- Touche d'ouverture inventaire
Config.TrunkKey           = 'G'      -- Touche coffre véhicule
Config.GloveboxKey        = 'I'      -- Touche boîte à gants
Config.Notify             = 'auto'   -- 'auto', 'ox', 'esx', 'qbcore'
Config.Lang               = Config.Langs['fr'] -- 'fr', 'en', 'es'
```

### Slots vêtements

Les slots d'équipement (chapeau, masque, torse, etc.) se configurent dans `Config.EquipmentSlots`. Chaque slot est lié à un component ou prop du ped GTA.

### NakedComponents

`Config.NakedComponents` définit les drawables appliqués quand le joueur retire sa tenue. À ajuster selon votre ped de base.

---

## Fonctionnalités

### Inventaire principal
- 41 slots avec système de poids
- Drag & drop entre slots
- Clic droit : Utiliser / Donner / Jeter
- Argent physique affiché

### Hotbar
- 5 raccourcis rapides (touches `1` à `5`)
- Glisser un item depuis l'inventaire pour l'assigner
- Persistant en base de données

### Bouton TENUE
- Retire tous les vêtements du personnage en un clic (garde le masque)
- Reclique = restaure la tenue complète
- État sauvegardé localement en session

### Bouton MASQUE
- Retire uniquement le masque (component 1)
- Indépendant du bouton TENUE
- Reclique = restaure le masque

### Drops au sol
- Items jetés visibles par tous les joueurs proches (objet 3D)
- Ramassage au sol depuis l'interface
- Nettoyage automatique au restart serveur

### Coffre véhicule & Boîte à gants
- Touche `G` près d'un véhicule = ouvre le coffre
- Touche `I` dans un véhicule = ouvre la boîte à gants
- Drag & drop entre l'inventaire joueur et le coffre

### Gilet pare-balles
- Item `bulletproof_vest` équipable depuis l'inventaire
- Barre d'armure en temps réel
- Retrait = item rendu avec durabilité restante

---

## Compatibilité (`bobo-compat`)

`bobo-compat` expose les exports standards pour que les autres ressources de votre serveur continuent de fonctionner sans modification :

- `ps-inventory`
- `qb-inventory`
- `ox_inventory`
- `qs-inventory`
- `core_inventory`
- `origen_inventory`
- `tgiann-inventory`

---

## Exports disponibles

```lua
-- Serveur
exports['bobo-inventory']:AddItem(source, item, amount, slot, info)
exports['bobo-inventory']:RemoveItem(source, item, amount, slot)
exports['bobo-inventory']:HasItem(source, item, amount)
exports['bobo-inventory']:GetItemByName(source, item)
exports['bobo-inventory']:GetItemBySlot(source, slot)
exports['bobo-inventory']:GetSlotsByItem(items, itemName)
exports['bobo-inventory']:GetFirstSlotByItem(items, itemName)
exports['bobo-inventory']:GetTotalWeight(items)
exports['bobo-inventory']:ClearInventory(source)
exports['bobo-inventory']:LoadInventory(source, citizenid)
exports['bobo-inventory']:SaveInventory(source)
```

---

## Commandes admin

| Commande | Description |
|---|---|
| `/giveitem [id] [item] [quantite]` | Donne un item à un joueur |
| `/clearinv [id]` | Vide l'inventaire d'un joueur |

> Ces commandes sont réservées aux administrateurs (`ace` FiveM).

---

## Langues

Trois langues disponibles dans `config.lua` : **Français** (`fr`), **Anglais** (`en`), **Espagnol** (`es`).

Pour changer de langue :
```lua
Config.Lang = Config.Langs['en']
```

---

## Support

Pour tout bug ou question, ouvrez une issue sur le dépôt GitHub.
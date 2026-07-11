-- =====================================================================
-- bobo-inventory | Base de données complète
-- Importe ce fichier une seule fois sur ton serveur MySQL.
--
-- Compatibilité : ESX / QBCore / QBox
--
-- NOTE : L'inventaire du joueur est stocké dans la colonne `inventory`
-- de la table `players` (fournie par ton framework), rien à créer ici.
-- =====================================================================


-- =====================================================================
-- TENUE ÉQUIPÉE
-- Sauvegarde ce que le joueur porte (vêtements, accessoires).
-- Permet de ré-habiller le joueur à la reconnexion.
-- =====================================================================
CREATE TABLE IF NOT EXISTS `bobo_equipment` (
    `citizenid` VARCHAR(50)  NOT NULL,
    `equipment` LONGTEXT     CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================================
-- HOTBAR (raccourcis 1-5)
-- Sauvegarde les items assignés aux touches rapides de chaque joueur.
-- =====================================================================
CREATE TABLE IF NOT EXISTS `bobo_hotbar` (
    `citizenid` VARCHAR(50)  NOT NULL,
    `hotbar`    LONGTEXT     CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================================
-- COFFRES DE VÉHICULE
-- Stocke les items dans le coffre d'un véhicule (par plaque).
-- =====================================================================
CREATE TABLE IF NOT EXISTS `bobo_trunkitems` (
    `id`    INT(11)      NOT NULL AUTO_INCREMENT,
    `plate` VARCHAR(255) NOT NULL,
    `items` LONGTEXT     CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
    PRIMARY KEY (`plate`),
    KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================================
-- BOÎTE À GANTS
-- Stocke les items dans la boîte à gants d'un véhicule (par plaque).
-- =====================================================================
CREATE TABLE IF NOT EXISTS `bobo_gloveboxitems` (
    `id`    INT(11)      NOT NULL AUTO_INCREMENT,
    `plate` VARCHAR(255) NOT NULL,
    `items` LONGTEXT     CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
    PRIMARY KEY (`plate`),
    KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================================
-- STASHS (conteneurs fixes : armoires, coffres, etc.)
-- Stocke les items dans un stash identifié par un nom unique.
-- =====================================================================
CREATE TABLE IF NOT EXISTS `bobo_stashitems` (
    `id`    INT(11)      NOT NULL AUTO_INCREMENT,
    `stash` VARCHAR(255) NOT NULL,
    `items` LONGTEXT     CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
    PRIMARY KEY (`stash`),
    KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
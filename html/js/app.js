// ===================================================================
// bobo-inventory | app.js
// ===================================================================

var STATE = {
    inventory: {},
    maxWeight: 120000,
    maxSlots: 41,
    cash: 0,
    groundDrops: [],
    // Véhicule
    isVehicle: false,
    vehicleType: null,   // 'trunk' ou 'glovebox'
    vehiclePlate: null,
    vehicleInventory: {},
    maxVehicleWeight: 100000,
    maxVehicleSlots: 30,
    // Tenue
    clothesStripped: false,
    // Masque
    maskOff: false,
};

// Formate un nombre en $ avec séparateurs de milliers : 12345 -> $12,345
function formatMoney(n) {
    n = Math.floor(Number(n) || 0);
    return '$' + n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

function getDirtyTotal() {
    var total = 0;
    for (var k in STATE.inventory) {
        var it = STATE.inventory[k];
        if (it && it.name && it.name.toLowerCase() === 'black_money') {
            total += (it.amount || 1);
        }
    }
    return total;
}

function renderMoney() {
    var cashEl = document.getElementById('cash-amount');
    if (cashEl) cashEl.textContent = formatMoney(STATE.cash);

    var dirtyEl = document.getElementById('dirty-amount');
    if (dirtyEl) dirtyEl.textContent = formatMoney(getDirtyTotal());
}

var IMG_PATH      = 'nui://bobo-inventory/html/images/';
var RESOURCE_NAME = GetParentResourceName();

// Helper : POST vers un callback NUI Lua
function nuiFetch(endpoint, data) {
    return fetch('https://' + RESOURCE_NAME + '/' + endpoint, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body:    JSON.stringify(data || {})
    });
}

document.getElementById('app').classList.add('hidden');

// --- FERMETURE avec TAB ou Echap ---
window.addEventListener('keydown', function(event) {
    if (event.key === "Escape") {
        if (QUANTITY_MODAL.visible) {
            event.preventDefault();
            closeQuantityModal();
            return;
        }
    }
    if (event.key === "Tab" || event.key === "Escape") {
        event.preventDefault();
        if (STATE.isVehicle) {
            // Fermer le coffre/boite a gants — ne pas ouvrir l'inventaire
            nuiFetch('closeVehicleInventory', {});
        } else {
            nuiFetch('closeInventory', {});
        }
    }
});

// --- MESSAGES DU LUA ---
window.addEventListener('message', function(event) {
    var data = event.data;

    if (data.action === "close" || data.action === "closeVehicle") {
        STATE.isVehicle = false;
        STATE.vehicleType = null;
        STATE.vehiclePlate = null;
        STATE.vehicleInventory = {};
        document.getElementById('app').classList.add('hidden');
        closeQuantityModal();
        var search = document.getElementById('player-search');
        if (search) search.value = '';
        // Restaurer le titre du panneau droite
        var groundTitle = document.querySelector('.ground-panel .panel-title');
        if (groundTitle) groundTitle.textContent = 'Sol';
        var groundIcon = document.querySelector('.ground-panel .head-icon i');
        if (groundIcon) groundIcon.className = 'fa-solid fa-box-open';
    }

    if (data.action === "open") {
        STATE.inventory = data.inventory || {};
        STATE.maxWeight = data.maxWeight || 120000;
        STATE.maxSlots = data.maxSlots || 41;
        if (data.hotbar) STATE.hotbar = data.hotbar;

        // Mode véhicule ?
        STATE.isVehicle = data.isVehicle || false;
        STATE.vehicleType = data.vehType || null;
        STATE.vehiclePlate = data.plate || null;

        if (STATE.isVehicle) {
            // Sauvegarder l'inventaire véhicule séparément
            STATE.vehicleInventory = data.inventory || {};
            STATE.vehicleMaxWeight = data.maxWeight || 100000;
            STATE.vehicleMaxSlots  = data.maxSlots  || 30;
            // Recharger l'inventaire JOUEUR depuis le state existant (pas écrasé)
            // On ne touche pas STATE.inventory ici
            renderVehiclePanel();
            // Rafraîchir l'inventaire joueur avec ses vraies données
            nuiFetch('getPlayerInventory', {});
        } else {
            STATE.vehicleInventory = {};
            renderGroundPanel();
        }

        renderPlayerGrid();
        renderWeight();
        if (typeof data.cash !== 'undefined') STATE.cash = data.cash;
        renderMoney();
        renderHotbar();
        // Synchroniser l'état stripped si le serveur nous le transmet
        if (typeof data.clothesStripped !== 'undefined') {
            STATE.clothesStripped = data.clothesStripped;
        }
        if (typeof data.maskOff !== 'undefined') {
            STATE.maskOff = data.maskOff;
        }
        document.getElementById('app').classList.remove('hidden');
        updateOutfitBtn();
        updateMaskSlot();
    }

    if (data.action === "openVehicleWithPlayer") {
        // Reçoit les deux inventaires séparément
        STATE.vehicleInventory = data.vehicleInventory || {};
        STATE.vehicleMaxWeight = data.maxVehicleWeight || 100000;
        STATE.vehicleMaxSlots  = data.maxVehicleSlots  || 30;
        STATE.inventory        = data.playerInventory  || {};
        STATE.maxWeight        = data.maxPlayerWeight  || 120000;
        STATE.maxSlots         = data.maxPlayerSlots   || 41;
        STATE.isVehicle        = true;
        STATE.vehicleType      = data.vehType;
        STATE.vehiclePlate     = data.plate;
        if (typeof data.cash !== 'undefined') STATE.cash = data.cash;
        if (data.hotbar) STATE.hotbar = data.hotbar;
        renderPlayerGrid();
        renderWeight();
        renderMoney();
        renderHotbar();
        renderVehiclePanel();
        document.getElementById('app').classList.remove('hidden');
    }

    if (data.action === "refreshVehicle") {
        STATE.vehicleInventory = data.vehicleInventory || {};
        STATE.inventory        = data.playerInventory  || STATE.inventory;
        if (typeof data.cash !== 'undefined') STATE.cash = data.cash;
        renderVehiclePanel();
        renderPlayerGrid();
        renderWeight();
        renderMoney();
        renderHotbar();
    }

    if (data.action === "refresh") {
        if (STATE.isVehicle) {
            STATE.vehicleInventory = data.inventory || {};
            renderVehiclePanel();
        } else {
            STATE.inventory = data.inventory || {};
            if (typeof data.cash !== 'undefined') STATE.cash = data.cash;
            renderPlayerGrid();
            renderWeight();
            renderMoney();
            renderHotbar();
        }
    }

    if (data.action === "refreshPlayer") {
        STATE.inventory = data.inventory || {};
        if (typeof data.cash !== 'undefined') STATE.cash = data.cash;
        renderPlayerGrid();
        renderWeight();
        renderMoney();
        renderHotbar();
    }

    if (data.action === "money") {
        if (typeof data.cash !== 'undefined') STATE.cash = data.cash;
        renderMoney();
    }

    if (data.action === "armor") {
        renderArmor(data.value || 0);
    }

    if (data.action === "groundUpdate") {
        STATE.groundDrops = data.drops || [];
        renderGroundGrid();
    }
});

// ===================================================================
// RENDU DE LA GRILLE D'INVENTAIRE
// ===================================================================
function getItemBySlot(slotNum) {
    slotNum = parseInt(slotNum, 10);
    for (var key in STATE.inventory) {
        var it = STATE.inventory[key];
        if (it && it.name) {
            var s = parseInt(it.slot || key, 10);
            if (s === slotNum) return it;
        }
    }
    return null;
}

function renderPlayerGrid() {
    var grid = document.getElementById('player-grid');
    if (!grid) return;
    grid.innerHTML = '';

    var bySlot = {};
    for (var key in STATE.inventory) {
        var it = STATE.inventory[key];
        if (it && it.name) {
            var s = parseInt(it.slot || key, 10);
            if (!isNaN(s)) bySlot[s] = it;
        }
    }

    var RESERVED_SLOTS = [40, 41];
    for (var i = 1; i <= STATE.maxSlots; i++) {
        if (RESERVED_SLOTS.indexOf(i) !== -1) continue;
        var item = bySlot[i];
        var slot = document.createElement('div');
        slot.className = 'slot';
        slot.dataset.slot = i;

        if (item) {
            var img = document.createElement('img');
            img.src = IMG_PATH + (item.image || 'placeholder.png');
            img.onerror = function() { this.style.opacity = '0.15'; };
            slot.appendChild(img);

            if (item.amount && item.amount > 1) {
                var amt = document.createElement('span');
                amt.className = 'amount';
                amt.textContent = 'x' + item.amount;
                slot.appendChild(amt);
            }

            var lbl = document.createElement('span');
            lbl.className = 'label';
            lbl.textContent = item.label || item.name || '';
            slot.appendChild(lbl);

            slot.addEventListener('mousemove', makeTooltipHandler(item));
            slot.addEventListener('mouseleave', hideTooltip);

            (function(capturedItem, capturedIndex) {
                slot.addEventListener('contextmenu', function(ev) {
                    ev.preventDefault();
                    hideTooltip();
                    openContextMenu(ev.clientX, ev.clientY, capturedIndex, capturedItem);
                });
            })(item, i);

            (function(capturedIndex) {
                slot.addEventListener('mousedown', function(ev) {
                    if (ev.button !== 0) return;
                    startManualDrag(ev, capturedIndex, slot);
                });
            })(i);
        } else {
            slot.classList.add('empty');
        }

        slot.dataset.dropTarget = i;
        grid.appendChild(slot);
    }
}

// ===================================================================
// POIDS
// ===================================================================
function renderWeight() {
    var total = 0;
    for (var k in STATE.inventory) {
        var it = STATE.inventory[k];
        if (it) total += (it.weight || 0) * (it.amount || 1);
    }
    var pct = Math.min(100, (total / STATE.maxWeight) * 100);

    var weightText = document.getElementById('weight-text');
    if (weightText) {
        weightText.textContent = (total / 1000).toFixed(1) + ' / ' + (STATE.maxWeight / 1000) + ' kg';
    }

    var weightFill = document.getElementById('weight-fill');
    if (weightFill) {
        weightFill.style.width = pct + '%';
    }
}

// ===================================================================
// TOOLTIP (infobulle au survol)
// ===================================================================
function makeTooltipHandler(item) {
    return function(ev) {
        var tt = document.getElementById('tooltip');
        var ttName = document.getElementById('tt-name');
        var ttDesc = document.getElementById('tt-desc');
        var ttWeight = document.getElementById('tt-weight');
        if (!tt) return;

        ttName.textContent = item.label || item.name || '';
        ttDesc.textContent = item.description || '';
        ttWeight.textContent = ((item.weight || 0) / 1000).toFixed(2) + ' kg';

        tt.classList.remove('hidden');
        var x = Math.min(ev.clientX + 14, window.innerWidth - 260);
        var y = Math.min(ev.clientY + 14, window.innerHeight - 120);
        tt.style.left = x + 'px';
        tt.style.top = y + 'px';
    };
}

function hideTooltip() {
    var tt = document.getElementById('tooltip');
    if (tt) tt.classList.add('hidden');
}

// ===================================================================
// RECHERCHE
// ===================================================================
var searchInput = document.getElementById('player-search');
if (searchInput) {
    searchInput.addEventListener('input', function() {
        var q = searchInput.value.trim().toLowerCase();
        var slots = document.getElementById('player-grid').querySelectorAll('.slot');
        slots.forEach(function(slot) {
            if (!q) { slot.style.opacity = ''; return; }
            var idx = slot.dataset.slot;
            var item = STATE.inventory[idx];
            if (!item) { slot.style.opacity = '0.2'; return; }
            var name = (item.label || item.name || '').toLowerCase();
            slot.style.opacity = name.includes(q) ? '' : '0.2';
        });
    });
}

// ===================================================================
// MODALE DE QUANTITE
// ===================================================================

var QUANTITY_MODAL = {
    visible: false,
    action: null,
    slotIndex: null,
    item: null
};

// Injecte la modale dans le DOM (une seule fois au chargement)
(function createQuantityModal() {
    var modal = document.createElement('div');
    modal.id = 'qty-modal';
    modal.style.cssText = [
        'display:none',
        'position:fixed',
        'inset:0',
        'z-index:9999',
        'align-items:center',
        'justify-content:center',
        'background:rgba(0,0,0,0.55)',
        'backdrop-filter:blur(4px)'
    ].join(';');

    modal.innerHTML = [
        '<div id="qty-box" style="',
            'background:linear-gradient(135deg,#1a1d2e 0%,#12141f 100%);',
            'border:1px solid rgba(255,255,255,0.08);',
            'border-radius:14px;',
            'padding:24px 28px;',
            'min-width:300px;',
            'max-width:360px;',
            'width:90%;',
            'box-shadow:0 20px 60px rgba(0,0,0,0.7);',
            'font-family:inherit;',
            'color:#fff;',
        '">',
            /* En-tête avec icône + nom item */
            '<div style="display:flex;align-items:center;gap:12px;margin-bottom:18px;">',
                '<img id="qty-item-img" src="" style="width:44px;height:44px;object-fit:contain;border-radius:8px;background:rgba(255,255,255,0.05);padding:4px;" onerror="this.style.opacity=\'0.15\'">',
                '<div>',
                    '<div id="qty-item-name" style="font-size:15px;font-weight:700;letter-spacing:.03em;"></div>',
                    '<div id="qty-action-label" style="font-size:12px;color:rgba(255,255,255,0.45);margin-top:2px;"></div>',
                '</div>',
            '</div>',

            /* Slider */
            '<div style="margin-bottom:14px;">',
                '<div style="display:flex;justify-content:space-between;font-size:11px;color:rgba(255,255,255,0.35);margin-bottom:6px;">',
                    '<span>1</span>',
                    '<span id="qty-max-label"></span>',
                '</div>',
                '<input id="qty-slider" type="range" min="1" max="1" value="1" style="',
                    'width:100%;',
                    'accent-color:var(--theme-color,#7c6ef8);',
                    'cursor:pointer;',
                    'height:4px;',
                '">',
            '</div>',

            /* Champ numérique centré */
            '<div style="display:flex;align-items:center;justify-content:center;gap:10px;margin-bottom:20px;">',
                '<button id="qty-minus" style="',
                    'width:32px;height:32px;border-radius:8px;border:1px solid rgba(255,255,255,0.1);',
                    'background:rgba(255,255,255,0.06);color:#fff;font-size:18px;cursor:pointer;',
                    'display:flex;align-items:center;justify-content:center;line-height:1;',
                '">−</button>',
                '<input id="qty-input" type="number" min="1" max="1" value="1" style="',
                    'width:80px;text-align:center;',
                    'background:rgba(255,255,255,0.06);',
                    'border:1px solid rgba(255,255,255,0.12);',
                    'border-radius:8px;padding:6px 8px;',
                    'color:#fff;font-size:18px;font-weight:700;',
                    'outline:none;',
                '">',
                '<button id="qty-plus" style="',
                    'width:32px;height:32px;border-radius:8px;border:1px solid rgba(255,255,255,0.1);',
                    'background:rgba(255,255,255,0.06);color:#fff;font-size:18px;cursor:pointer;',
                    'display:flex;align-items:center;justify-content:center;line-height:1;',
                '">+</button>',
            '</div>',

            /* Boutons Confirmer / Annuler */
            '<div style="display:flex;gap:10px;">',
                '<button id="qty-cancel" style="',
                    'flex:1;padding:10px;border-radius:9px;border:1px solid rgba(255,255,255,0.1);',
                    'background:rgba(255,255,255,0.05);color:rgba(255,255,255,0.6);',
                    'font-size:13px;cursor:pointer;font-weight:600;',
                '">Annuler</button>',
                '<button id="qty-confirm" style="',
                    'flex:2;padding:10px;border-radius:9px;border:none;',
                    'background:var(--theme-color,#7c6ef8);color:#fff;',
                    'font-size:13px;cursor:pointer;font-weight:700;',
                    'box-shadow:0 0 16px var(--theme-glow,rgba(124,110,248,0.4));',
                '" id="qty-confirm">Confirmer</button>',
            '</div>',
        '</div>'
    ].join('');

    document.body.appendChild(modal);

    // Synchronisation slider <-> input
    var slider = document.getElementById('qty-slider');
    var input  = document.getElementById('qty-input');

    slider.addEventListener('input', function() {
        input.value = slider.value;
    });
    input.addEventListener('input', function() {
        var v = parseInt(input.value, 10);
        var max = parseInt(slider.max, 10);
        if (isNaN(v) || v < 1) v = 1;
        if (v > max) v = max;
        input.value = v;
        slider.value = v;
    });

    // Boutons + / -
    document.getElementById('qty-minus').addEventListener('click', function() {
        var v = parseInt(input.value, 10);
        if (v > 1) { input.value = v - 1; slider.value = v - 1; }
    });
    document.getElementById('qty-plus').addEventListener('click', function() {
        var v = parseInt(input.value, 10);
        var max = parseInt(slider.max, 10);
        if (v < max) { input.value = v + 1; slider.value = v + 1; }
    });

    // Confirmer
    document.getElementById('qty-confirm').addEventListener('click', function() {
        var qty = parseInt(input.value, 10);
        var max = parseInt(slider.max, 10);
        if (isNaN(qty) || qty < 1) qty = 1;
        if (qty > max) qty = max;
        closeQuantityModal();
        executeContextAction(QUANTITY_MODAL.action, QUANTITY_MODAL.slotIndex, QUANTITY_MODAL.item, qty);
    });

    // Annuler
    document.getElementById('qty-cancel').addEventListener('click', closeQuantityModal);

    // Clic sur le fond = fermer
    modal.addEventListener('click', function(e) {
        if (e.target === modal) closeQuantityModal();
    });
})();

function openQuantityModal(action, slotIndex, item) {
    var max = item.amount || 1;

    // Si quantité = 1, on ne demande pas → on exécute directement
    if (max <= 1) {
        executeContextAction(action, slotIndex, item, 1);
        return;
    }

    QUANTITY_MODAL.visible = true;
    QUANTITY_MODAL.action = action;
    QUANTITY_MODAL.slotIndex = slotIndex;
    QUANTITY_MODAL.item = item;

    // Libellé de l'action
    var labels = { use: 'Utiliser', give: 'Donner', drop: 'Jeter' };
    var icons  = { use: '🖐', give: '🤝', drop: '🗑' };

    document.getElementById('qty-item-img').src = IMG_PATH + (item.image || 'placeholder.png');
    document.getElementById('qty-item-name').textContent = item.label || item.name || '';
    document.getElementById('qty-action-label').textContent = (icons[action] || '') + ' ' + (labels[action] || action);
    document.getElementById('qty-max-label').textContent = 'x' + max;

    var slider = document.getElementById('qty-slider');
    var input  = document.getElementById('qty-input');
    slider.max   = max;
    slider.value = max;   // par défaut : toute la quantité
    input.max    = max;
    input.value  = max;

    var modal = document.getElementById('qty-modal');
    modal.style.display = 'flex';
}

function closeQuantityModal() {
    QUANTITY_MODAL.visible = false;
    var modal = document.getElementById('qty-modal');
    if (modal) modal.style.display = 'none';
}

// ===================================================================
// MENU CLIC DROIT (Utiliser / Donner / Jeter)
// ===================================================================

var CONTEXT_MENU = null;

function closeContextMenu() {
    if (CONTEXT_MENU) {
        CONTEXT_MENU.remove();
        CONTEXT_MENU = null;
    }
}

window.addEventListener('click', closeContextMenu);
window.addEventListener('contextmenu', function (e) { e.preventDefault(); });

function openContextMenu(x, y, slotIndex, item) {
    closeContextMenu();

    var menu = document.createElement('div');
    menu.className = 'ctx-menu';
    menu.style.left = Math.min(x, window.innerWidth - 180) + 'px';
    menu.style.top = Math.min(y, window.innerHeight - 150) + 'px';

    var actions = [
        { key: 'use',  label: 'Utiliser', icon: 'fa-hand-pointer', show: !!item.useable },
        { key: 'give', label: 'Donner',   icon: 'fa-hand-holding', show: true },
        { key: 'drop', label: 'Jeter',    icon: 'fa-trash',        show: true }
    ];

    actions.forEach(function (act) {
        if (!act.show) return;
        var row = document.createElement('div');
        row.className = 'ctx-item';
        row.innerHTML = '<i class="fa-solid ' + act.icon + '"></i> ' + act.label;
        row.addEventListener('click', function (ev) {
            ev.stopPropagation();
            closeContextMenu();
            // Ouvre la modale de quantité (ou exécute directement si x1)
            handleContextAction(act.key, slotIndex, item);
        });
        menu.appendChild(row);
    });

    document.body.appendChild(menu);
    CONTEXT_MENU = menu;
}

// Décide si on ouvre la modale ou on exécute directement
function handleContextAction(action, slotIndex, item) {
    var amount = item.amount || 1;

    // "Utiliser" : on utilise toujours 1 à la fois → pas de modale
    if (action === 'use') {
        executeContextAction('use', slotIndex, item, 1);
        return;
    }

    // "Donner" / "Jeter" : modale si quantité > 1
    openQuantityModal(action, slotIndex, item);
}

// Envoie réellement l'action au Lua avec la quantité choisie
function executeContextAction(action, slotIndex, item, amount) {
    var endpoints = { use: 'useItem', give: 'giveItem', drop: 'dropItem' };
    var endpoint  = endpoints[action];
    if (!endpoint) return;
    nuiFetch(endpoint, { slot: slotIndex, amount: amount });
}


// ===================================================================
// DRAG & DROP
// ===================================================================

var DRAG_FROM = null;

// ===================================================================
// JAUGE D'ARMURE (gilet pare-balles)
// ===================================================================

function renderArmor(value) {
    var slot = document.getElementById('armor-slot');
    var bar  = document.getElementById('armor-bar');
    var fill = document.getElementById('armor-fill');
    var pct  = document.getElementById('armor-pct');
    if (!slot || !bar || !fill || !pct) return;

    value = Math.max(0, Math.min(100, Math.floor(Number(value) || 0)));

    if (value > 0) {
        slot.classList.add('equipped');
        bar.classList.remove('hidden');
        pct.classList.remove('hidden');
        fill.style.width = value + '%';
        pct.textContent = value + '%';
    } else {
        slot.classList.remove('equipped');
        bar.classList.add('hidden');
        pct.classList.add('hidden');
        fill.style.width = '0%';
        pct.textContent = '';
    }
}

(function setupArmorSlot() {
    var slot = document.getElementById('armor-slot');
    if (!slot) return;

    slot.addEventListener('click', function() {
        var isEquipped = slot.classList.contains('equipped');
        if (isEquipped) {
            nuiFetch('unequipArmor', {});
        } else {
            nuiFetch('equipArmor', {});
        }
    });
})();


// ===================================================================
// DRAG MANUEL A LA SOURIS
// ===================================================================

var MANUAL_DRAG = {
    active: false,
    fromSlot: null,
    ghost: null
};

function startManualDrag(ev, fromSlot, slotEl) {
    ev.preventDefault();
    hideTooltip();

    MANUAL_DRAG.active = true;
    MANUAL_DRAG.fromSlot = fromSlot;

    slotEl.classList.add('dragging');

    var ghost = document.createElement('div');
    ghost.className = 'drag-ghost';
    var item = getItemBySlot(fromSlot);
    if (item) {
        var img = document.createElement('img');
        img.src = IMG_PATH + (item.image || 'placeholder.png');
        img.onerror = function() { this.style.opacity = '0.15'; };
        ghost.appendChild(img);
    }
    document.body.appendChild(ghost);
    MANUAL_DRAG.ghost = ghost;
    moveGhost(ev.clientX, ev.clientY);

    document.addEventListener('mousemove', onManualDragMove);
    document.addEventListener('mouseup', onManualDragUp);
}

function moveGhost(x, y) {
    if (!MANUAL_DRAG.ghost) return;
    MANUAL_DRAG.ghost.style.left = (x - 30) + 'px';
    MANUAL_DRAG.ghost.style.top = (y - 30) + 'px';
}

function onManualDragMove(ev) {
    if (!MANUAL_DRAG.active) return;
    moveGhost(ev.clientX, ev.clientY);

    clearDragHighlights();
    var el = document.elementFromPoint(ev.clientX, ev.clientY);
    var dropZone = el ? el.closest('.slot, #give-drop') : null;
    if (dropZone) dropZone.classList.add('dragover');
}

function onManualDragUp(ev) {
    document.removeEventListener('mousemove', onManualDragMove);
    document.removeEventListener('mouseup', onManualDragUp);

    var fromSlot = MANUAL_DRAG.fromSlot;

    if (MANUAL_DRAG.ghost) MANUAL_DRAG.ghost.style.display = 'none';
    var el = document.elementFromPoint(ev.clientX, ev.clientY);

    clearDragHighlights();
    var dragging = document.querySelector('.slot.dragging');
    if (dragging) dragging.classList.remove('dragging');
    if (MANUAL_DRAG.ghost) { MANUAL_DRAG.ghost.remove(); MANUAL_DRAG.ghost = null; }
    MANUAL_DRAG.active = false;
    MANUAL_DRAG.fromSlot = null;

    if (fromSlot === null || fromSlot === undefined) return;
    if (!el) return;

    var fromSlotInt = parseInt(fromSlot, 10);

    // Cas 0a : lâché sur le slot TÉLÉPHONE (slot fixe 40)
    if (el.closest('#slot-phone')) {
        if (fromSlotInt !== 40) nuiFetch('moveItem', { fromSlot: fromSlotInt, toSlot: 40 });
        return;
    }

    // Cas 0b : lâché sur le slot RADIO (slot fixe 41)
    if (el.closest('#slot-radio')) {
        if (fromSlotInt !== 41) nuiFetch('moveItem', { fromSlot: fromSlotInt, toSlot: 41 });
        return;
    }

    // Cas 0c : lâché sur une case HOTBAR 1-5
    var hotbarEl = el.closest('.hotbar-slot');
    if (hotbarEl && typeof hotbarEl.dataset.hotbarKey !== 'undefined') {
        var draggedItem = getItemBySlot(fromSlot);
        if (draggedItem) assignToHotbar(hotbarEl.dataset.hotbarKey, draggedItem.name);
        return;
    }

    // Cas 1 : lâché sur la case DONNER
    if (el.closest('#give-drop')) {
        var giveItem = getItemBySlot(fromSlot);
        if (giveItem) openQuantityModal('give', fromSlot, giveItem);
        return;
    }

    // Cas 2 : lâché sur un autre slot
    var targetSlotEl = el.closest('.slot');
    if (targetSlotEl && typeof targetSlotEl.dataset.dropTarget !== 'undefined') {
        var toSlot = parseInt(targetSlotEl.dataset.dropTarget, 10);
        if (toSlot !== fromSlotInt) nuiFetch('moveItem', { fromSlot: fromSlotInt, toSlot: toSlot });
    }
}

function clearDragHighlights() {
    var hl = document.querySelectorAll('.dragover');
    for (var i = 0; i < hl.length; i++) hl[i].classList.remove('dragover');
}


// ===================================================================
// COLONNE SOL (drops au sol)
// ===================================================================

function renderGroundGrid() {
    var grid = document.getElementById('ground-grid');
    if (!grid) return;
    grid.innerHTML = '';

    var drops = STATE.groundDrops || [];

    var cases = [];
    for (var d = 0; d < drops.length; d++) {
        var drop = drops[d];
        if (!drop || !drop.items) continue;
        for (var idx = 0; idx < drop.items.length; idx++) {
            cases.push({ dropId: drop.id, itemIndex: idx + 1, item: drop.items[idx] });
        }
    }

    var totalCases = Math.max(cases.length, STATE.maxSlots || 41);

    for (var i = 0; i < totalCases; i++) {
        var slot = document.createElement('div');
        slot.className = 'slot';

        var entry = cases[i];
        if (entry) {
            var item = entry.item;

            var img = document.createElement('img');
            img.src = IMG_PATH + (item.image || 'placeholder.png');
            img.onerror = function() { this.style.opacity = '0.15'; };
            slot.appendChild(img);

            if (item.amount && item.amount > 1) {
                var amt = document.createElement('span');
                amt.className = 'amount';
                amt.textContent = 'x' + item.amount;
                slot.appendChild(amt);
            }

            var lbl = document.createElement('span');
            lbl.className = 'label';
            lbl.textContent = item.label || item.name || '';
            slot.appendChild(lbl);

            slot.addEventListener('mousemove', makeTooltipHandler(item));
            slot.addEventListener('mouseleave', hideTooltip);

            (function(dropId, itemIndex) {
                slot.addEventListener('click', function() {
                    hideTooltip();
                    nuiFetch('pickupDrop', { dropId: dropId, itemIndex: itemIndex });
                });
            })(entry.dropId, entry.itemIndex);

            slot.style.cursor = 'pointer';
        } else {
            slot.classList.add('empty');
        }

        grid.appendChild(slot);
    }
}


// ===================================================================
// HOTBAR (raccourcis 1-5)
// ===================================================================

if (!STATE.hotbar) STATE.hotbar = {};

function renderHotbar() {
    // --- Slots hotbar 1-5 ---
    var slots = document.querySelectorAll('.hotbar-slot');
    slots.forEach(function(slotEl) {
        var key = slotEl.dataset.key;
        var num = slotEl.querySelector('.hotbar-num');
        slotEl.innerHTML = '';

        if (num) {
            slotEl.appendChild(num);
        } else {
            var n = document.createElement('span');
            n.className = 'hotbar-num';
            n.textContent = key;
            slotEl.appendChild(n);
        }

        var itemName = STATE.hotbar[key];
        if (itemName) {
            var found = null;
            for (var k in STATE.inventory) {
                var it = STATE.inventory[k];
                if (it && it.name === itemName) { found = it; break; }
            }

            var img = document.createElement('img');
            img.src = IMG_PATH + ((found && found.image) ? found.image : (itemName + '.png'));
            img.onerror = function() { this.style.opacity = '0.2'; };
            slotEl.appendChild(img);

            if (found) {
                var total = 0;
                for (var k2 in STATE.inventory) {
                    var it2 = STATE.inventory[k2];
                    if (it2 && it2.name === itemName) total += (it2.amount || 1);
                }
                var amt = document.createElement('span');
                amt.className = 'hotbar-amount';
                amt.textContent = 'x' + total;
                slotEl.appendChild(amt);
            }
        }
    });

    // --- Slots fixes téléphone (40) et radio (41) ---
    renderSpecialSlot('slot-phone', 40, 'fa-mobile-screen', 'Téléphone');
    renderSpecialSlot('slot-radio', 41, 'fa-tower-broadcast', 'Radio');
}

function renderSpecialSlot(elemId, slotNum, iconClass, defaultLabel) {
    var el = document.getElementById(elemId);
    if (!el) return;

    var item = getItemBySlot(slotNum);
    el.innerHTML = '';

    if (item) {
        // Item présent : afficher l'image et le label de l'item
        var img = document.createElement('img');
        img.src = IMG_PATH + (item.image || 'placeholder.png');
        img.onerror = function() { this.style.opacity = '0.15'; };
        img.style.cssText = 'width:38px;height:38px;object-fit:contain;';
        el.appendChild(img);

        var lbl = document.createElement('span');
        lbl.className = 'info-slot-label';
        lbl.textContent = item.label || item.name || defaultLabel;
        el.appendChild(lbl);

        // Clic droit pour retirer (envoyer vers premier slot libre)
        el.oncontextmenu = function(ev) {
            ev.preventDefault();
            // Trouver le premier slot libre entre 1 et 39
            var freeSlot = null;
            for (var i = 1; i <= 39; i++) {
                if (!getItemBySlot(i)) { freeSlot = i; break; }
            }
            if (freeSlot === null) return;
            nuiFetch('moveItem', { fromSlot: slotNum, toSlot: freeSlot });
        };
    } else {
        // Slot vide : afficher l'icône et le label par défaut
        var ico = document.createElement('i');
        ico.className = 'fa-solid ' + iconClass + ' info-slot-icon';
        el.appendChild(ico);

        var lbl = document.createElement('span');
        lbl.className = 'info-slot-label';
        lbl.textContent = defaultLabel;
        el.appendChild(lbl);

        el.oncontextmenu = null;
    }
}

(function setupHotbar() {
    // Uniquement les slots 1-5 (pas les info-slots phone/radio)
    var slots = document.querySelectorAll('.hotbar-slot');
    slots.forEach(function(slotEl) {
        var key = slotEl.dataset.key;
        // Ignorer les anciens info-slots s'il en reste
        if (!key || isNaN(parseInt(key, 10))) return;
        slotEl.dataset.hotbarKey = key;

        slotEl.addEventListener('contextmenu', function(ev) {
            ev.preventDefault();
            if (STATE.hotbar[key]) {
                delete STATE.hotbar[key];
                saveHotbar();
                renderHotbar();
            }
        });
    });
})();

function saveHotbar() {
    nuiFetch('saveHotbar', { hotbar: STATE.hotbar });
}

function assignToHotbar(key, itemName) {
    STATE.hotbar[key] = itemName;
    saveHotbar();
    renderHotbar();
}

// ===================================================================
// PANNEAU VÉHICULE (remplace le panneau Sol quand un véhicule est ouvert)
// ===================================================================

function renderGroundPanel() {
    // Restaurer le panneau Sol normal
    var groundTitle = document.querySelector('.ground-panel .panel-title');
    if (groundTitle) groundTitle.textContent = 'Sol';
    var groundIcon = document.querySelector('.ground-panel .head-icon i');
    if (groundIcon) groundIcon.className = 'fa-solid fa-box-open';
    var weightText = document.getElementById('ground-weight-text');
    if (weightText) weightText.textContent = '0 / 9999 kg';
    renderGroundGrid();
}

function renderVehiclePanel() {
    // Changer le titre du panneau droite
    var label = STATE.vehicleType === 'trunk' ? 'Coffre' : 'Boîte à gants';
    var icon  = STATE.vehicleType === 'trunk' ? 'fa-car-side' : 'fa-glove-boxing';

    var groundTitle = document.querySelector('.ground-panel .panel-title');
    if (groundTitle) groundTitle.textContent = label + (STATE.vehiclePlate ? ' — ' + STATE.vehiclePlate : '');

    var groundIcon = document.querySelector('.ground-panel .head-icon i');
    if (groundIcon) groundIcon.className = 'fa-solid ' + icon;

    // Poids
    var totalW = 0;
    for (var k in STATE.vehicleInventory) {
        var it = STATE.vehicleInventory[k];
        if (it) totalW += (it.weight || 0) * (it.amount || 1);
    }
    var maxW = STATE.vehicleMaxWeight || 100000;
    var weightText = document.getElementById('ground-weight-text');
    if (weightText) weightText.textContent = (totalW / 1000).toFixed(1) + ' / ' + (maxW / 1000) + ' kg';

    // Grille
    var grid = document.getElementById('ground-grid');
    if (!grid) return;
    grid.innerHTML = '';

    var bySlot = {};
    for (var key in STATE.vehicleInventory) {
        var it = STATE.vehicleInventory[key];
        if (it && it.name) {
            var s = parseInt(it.slot || key, 10);
            if (!isNaN(s)) bySlot[s] = it;
        }
    }

    var maxSlots = STATE.vehicleMaxSlots || 30;
    for (var i = 1; i <= maxSlots; i++) {
        var item = bySlot[i];
        var slot = document.createElement('div');
        slot.className = 'slot';
        slot.dataset.slot = i;
        slot.dataset.vehicleSlot = i;

        if (item) {
            var img = document.createElement('img');
            img.src = IMG_PATH + (item.image || 'placeholder.png');
            img.onerror = function() { this.style.opacity = '0.15'; };
            slot.appendChild(img);

            if (item.amount && item.amount > 1) {
                var amt = document.createElement('span');
                amt.className = 'amount';
                amt.textContent = 'x' + item.amount;
                slot.appendChild(amt);
            }

            var lbl = document.createElement('span');
            lbl.className = 'label';
            lbl.textContent = item.label || item.name || '';
            slot.appendChild(lbl);

            slot.addEventListener('mousemove', makeTooltipHandler(item));
            slot.addEventListener('mouseleave', hideTooltip);

            // Clic gauche = reprendre l'item dans l'inventaire joueur
            (function(capturedSlot, capturedItem) {
                slot.addEventListener('click', function() {
                    hideTooltip();
                    nuiFetch('moveFromVehicle', { fromSlot: capturedSlot, amount: capturedItem.amount || 1 });
                });
            })(i, item);

            slot.style.cursor = 'pointer';
            slot.title = 'Clic gauche pour reprendre';
        } else {
            slot.classList.add('empty');
        }

        grid.appendChild(slot);
    }
}

// ===================================================================
// BOUTON TENUE — Toggle déshabiller / rhabiller
// ===================================================================

function updateOutfitBtn() {
    var btn   = document.getElementById('btn-strip-clothes');
    var icon  = document.getElementById('outfit-icon');
    var label = document.getElementById('outfit-label');
    if (!btn) return;

    if (STATE.clothesStripped) {
        btn.classList.add('stripped');
        icon.className  = 'fa-solid fa-person';
        label.textContent = 'RHABILLER';
    } else {
        btn.classList.remove('stripped');
        icon.className  = 'fa-solid fa-shirt';
        label.textContent = 'TENUE';
    }
}

document.getElementById('btn-strip-clothes').addEventListener('click', function() {
    if (STATE.clothesStripped) {
        // Remettre la tenue
        nuiFetch('restoreClothes', {});
        STATE.clothesStripped = false;
    } else {
        // Enlever la tenue
        nuiFetch('stripClothes', {});
        STATE.clothesStripped = true;
    }
    updateOutfitBtn();
});

// ===================================================================
// SLOT MASQUE — Toggle enlever / remettre
// ===================================================================

(function setupMaskSlot() {
    var btn = document.getElementById('btn-strip-mask');
    if (!btn) return;

    btn.addEventListener('click', function() {
        if (STATE.maskOff) {
            nuiFetch('restoreMask', {});
            STATE.maskOff = false;
        } else {
            nuiFetch('stripMask', {});
            STATE.maskOff = true;
        }
        updateMaskSlot();
    });
})();

function updateMaskSlot() {
    var btn   = document.getElementById('btn-strip-mask');
    var icon  = document.getElementById('mask-icon');
    var label = document.getElementById('mask-label');
    if (!btn) return;

    if (STATE.maskOff) {
        btn.classList.add('stripped');
        icon.className  = 'fa-solid fa-face-smile';
        label.textContent = 'REMETTRE';
    } else {
        btn.classList.remove('stripped');
        icon.className  = 'fa-solid fa-masks-theater';
        label.textContent = 'MASQUE';
    }
}

// Glisser un item de l'inventaire joueur vers le véhicule
document.addEventListener('mouseup', function(ev) {
    if (!STATE.isVehicle) return;
    if (!MANUAL_DRAG.active) return;

    var el = document.elementFromPoint(ev.clientX, ev.clientY);
    if (!el) return;
    var groundGrid = el.closest('#ground-grid');
    if (!groundGrid) return;

    var fromSlot = MANUAL_DRAG.fromSlot;
    if (fromSlot === null || fromSlot === undefined) return;

    var item = getItemBySlot(parseInt(fromSlot, 10));
    var amount = item ? (item.amount || 1) : 1;

    nuiFetch('moveToVehicle', { fromSlot: parseInt(fromSlot, 10), amount: amount });
    // Ne pas mettre à jour le STATE localement — attendre le refresh serveur
}, true);
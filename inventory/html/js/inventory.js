var type = "normal";
var disabled = false;
var storedItems = [];
var storedFastItems = [];
var storedCrMenu = '';
var activeSortBy = null;
var activeSortDir = 'asc';
var equippedClothes = {}; // { slotType: itemData }
var equippedOutfit   = null; // outfit item data or null
var outfitEditMode   = false; // vrai quand on édite une tenue depuis l'inventaire
var outfitEditSlots  = {}; // slot → {data:[draw,tex], fromInventory:bool, item:null|itemData}

// ── Helper drag fixe ──
function createDragHelper(el) {
    return $('<div class="drag-helper">').css('background-image', el.css('background-image'));
}

// ── Items filtrés (sans les vêtements équipés) + tri ──
function getFilteredItems() {
    var equippedIds = {};
    Object.keys(equippedClothes).forEach(function(slotType) {
        var it = equippedClothes[slotType];
        if (it && it.uniqueId !== undefined) equippedIds[it.uniqueId] = true;
    });
    if (equippedOutfit && equippedOutfit.uniqueId != null) {
        equippedIds[equippedOutfit.uniqueId] = true;
    }
    if (outfitEditMode) {
        Object.keys(outfitEditSlots).forEach(function(slotType) {
            var es = outfitEditSlots[slotType];
            if (es.fromInventory && es.item && es.item.uniqueId !== undefined) {
                equippedIds[es.item.uniqueId] = true;
            }
        });
    }
    var fastIds = {};
    var fastNames = {};
    (storedFastItems || []).forEach(function(it) {
        if (it.uniqueId !== undefined && it.uniqueId !== null) fastIds[it.uniqueId] = true;
        else if (it.name) fastNames[it.name] = true;
    });
    var display = storedItems.filter(function(item) {
        if (item.uniqueId !== undefined) return !equippedIds[item.uniqueId] && !fastIds[item.uniqueId];
        return !equippedClothes.hasOwnProperty(item.name) && !fastNames.hasOwnProperty(item.name);
    });
    if (activeSortBy === 'az') {
        display.sort(function(a, b) {
            var c = a.label.localeCompare(b.label, 'fr', { sensitivity: 'base' });
            return activeSortDir === 'asc' ? c : -c;
        });
    } else if (activeSortBy === 'count') {
        display.sort(function(a, b) {
            return activeSortDir === 'asc' ? b.count - a.count : a.count - b.count;
        });
    }
    return display;
}

// ── Vide un slot vêtement et le rend non-draggable ──
function clearClothSlot(slotEl) {
    var itemEl = slotEl.find('.cloth-slot-item');
    if (itemEl.hasClass('ui-draggable')) itemEl.draggable('destroy');
    itemEl.css('background-image', '').removeData('item').removeData('inventory');
    slotEl.removeClass('filled');
}

// ── Sync slots vêtements (retire les items qui ne sont plus en inventaire) ──
function syncClothSlots() {
    Object.keys(equippedClothes).forEach(function(slotType) {
        var itemData = equippedClothes[slotType];
        var still = storedItems.some(function(it) {
            return itemData.uniqueId !== undefined ? it.uniqueId === itemData.uniqueId : it.name === itemData.name;
        });
        if (!still) {
            delete equippedClothes[slotType];
            clearClothSlot($('.cloth-slot[data-slot-type="' + slotType + '"]'));
        }
    });
}

// ── Applique les slots équipés sauvegardés (après chargement items) ──
function applyEquippedSlots(slots) {
    Object.keys(slots).forEach(function(slotType) {
        var savedItem = slots[slotType];
        var matchingItem = null;
        for (var i = 0; i < storedItems.length; i++) {
            if (savedItem.uniqueId !== undefined && storedItems[i].uniqueId === savedItem.uniqueId) { matchingItem = storedItems[i]; break; }
        }
        if (!matchingItem) {
            for (var i = 0; i < storedItems.length; i++) {
                if (storedItems[i].name === savedItem.name) { matchingItem = storedItems[i]; break; }
            }
        }
        if (!matchingItem) return;
        equippedClothes[slotType] = matchingItem;
        var slot = $('.cloth-slot[data-slot-type="' + slotType + '"]');
        var itemEl = slot.find('.cloth-slot-item');
        itemEl.css('background-image', "url('img/items/" + matchingItem.name + ".png')");
        itemEl.data('item', matchingItem).data('inventory', 'clothSlot');
        slot.addClass('filled');
        if (itemEl.hasClass('ui-draggable')) itemEl.draggable('destroy');
        itemEl.draggable({ helper: function() { return createDragHelper($(this)); }, appendTo: 'body', zIndex: 99999, revert: 'invalid' });
    });
}


// ── Outfit slot helpers ───────────────────────────
function setOutfitSlotLocked(locked) {
    if (locked) {
        $('.cloth-slot').addClass('cloth-slot-outfit-locked');
        $('#outfitLockBadge').show();
    } else {
        $('.cloth-slot').removeClass('cloth-slot-outfit-locked');
        $('#outfitLockBadge').hide();
    }
}

function applyEquippedOutfit(outfitData) {
    equippedOutfit = outfitData;
    var $slot = $('#outfitSlot');
    var $item = $slot.find('.outfit-slot-item');

    if (outfitData) {
        $item.css('background-image', "url('img/items/outfit.png')");
        $item.data('item', outfitData).data('inventory', 'outfitSlot');
        $slot.addClass('filled');
        setOutfitSlotLocked(true);

        // Clear all individual cloth slots visually (outfit takes over)
        Object.keys(equippedClothes).forEach(function(slotType) {
            clearClothSlot($('.cloth-slot[data-slot-type="' + slotType + '"]'));
        });
        equippedClothes = {};

        // Make outfit item draggable (to unequip)
        if ($item.hasClass('ui-draggable')) $item.draggable('destroy');
        $item.draggable({
            helper: function() { return createDragHelper($item); },
            appendTo: 'body',
            zIndex: 99999,
            revert: 'invalid'
        });
    } else {
        $item.css('background-image', '').removeData('item').removeData('inventory');
        if ($item.hasClass('ui-draggable')) $item.draggable('destroy');
        $slot.removeClass('filled');
        setOutfitSlotLocked(false);
    }
}

// ── Mode édition d'une tenue : entre en édition ──
function enterOutfitEditMode() {
    if (!equippedOutfit || !equippedOutfit.data) return;
    outfitEditMode  = true;
    outfitEditSlots = {};

    // Débloquer les slots individuels
    $('.cloth-slot').removeClass('cloth-slot-outfit-locked');
    $('#outfitLockBadge').addClass('outfit-lock-edit');
    $('#controls').addClass('outfit-edit-active');

    // Afficher chaque vêtement de la tenue dans son slot
    var outfitData = equippedOutfit.data;
    Object.keys(outfitData).forEach(function(slotType) {
        var vals    = outfitData[slotType];
        var drawable = Array.isArray(vals) ? (vals[0] || 0) : (vals && vals.drawable || 0);
        var texture  = Array.isArray(vals) ? (vals[1] || 0) : (vals && vals.texture  || 0);
        outfitEditSlots[slotType] = { data: [drawable, texture], fromInventory: false, item: null };
        var $slot   = $('.cloth-slot[data-slot-type="' + slotType + '"]');
        var $itemEl = $slot.find('.cloth-slot-item');
        $itemEl.css('background-image', "url('img/items/" + slotType + ".png')");
        $itemEl.data('item', { name: slotType, data: [drawable, texture] });
        $itemEl.data('inventory', 'outfitEditSlot');
        $slot.addClass('filled');
        if ($itemEl.hasClass('ui-draggable')) $itemEl.draggable('destroy');
        $itemEl.draggable({ helper: function() { return createDragHelper($(this)); }, appendTo: 'body', zIndex: 99999, revert: 'invalid' });
    });

    renderInventoryGrid(getFilteredItems());
    initMainDraggables();
}

// ── Mode édition : quitter (save=true → enregistre la tenue) ──
function exitOutfitEditMode(save) {
    if (!outfitEditMode) return;

    if (save && equippedOutfit) {
        var newSlots      = {};
        var consumedItems = [];
        var removedSlots  = {};

        // Slots de la tenue originale supprimés ou remplacés → retournés comme items
        if (equippedOutfit.data) {
            Object.keys(equippedOutfit.data).forEach(function(slotType) {
                if (!outfitEditSlots[slotType]) {
                    // Slot complètement retiré
                    removedSlots[slotType] = equippedOutfit.data[slotType];
                } else if (outfitEditSlots[slotType].fromInventory) {
                    // Slot remplacé par un item d'inventaire → rendre l'original
                    removedSlots[slotType] = equippedOutfit.data[slotType];
                }
            });
        }

        Object.keys(outfitEditSlots).forEach(function(slotType) {
            var es = outfitEditSlots[slotType];
            newSlots[slotType] = es.data;
            if (es.fromInventory && es.item) {
                consumedItems.push({ uniqueId: es.item.uniqueId, name: es.item.name });
            }
        });

        // Mettre à jour les données locales de la tenue
        equippedOutfit.data = newSlots;

        $.post('http://lslegacy/SaveOutfitFromInventory', JSON.stringify({
            outfitUniqueId: equippedOutfit.uniqueId,
            outfitLabel:    equippedOutfit.label,
            newSlots:       newSlots,
            consumedItems:  consumedItems,
            removedSlots:   removedSlots
        }));
    }

    outfitEditMode  = false;
    outfitEditSlots = {};

    // Vider les slots individuels et rebloquer
    $('.cloth-slot').each(function() { clearClothSlot($(this)); });
    equippedClothes = {};
    setOutfitSlotLocked(true);
    $('#outfitLockBadge').removeClass('outfit-lock-edit');
    $('#controls').removeClass('outfit-edit-active');

    renderInventoryGrid(getFilteredItems());
    initMainDraggables();
}

// ── Affichage inventaire principal ──
function renderInventoryGrid(items) {
    $("#playerInventory").html("");
    $.each(items, function(index, item) {
        var count = setCount(item);
        $("#playerInventory").append(
            '<div class="slot">' +
            '<div id="item-' + index + '" class="item" style="background-image:url(\'img/items/' + item.name + '.png\')">' +
            '<div class="item-count">' + count + '</div>' +
            '<div class="item-name">' + item.label + '</div>' +
            '</div>' +
            '</div>'
        );
        $('#item-' + index).data('item', item);
        if (item.data !== undefined && item.data.durability !== undefined) {
            var durPercent = Number(item.data.durability);
            var color = durPercent > 30 ? "green" : durPercent > 20 ? "orange" : "red";
            $('#item-' + index).append($('<div class="durability-bar">').css({ width: durPercent + '%', backgroundColor: color }));
        }
        $('#item-' + index).data('inventory', "main");
    });
}

// ── Tri et re-rendu (bidirectionnel) ──
function applySortAndRender(criteria) {
    if (activeSortBy === criteria) {
        // Inverser la direction
        activeSortDir = activeSortDir === 'asc' ? 'desc' : 'asc';
    } else {
        activeSortBy = criteria;
        activeSortDir = 'asc';
    }
    // Mise à jour texte boutons
    $('.sort-btn[data-sort="az"]').text(
        activeSortBy === 'az' ? (activeSortDir === 'asc' ? 'A↓Z' : 'Z↓A') : 'A↓Z'
    ).toggleClass('active', activeSortBy === 'az');
    $('.sort-btn[data-sort="count"]').text(
        activeSortBy === 'count' ? (activeSortDir === 'asc' ? '9→1' : '1→9') : '9→1'
    ).toggleClass('active', activeSortBy === 'count');

    renderInventoryGrid(getFilteredItems());
    initMainDraggables();
}

// ── Setup inventaire (stockage + rendu) ──
function inventorySetup(items, fastItems, crMenu, equippedSlots, equippedOutfitData) {
    storedItems = items;
    storedFastItems = fastItems;
    storedCrMenu = crMenu;

    if (crMenu === 'items' || crMenu === 'clothes') {
        if (equippedOutfitData) {
            applyEquippedOutfit(equippedOutfitData);
        } else {
            applyEquippedOutfit(null);
            if (equippedSlots) {
                applyEquippedSlots(equippedSlots);
            }
            syncClothSlots();
        }
    }
    renderInventoryGrid(getFilteredItems());

    if (crMenu === "weapons") { $("#unload").show(); } else { $("#unload").hide(); }

    $("#playerInventoryFastItems").html("");
    for (var i = 1; i < 6; i++) {
        $("#playerInventoryFastItems").append(
            '<div class="slotFast"><div id="itemFast-' + i + '" class="item">' +
            '<div class="keybind">' + i + '</div><div class="item-count"></div><div class="item-name"></div>' +
            '</div></div>'
        );
    }
    $.each(fastItems, function(index, item) {
        var count = setCount(item);
        $('#itemFast-' + item.slot).css("background-image", 'url(\'img/items/' + item.name + '.png\')');
        $('#itemFast-' + item.slot).html(
            '<div class="keybind">' + item.slot + '</div>' +
            '<div class="item-count">' + count + '</div>' +
            '<div class="item-name">' + item.label + '</div>'
        );
        $('#itemFast-' + item.slot).data('item', item);
        $('#itemFast-' + item.slot).data('inventory', "fast");
    });
    makeDraggables();
}

// ── Échange la position de deux items de l'inventaire principal (drag & drop sur un slot occupé) ──
function swapMainInventoryItems(itemA, itemB) {
    var idxA = storedItems.indexOf(itemA);
    var idxB = storedItems.indexOf(itemB);
    if (idxA === -1 || idxB === -1 || idxA === idxB) return;

    storedItems[idxA] = itemB;
    storedItems[idxB] = itemA;

    // Un tri actif écraserait le rangement manuel : on repasse en ordre libre.
    activeSortBy = null;
    activeSortDir = 'asc';
    $('.sort-btn').removeClass('active').each(function() {
        var $btn = $(this);
        $btn.text($btn.data('sort') === 'az' ? 'A↓Z' : '9→1');
    });

    renderInventoryGrid(getFilteredItems());
    initMainDraggables();

    $.post('http://lslegacy/SwapItemPosition', JSON.stringify({
        itemA: { uniqueId: itemA.uniqueId, name: itemA.name, label: itemA.label },
        itemB: { uniqueId: itemB.uniqueId, name: itemB.name, label: itemB.label }
    }));
}

// ── Init draggables inventaire principal ──
function initMainDraggables() {
    $('.item').draggable({
        helper: function() { return createDragHelper($(this)); },
        appendTo: 'body',
        zIndex: 99999,
        revert: 'invalid',
        start: function(event, ui) {
            if (disabled) return false;
            $(this).css('background-image', 'none');
            itemData = $(this).data("item");
            $("#drop, #give, #rename, #use").addClass("disabled");
            if (itemData !== undefined && itemData.name !== undefined) {
                $(this).css('background-image', 'url(\'img/items/' + itemData.name + '.png\'');
                $("#drop, #give, #rename, #use").removeClass("disabled");
            }
        },
        stop: function() {
            itemData = $(this).data("item");
            if (itemData !== undefined && itemData.name !== undefined) {
                $(this).css('background-image', 'url(\'img/items/' + itemData.name + '.png\'');
                $("#drop, #give, #rename, #use").removeClass("disabled");
            }
        }
    });

    // Slots de l'inventaire principal : accepte un autre item du même inventaire pour échanger leur place.
    $('#playerInventory .item').droppable({
        accept: function(draggable) {
            return disabled !== true && draggable.data('inventory') === 'main' && draggable[0] !== $(this)[0];
        },
        hoverClass: 'hoverSlot',
        drop: function(event, ui) {
            if (disabled) return;
            var draggedItem = ui.draggable.data('item');
            var draggedInventory = ui.draggable.data('inventory');
            var targetItem = $(this).data('item');
            if (draggedInventory !== 'main' || !draggedItem || !targetItem) return;
            swapMainInventoryItems(draggedItem, targetItem);
        }
    });
}

// ── Init draggables second inventaire ──
function initSecondDraggables() {
    $('.item').draggable({
        helper: function() { return createDragHelper($(this)); },
        appendTo: 'body',
        zIndex: 99999,
        revert: 'invalid',
        start: function(event, ui) {
            if (disabled) return false;
            $(this).css('background-image', 'none');
            var itemData = $(this).data("item");
            var inventoryType = $(this).data("inventory");
            if (inventoryType === "second") {
                $("#drop, #give, #rename, #use").addClass("disabled");
            }
        },
        stop: function() {
            var itemData = $(this).data("item");
            var inventoryType = $(this).data("inventory");
            if (itemData !== undefined && itemData.name !== undefined) {
                $(this).css('background-image', 'url(\'img/items/' + itemData.name + '.png\'');
            }
            if (inventoryType === "main") {
                $("#drop, #give, #rename, #use").removeClass("disabled");
            }
        }
    });
}

// ── Réception des messages NUI ──
window.addEventListener("message", function(event) {
    if (event.data.action == "display") {
        type = event.data.type;
        disabled = false;

        if (type === "normal") { $(".info-div").hide(); }
        else if (type === "trunk" || type === "player") { $(".info-div").show(); }
        else { $(".info-div").hide(); }

        $("#rightPanel").addClass("panel-hidden");
        $(".ui").addClass("ui-visible");

    } else if (event.data.action == "hide") {
        if (outfitEditMode) exitOutfitEditMode(false); // annuler l'édition en cours
        closeItemContextMenu();
        $(".ui").removeClass("ui-visible");
        $(".item").remove();
        $("#otherInventory").html("<div id=\"noSecondInventoryMessage\"></div>");
        $("#rightPanel").addClass("panel-hidden");
        // Keep outfit state across inventory sessions — do NOT reset equippedOutfit

    } else if (event.data.action == "setItems") {
        closeItemContextMenu();
        inventorySetup(event.data.itemList, event.data.fastItems, event.data.crMenu, event.data.equippedSlots, event.data.equippedOutfit);
        $(".info-div2").html(event.data.text);
        initMainDraggables();

    } else if (event.data.action == "setSecondInventoryItems") {
        $("#rightPanel").removeClass("panel-hidden");
        secondInventorySetup(event.data.itemList, event.data.fastItems);
        initSecondDraggables();

    } else if (event.data.action == "setShopInventoryItems") {
        $("#rightPanel").removeClass("panel-hidden");
        shopInventorySetup(event.data.itemList);

    } else if (event.data.action == "setInfoText") {
        $(".info-div").html(event.data.text);

    } else if (event.data.action == "setWeightText") {
        $(".weight-div").html(event.data.text);

    } else if (event.data.action == "setEquippedOutfit") {
        applyEquippedOutfit(event.data.outfit || null);

    } else if (event.data.action == "setEquippedSlots") {
        // no-op: equipped slots are now sent directly with setItems

    } else if (event.data.action == "updateFastAmmo") {
        var slot = event.data.slot;
        var ammo = event.data.ammo;
        var $fastItem = $('#itemFast-' + slot);
        if ($fastItem.length) {
            var countHtml = ammo > 0 ? '<img src="img/bullet.png" class="ammoIcon"> ' + ammo : '';
            $fastItem.find('.item-count').html(countHtml);
        }
        if (storedFastItems) {
            $.each(storedFastItems, function(i, item) {
                if (item && item.slot == slot) { item.ammo = ammo; }
            });
        }

    } else if (event.data.action == "nearPlayers") {
        $("#nearPlayers").html("");
        $.each(event.data.players, function(index, player) {
            $("#nearPlayers").append('<button class="nearbyPlayerButton" data-player="' + player.player + '">' + player.label + ' (' + player.player + ')</button>');
        });
        if ($.fn.dialog) { $("#dialog").dialog("open"); }
        $(".nearbyPlayerButton").click(function() {
            if ($.fn.dialog) { $("#dialog").dialog("close"); }
            var player = $(this).data("player");
            $.post("http://lslegacy/GiveItem", JSON.stringify({
                player: player,
                item: event.data.item,
                number: parseInt($("#count").val())
            }));
        });
    }
});

// ── Second inventaire ──
function secondInventorySetup(items, fastItems) {
    $("#otherInventory").html("");
    $.each(items, function(index, item) {
        var count = setCount(item);
        $("#otherInventory").append(
            '<div class="slot"><div id="itemOther-' + index + '" class="item" style="background-image:url(\'img/items/' + item.name + '.png\')">' +
            '<div class="item-count">' + count + '</div><div class="item-name">' + item.label + '</div>' +
            '</div></div>'
        );
        $('#itemOther-' + index).data('item', item);
        if (item.data !== undefined && item.data.durability !== undefined) {
            var durPercent = Number(item.data.durability);
            var color = durPercent > 30 ? "green" : durPercent > 20 ? "orange" : "red";
            $('#itemOther-' + index).append($('<div class="durability-bar">').css({ width: durPercent + '%', backgroundColor: color }));
        }
        $('#itemOther-' + index).data('inventory', "second");
    });

    $("#playerInventoryFastItems").html("");
    for (var i = 1; i < 6; i++) {
        $("#playerInventoryFastItems").append(
            '<div class="slotFast"><div id="itemFast-' + i + '" class="item">' +
            '<div class="keybind">' + i + '</div><div class="item-count"></div><div class="item-name"></div>' +
            '</div></div>'
        );
    }
    $.each(fastItems, function(index, item) {
        var count = setCount(item);
        $('#itemFast-' + item.slot).css("background-image", 'url(\'img/items/' + item.name + '.png\')');
        $('#itemFast-' + item.slot).html(
            '<div class="keybind">' + item.slot + '</div>' +
            '<div class="item-count">' + count + '</div>' +
            '<div class="item-name">' + item.label + '</div>'
        );
        $('#itemFast-' + item.slot).data('item', item);
        $('#itemFast-' + item.slot).data('inventory', "fast");
    });
    makeDraggables();
}

// ── Shop inventaire ──
function shopInventorySetup(items) {
    $("#otherInventory").html("");
    $.each(items, function(index, item) {
        var cost = item.cost !== undefined ? '$' + item.cost : setCount(item);
        $("#otherInventory").append(
            '<div class="slot"><div id="itemOther-' + index + '" class="item" style="background-image:url(\'img/items/' + item.name + '.png\')">' +
            '<div class="item-count">' + cost + '</div><div class="item-name">' + item.label + '</div>' +
            '</div></div>'
        );
        $('#itemOther-' + index).data('item', item);
        $('#itemOther-' + index).data('inventory', "second");
    });
}

// ── Droppables slots rapides ──
function makeDraggables() {
    for (var s = 1; s <= 5; s++) {
        (function(slot) {
            $('#itemFast-' + slot).droppable({
                drop: function(event, ui) {
                    var itemData = ui.draggable.data("item");
                    var itemInventory = ui.draggable.data("inventory");
                    if (type === "normal" && (itemInventory === "main" || itemInventory === "fast")) {
                        disableInventory(500);
                        $.post("http://lslegacy/PutIntoFast", JSON.stringify({ item: itemData, slot: slot }));
                    }
                }
            });
        })(s);
    }
}

// ── Menu contextuel rapide (clic droit sur un item de l'inventaire) ──
var contextMenuItem = null;

function openItemContextMenu(x, y, itemData) {
    contextMenuItem = itemData;
    var isWeapon = itemData.name.indexOf('weapon_') === 0;
    $('#contextMenuUnload').toggle(isWeapon);

    var $menu = $('#itemContextMenu');
    $menu.css({ display: 'block', left: x, top: y });

    // Empêche le menu de sortir de l'écran
    var menuWidth = $menu.outerWidth();
    var menuHeight = $menu.outerHeight();
    var maxLeft = $(window).width() - menuWidth - 4;
    var maxTop = $(window).height() - menuHeight - 4;
    $menu.css({
        left: Math.max(4, Math.min(x, maxLeft)),
        top: Math.max(4, Math.min(y, maxTop))
    });
}

function closeItemContextMenu() {
    $('#itemContextMenu').hide();
    contextMenuItem = null;
}

$(document).on('contextmenu', '#playerInventory .item', function(event) {
    event.preventDefault();
    if (disabled) return;
    var itemData = $(this).data('item');
    if (itemData === undefined || itemData.name === undefined) return;
    openItemContextMenu(event.pageX, event.pageY, itemData);
});

$(document).on('click', '.context-menu-option', function(event) {
    event.stopPropagation();
    var action = $(this).data('action');
    var itemData = contextMenuItem;
    closeItemContextMenu();
    if (!itemData) return;

    var count = parseInt($('#count').val());
    if (!count || count < 1) count = 1;

    if (action === 'rename') {
        $.post('http://lslegacy/RenameItem', JSON.stringify({ item: itemData, number: count }));
    } else if (action === 'give') {
        $.post('http://lslegacy/GetNearPlayers', JSON.stringify({ item: itemData, number: count }));
    } else if (action === 'drop') {
        $.post('http://lslegacy/DropItem', JSON.stringify({ item: itemData, number: count }));
    } else if (action === 'unload') {
        if (itemData.name.indexOf('weapon_') === 0) {
            $.post('http://lslegacy/UnloadWeapon', JSON.stringify({ item: itemData }));
        }
    }
});

// Ferme le menu contextuel au clic ailleurs, à l'échap, ou si l'inventaire se ferme/rafraîchit
$(document).on('click contextmenu', function(event) {
    if ($(event.target).closest('#itemContextMenu').length) return;
    // Le clic droit sur un item déclenche son propre handler (ouverture) juste au-dessus
    if (event.type === 'contextmenu' && $(event.target).closest('#playerInventory .item').length) return;
    closeItemContextMenu();
});
$(document).on('scroll', '#playerInventory', function() { closeItemContextMenu(); });

// ── Clic gauche : utiliser item (désactivé pour tous les vêtements) ──
$(document).on('click', function(event) {
    var $t = $(event.target);

    // Bloquer si c'est un item dans un slot vêtement équipé
    var $clothItem = $t.hasClass('cloth-slot-item') ? $t : $t.closest('.cloth-slot-item');
    if ($clothItem.length) return;

    var itemData = $t.data("item");
    if (itemData == undefined || itemData.usable == undefined) return;

    // Bloquer si le nom de l'item correspond à un type de slot vêtement
    if ($('[data-slot-type="' + itemData.name + '"]').length > 0) return;

    if (itemData.usable) {
        $t.fadeIn(50);
        setTimeout(function() {
            $.post("https://lslegacy/UseItem", JSON.stringify({
                item: itemData
            }));
        }, 100);
        $t.fadeOut(50);
    }
});

// ── ESC : fermer l'inventaire ──
$(document).keydown(function(event) {
    if (event.key === 'Escape') {
        if (contextMenuItem !== null) {
            closeItemContextMenu();
            return;
        }
        if ($(".ui").hasClass("ui-visible")) {
            $.post("http://lslegacy/escape", "{}");
        }
    }
});


// ── Helpers ──
function disableInventory(ms) {
    disabled = true;
    setInterval(function() { disabled = false; }, ms);
}

function setCount(item) {
    var count = item.count;
    if (item.name.startsWith("weapon_")) {
        count = (count == 0) ? "" : '<img src="img/bullet.png" class="ammoIcon"> ' + item.ammo;
    }
    if (item.type === "item_dirty" || item.type === "item_cash") {
        count = formatMoney(item.count);
    }
    return count;
}

function formatMoney(n, c, d, t) {
    var c = isNaN(c = Math.abs(c)) ? 2 : c,
        d = d == undefined ? "." : d,
        t = t == undefined ? "," : t,
        s = n < 0 ? "-" : "",
        i = String(parseInt(n = Math.abs(Number(n) || 0).toFixed(c))),
        j = (j = i.length) > 3 ? j % 3 : 0;
    return s + (j ? i.substr(0, j) + t : "") + i.substr(j).replace(/(\d{3})(?=\d)/g, "$1" + t);
}

// ── Document ready : droppables + events ──
$(document).ready(function() {
    $("#count").focus(function() { $(this).val(""); }).blur(function() { if ($(this).val() == "") $(this).val("1"); });
    $("#count").on("keypress keyup blur", function(event) {
        $(this).val($(this).val().replace(/[^\d].+/, ""));
        if (event.which < 48 || event.which > 57) event.preventDefault();
    });

    // Boutons catégorie (sidebar)
    $(".cat-btn").on("click", function() {
        $(".cat-btn").removeClass("active");
        $(this).addClass("active");
        activeSortBy = null;
        $(".sort-btn").removeClass("active");
        $.post("https://lslegacy/OngletInventory", JSON.stringify({ type: $(this).data("cat") }));
    });

    // Boutons tri
    $(".sort-btn").on("click", function() {
        applySortAndRender($(this).data("sort"));
    });

    // Cadenas de la tenue : toggle mode édition
    $(document).on('click', '#outfitLockBadge', function() {
        if (outfitEditMode) {
            exitOutfitEditMode(true);
        } else {
            enterOutfitEditMode();
        }
    });

    // Outfit slot (droppable — accepts only 'outfit' items)
    $("#outfitSlot").droppable({
        tolerance: "pointer",
        accept: function(draggable) {
            var itemData = draggable.data("item");
            return itemData !== undefined && itemData.name === 'outfit';
        },
        hoverClass: "outfit-slot-hover",
        drop: function(event, ui) {
            var itemData = ui.draggable.data("item");
            var itemInventory = ui.draggable.data("inventory");
            if (itemInventory === 'outfitSlot') return; // already equipped
            applyEquippedOutfit(itemData);
            $.post('http://lslegacy/EquipOutfit', JSON.stringify({ outfit: itemData }));
            renderInventoryGrid(getFilteredItems());
            initMainDraggables();
        }
    });

    // Slots vêtements (droppable avec validation de type)
    $(".cloth-slot").droppable({
        tolerance: "pointer",
        accept: function(draggable) {
            if (equippedOutfit && !outfitEditMode) return false; // tenue équipée et pas en mode édition → lock
            var itemData = draggable.data("item");
            var slotType = $(this).data("slotType");
            if (!itemData || itemData.name !== slotType) return false;
            if (outfitEditMode) return draggable.data("inventory") === "main";
            return true;
        },
        hoverClass: "cloth-slot-hover",
        drop: function(event, ui) {
            var itemData     = ui.draggable.data("item");
            var itemInventory = ui.draggable.data("inventory");
            var slotType     = $(this).data("slotType");

            if (outfitEditMode) {
                // En mode édition : ajouter un vêtement depuis l'inventaire à la tenue
                if (itemInventory !== "main") return;
                var raw      = itemData.data;
                var drawable = Array.isArray(raw) ? (raw[0] || 0) : (raw && raw.drawable || 0);
                var texture  = Array.isArray(raw) ? (raw[1] || 0) : (raw && raw.texture  || 0);
                outfitEditSlots[slotType] = { data: [drawable, texture], fromInventory: true, item: itemData };
                var $itemEl = $(this).find('.cloth-slot-item');
                $itemEl.css('background-image', "url('img/items/" + slotType + ".png')");
                $itemEl.data('item', { name: slotType, data: [drawable, texture] });
                $itemEl.data('inventory', 'outfitEditSlot');
                $(this).addClass('filled');
                if ($itemEl.hasClass('ui-draggable')) $itemEl.draggable('destroy');
                $itemEl.draggable({ helper: function() { return createDragHelper($(this)); }, appendTo: 'body', zIndex: 99999, revert: 'invalid' });
                // Appliquer le vêtement sur le perso en temps réel
                $.post('http://lslegacy/OutfitEditApplySlot', JSON.stringify({ slotType: slotType, drawable: drawable, texture: texture }));
                renderInventoryGrid(getFilteredItems());
                initMainDraggables();
                return;
            }

            if (equippedOutfit) return; // safety guard hors mode édition
            if (itemInventory === "clothSlot") return;
            equippedClothes[slotType] = itemData;
            var itemEl = $(this).find(".cloth-slot-item");
            itemEl.css("background-image", "url('img/items/" + itemData.name + ".png')");
            itemEl.data("item", itemData).data("inventory", "clothSlot");
            $(this).addClass("filled");
            if (itemEl.hasClass("ui-draggable")) itemEl.draggable("destroy");
            itemEl.draggable({
                helper: function() { return createDragHelper($(this)); },
                appendTo: "body",
                zIndex: 99999,
                revert: "invalid"
            });
            $.post("http://lslegacy/EquipClothing", JSON.stringify({ item: itemData }));
            renderInventoryGrid(getFilteredItems());
            initMainDraggables();
        }
    });

    // Droppable bouton décharger
    $("#unload").html(invLocale.unloadItem);
    $('#unload').droppable({
        hoverClass: 'hoverControl',
        drop: function(event, ui) {
            var itemData = ui.draggable.data("item");
            var inventoryType = ui.draggable.data("inventory");
            if (inventoryType === "main" && itemData.name.startsWith("weapon_")) {
                $.post("http://lslegacy/UnloadWeapon", JSON.stringify({ item: itemData }));
            }
        }
    });

    $('#use').droppable({
        hoverClass: 'hoverControl',
        drop: function(event, ui) {
            var itemData = ui.draggable.data("item");
            var inventoryType = ui.draggable.data("inventory");
            if (itemData.usable && inventoryType === "main") {
                $.post("http://lslegacy/UseItem", JSON.stringify({ item: itemData }));
            }
        }
    });

    $('#give').droppable({
        hoverClass: 'hoverControl',
        drop: function(event, ui) {
            var itemData = ui.draggable.data("item");
            var inventoryType = ui.draggable.data("inventory");
            if (inventoryType === "main") {
                $.post("http://lslegacy/GetNearPlayers", JSON.stringify({
                    player: $(this).data("player"),
                    item: itemData,
                    number: parseInt($("#count").val())
                }));
            }
        }
    });

    $('#drop').droppable({
        hoverClass: 'hoverControl',
        drop: function(event, ui) {
            var itemData = ui.draggable.data("item");
            var inventoryType = ui.draggable.data("inventory");
            if (inventoryType === "main") {
                $.post("http://lslegacy/DropItem", JSON.stringify({ item: itemData, number: parseInt($("#count").val()) }));
            }
        }
    });

    $('#rename').droppable({
        hoverClass: 'hoverControl',
        drop: function(event, ui) {
            var itemData = ui.draggable.data("item");
            var inventoryType = ui.draggable.data("inventory");
            if (inventoryType === "main") {
                $.post("http://lslegacy/RenameItem", JSON.stringify({ item: itemData, number: parseInt($("#count").val()) }));
            }
        }
    });

    $('#playerInventory').droppable({
        drop: function(event, ui) {
            var itemData = ui.draggable.data("item");
            var itemInventory = ui.draggable.data("inventory");
            if (itemInventory === "outfitEditSlot") {
                // Retirer ce slot de la tenue en mode édition
                var slotType = itemData.name;
                delete outfitEditSlots[slotType];
                clearClothSlot($('.cloth-slot[data-slot-type="' + slotType + '"]'));
                // Remettre le vêtement par défaut sur le perso en temps réel
                $.post('http://lslegacy/OutfitEditApplyDefault', JSON.stringify({ slotType: slotType }));
                renderInventoryGrid(getFilteredItems());
                initMainDraggables();
                return;
            }
            if (itemInventory === "outfitSlot") {
                // Unequip outfit → strip character
                equippedOutfit = null;
                applyEquippedOutfit(null);
                $.post("http://lslegacy/UnequipOutfit", JSON.stringify({ outfit: itemData }));
                renderInventoryGrid(getFilteredItems());
                initMainDraggables();
                return;
            }
            if (itemInventory === "clothSlot") {
                var slotType = itemData.name;
                delete equippedClothes[slotType];
                clearClothSlot($('.cloth-slot[data-slot-type="' + slotType + '"]'));
                $.post("http://lslegacy/UnequipClothing", JSON.stringify({ item: itemData }));
                renderInventoryGrid(getFilteredItems());
                initMainDraggables();
                return;
            }
            if (type === "trunk" && itemInventory === "second") {
                disableInventory(500);
                $.post("http://lslegacy/TakeFromTrunk", JSON.stringify({ item: itemData, number: parseInt($("#count").val()) }));
            } else if (type === "property" && itemInventory === "second") {
                disableInventory(500);
                $.post("http://lslegacy/TakeFromProperty", JSON.stringify({ item: itemData, number: parseInt($("#count").val()) }));
            } else if (type === "normal" && itemInventory === "fast") {
                disableInventory(500);
                $.post("http://lslegacy/TakeFromFast", JSON.stringify({ item: itemData }));
            } else if (type === "vault" && itemInventory === "second") {
                disableInventory(500);
                $.post("http://lslegacy/TakeFromVault", JSON.stringify({ item: itemData, number: parseInt($("#count").val()) }));
            } else if (type === "player" && itemInventory === "second") {
                disableInventory(500);
                $.post("http://lslegacy/TakeFromPlayer", JSON.stringify({ item: itemData, number: parseInt($("#count").val()) }));
            }
        }
    });

    $('#otherInventory').droppable({
        drop: function(event, ui) {
            var itemData = ui.draggable.data("item");
            var itemInventory = ui.draggable.data("inventory");
            if (type === "trunk" && itemInventory === "main") {
                disableInventory(500);
                $.post("http://lslegacy/PutIntoTrunk", JSON.stringify({ item: itemData, number: parseInt($("#count").val()) }));
            } else if (type === "property" && itemInventory === "main") {
                disableInventory(500);
                $.post("http://lslegacy/PutIntoProperty", JSON.stringify({ item: itemData, number: parseInt($("#count").val()) }));
            } else if (type === "vault" && itemInventory === "main") {
                disableInventory(500);
                $.post("http://lslegacy/PutIntoVault", JSON.stringify({ item: itemData, number: parseInt($("#count").val()) }));
            } else if (type === "player" && itemInventory === "main") {
                disableInventory(500);
                $.post("http://lslegacy/PutIntoPlayer", JSON.stringify({ item: itemData, number: parseInt($("#count").val()) }));
            }
        }
    });
});

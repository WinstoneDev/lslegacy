// ════════════════════════════════════════════════
//  LSLegacy – ClothShop NUI
// ════════════════════════════════════════════════

var shopData = {
    shopName: '',
    shopType: '',
    maxVals: {},
    playerInventory: [],
    outfitItems: []
};

var cart = [];
var ITEM_PRICE = 30;

var CATEGORIES = {
    tshirt:   { label: 'T-Shirts',       color: '#818cf8', max: 'tshirt_1' },
    torso:    { label: 'Torses / Vestes', card: 'Torse', color: '#a78bfa', max: 'torso_1' },
    bproof:   { label: 'Gilets pare-balles', card: 'Gilet', color: '#4ade80', max: 'bproof_1' },
    arms:     { label: 'Bras / Gants',   card: 'Bras',  color: '#c4b5fd', max: 'arms_1' },
    pants:    { label: 'Pantalons',       color: '#ec4899', max: 'pants_1' },
    shoes:    { label: 'Chaussures',      color: '#f97316', max: 'shoes_1' },
    helmet:   { label: 'Chapeaux',        color: '#22d3ee', max: 'helmet_1' },
    glasses:  { label: 'Lunettes',        color: '#34d399', max: 'glasses_1' },
    ears:     { label: 'Oreillettes',     color: '#f59e0b', max: 'ears_1' },
    watches:  { label: 'Montres',         color: '#94a3b8', max: 'watches_1' },
    bracelet: { label: 'Bracelets',       color: '#e879f9', max: 'bracelets_1' },
    chain:    { label: 'Chaînes',         color: '#64748b', max: 'chain_1' },
    bags:     { label: 'Sacs',            color: '#facc15', max: 'bags_1' },
    decals:   { label: 'Badges',          color: '#3b82f6', max: 'decals_1' },
    mask:     { label: 'Masques',         color: '#ef4444', max: 'mask_1' }
};

var currentCat = 'tshirt';
var currentTextures = {};


var PROP_CATEGORIES = { helmet: 0, glasses: 1, ears: 2, watches: 6 };

var builderMode = 'new';
var builderSlots = {};
var editingOutfitId = null;
var originalOutfitData = null;

// ── NUI Messages ──────────────────────────────────
window.addEventListener('message', function(event) {
    var data = event.data;
    if (!data || !data.action) return;

    if (data.action === 'clothshop:open') {
        openShop(data);
    } else if (data.action === 'clothshop:hide') {
        hideShop();
    } else if (data.action === 'clothshop:cartSuccess') {
        onCartSuccess();
    } else if (data.action === 'clothshop:cartFailed') {
        $('#shop').addClass('shop-visible');
        showToast('Paiement refusé ou insuffisant.', 'error');
    } else if (data.action === 'clothshop:tempHide') {
        $('#shop').removeClass('shop-visible');
    } else if (data.action === 'clothshop:refreshInventory') {
        shopData.playerInventory = data.playerInventory || [];
        shopData.outfitItems     = data.outfitItems    || [];
        refreshOutfitTab();
    } else if (data.action === 'clothshop:outfitCreated') {
        shopData.playerInventory = data.playerInventory || [];
        shopData.outfitItems     = data.outfitItems    || [];
        // shop déjà fermé côté Lua, on met juste les données à jour
    } else if (data.action === 'clothshop:outfitSplit') {
        shopData.playerInventory = data.playerInventory || [];
        shopData.outfitItems     = data.outfitItems    || [];
        if ($('#shop').hasClass('shop-visible')) {
            showToast('Tenue décomposée.', 'info');
            resetBuilder();
            refreshOutfitTab();
        }
    }
});

// ── Open / Close ──────────────────────────────────
function openShop(data) {
    shopData.shopName        = data.shopName  || 'Boutique';
    shopData.shopType        = data.shopType  || 'Cloth';
    shopData.maxVals         = data.maxVals   || {};
    shopData.playerInventory = data.playerInventory || [];
    shopData.outfitItems     = data.outfitItems    || [];

    $('#shopName').text(shopData.shopName);

    cart = [];
    currentTextures = {};
    builderSlots = {};
    builderMode = 'new';
    editingOutfitId = null;

    if (shopData.shopType === 'Mask') {
        showOnlyMaskCategory();
    } else {
        showAllCategories();
    }

    renderCart();
    switchTab('browse');
    selectCategory(currentCat);

    $('#shop').addClass('shop-visible');
}

function hideShop() {
    $('#shop').removeClass('shop-visible');
}

function showOnlyMaskCategory() {
    currentCat = 'mask';
    $('.cat-item').hide();
    $('.cat-item[data-cat="mask"]').show();
    $('#tabOutfit').hide();
}

function showAllCategories() {
    $('.cat-item').show();
    $('#tabOutfit').show();
    if (shopData.shopType !== 'Mask') {
        $('.cat-item[data-cat="mask"]').hide();
    }
}

// ── Tab Switching ─────────────────────────────────
function switchTab(tab) {
    $('.shop-tab').removeClass('active');
    $('.shop-tab[data-tab="' + tab + '"]').addClass('active');

    if (tab === 'browse') {
        $('#bodyBrowse').removeClass('hidden');
        $('#bodyOutfit').addClass('hidden');
    } else {
        $('#bodyBrowse').addClass('hidden');
        $('#bodyOutfit').removeClass('hidden');
        refreshOutfitTab();
    }
}

// ── Category Selection ────────────────────────────
function selectCategory(cat) {
    // Revert previewed item if it's not in the cart before leaving/reselecting category
    var $previewing = $('.product-card.previewing');
    if ($previewing.length) {
        var prevSlot = $previewing.data('cat');
        if (prevSlot) {
            var inCart = cart.some(function(ci) { return ci.name === prevSlot; });
            if (!inCart) {
                $.post('http://lslegacy/clothshop:revertSlot', JSON.stringify({ slot: prevSlot }));
            }
        }
    }

    currentCat = cat;
    var meta = CATEGORIES[cat] || { label: cat, color: '#6c47ff' };

    $('.cat-item').removeClass('active');
    $('.cat-item[data-cat="' + cat + '"]').addClass('active');
    $('#catTitle').text(meta.label);

    renderProductGrid(cat);
}

// ── Product Grid ──────────────────────────────────
function renderProductGrid(cat) {
    var $grid = $('#productGrid');
    $grid.html('');

    var maxKey = CATEGORIES[cat] ? CATEGORIES[cat].max : null;
    var max    = maxKey ? (shopData.maxVals[maxKey] || 0) : 30;
    var color  = CATEGORIES[cat] ? CATEGORIES[cat].color : '#6c47ff';
    var label  = CATEGORIES[cat] ? (CATEGORIES[cat].card || CATEGORIES[cat].label.replace(/s$/, '')) : cat;
    var isProp = PROP_CATEGORIES.hasOwnProperty(cat);

    $('#catCount').text(max + ' articles');
    document.documentElement.style.setProperty('--active-cat-color', color);

    var startIdx = isProp ? -1 : 0;

    for (var i = startIdx; i <= max; i++) {
        (function(index) {

            // Carte spéciale "Retirer" pour les props (drawable -1)
            if (index === -1) {
                var $card = $('<div class="product-card" data-cat="' + cat + '" data-index="-1">')
                    .css({ '--card-color': '#6b7280' });

                var $img = $('<div class="product-card-img">').css({
                    'display': 'flex', 'align-items': 'center', 'justify-content': 'center',
                    'font-size': '30px', 'color': 'rgba(255,255,255,0.22)',
                    'background': 'rgba(255,255,255,0.03)'
                }).text('✕');
                $card.append($img);

                var $body = $('<div class="product-card-body">');
                $body.append($('<div class="product-card-name">').text('Retirer'));
                $body.append($('<div class="product-card-price">').css('color', 'rgba(255,255,255,0.32)').text('Sans accessoire'));
                $card.append($body);

                $card.on('click', function() {
                    $('.product-card').removeClass('previewing');
                    $card.addClass('previewing');
                    $.post('http://lslegacy/clothshop:preview',
                        JSON.stringify({ name: cat, drawable: -1, texture: 0 }));
                });

                $grid.append($card);
                return;
            }

            var texKey     = cat + '_' + index;
            var currentTex = currentTextures[texKey] || 0;

            var $card = $('<div class="product-card" data-cat="' + cat + '" data-index="' + index + '">')
                .css({ '--card-color': color });

            var $img = $('<div class="product-card-img">').css('background-image',
                "url('../../../inventory/html/img/items/" + cat + ".png')");
            $card.append($img);

            var $body = $('<div class="product-card-body">');
            $body.append($('<div class="product-card-name">').text(label + ' #' + index));
            $body.append($('<div class="product-card-price">').text(ITEM_PRICE + '$'));

            var $texRow = $('<div class="product-card-tex">');
            var $texLabel = $('<span class="tex-val">').text('Texture : ' + currentTex + '/—');
            $texRow.append($texLabel);
            $body.append($texRow);
            $card.data('texMax', 0);

            var $addBtn = $('<button class="product-card-add">').html(
                '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-2 10h-4v4h-2v-4H7v-2h4V7h2v4h4v2z"/></svg> Ajouter');
            $addBtn.on('click', function(e) {
                e.stopPropagation();
                var tex = currentTextures[texKey] || 0;
                addToCart(cat, index, tex, label + ' #' + index);
                $addBtn.html('<svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z"/></svg> Ajouté !');
                setTimeout(function() {
                    $addBtn.html('<svg viewBox="0 0 24 24" fill="currentColor"><path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-2 10h-4v4h-2v-4H7v-2h4V7h2v4h4v2z"/></svg> Ajouter');
                }, 1200);
            });
            $body.append($addBtn);
            $card.append($body);

            $card.on('click', function() {
                var tex = currentTextures[texKey] || 0;
                $('.product-card').removeClass('previewing');
                $card.addClass('previewing');
                $.post('http://lslegacy/clothshop:preview',
                    JSON.stringify({ name: cat, drawable: index, texture: tex }),
                    function(resp) {
                        if (!resp || resp.maxTex === undefined) return;
                        var maxTex = Math.max(0, parseInt(resp.maxTex));
                        $card.data('texMax', maxTex);
                        var clamped = Math.min(currentTextures[texKey] || 0, maxTex);
                        if (clamped !== (currentTextures[texKey] || 0)) {
                            currentTextures[texKey] = clamped;
                            $.post('http://lslegacy/clothshop:preview',
                                JSON.stringify({ name: cat, drawable: index, texture: clamped }));
                        }
                        $texLabel.text('Texture : ' + (currentTextures[texKey] || 0) + '/' + maxTex);
                    }, 'json');
            });

            $grid.append($card);
        })(i);
    }
}

// ── Cart Logic ────────────────────────────────────
function addToCart(name, drawable, texture, label) {
    cart.push({ name: name, drawable: drawable, texture: texture, label: label, price: ITEM_PRICE });
    renderCart();
    showToast(label + ' ajouté au panier', 'info');
}

function removeFromCart(index) {
    var removed = cart[index];
    cart.splice(index, 1);
    renderCart();
    if (removed) {
        var stillInCart = cart.some(function(ci) { return ci.name === removed.name; });
        if (!stillInCart) {
            $('.product-card[data-cat="' + removed.name + '"]').removeClass('previewing');
            $.post('http://lslegacy/clothshop:revertSlot', JSON.stringify({ slot: removed.name }));
        }
    }
}

function renderCart() {
    var $items = $('#cartItems');
    var $empty = $('#cartEmpty');
    $items.find('.cart-item').remove();

    var total = 0;
    cart.forEach(function(item, i) {
        total += item.price;
        var $row = $('<div class="cart-item">');
        $row.append($('<div class="cart-item-icon">').css('background-image',
            "url('../../../inventory/html/img/items/" + item.name + ".png')"));
        var $info = $('<div class="cart-item-info">');
        $info.append($('<div class="cart-item-name">').text(item.label));
        $info.append($('<div class="cart-item-price">').text(item.price + '$'));
        $row.append($info);
        var $rm = $('<button class="cart-item-remove">').text('×');
        (function(idx) { $rm.on('click', function() { removeFromCart(idx); }); })(i);
        $row.append($rm);
        $items.append($row);
    });

    if (cart.length === 0) { $empty.show(); } else { $empty.hide(); }

    $('#cartBadge').text(cart.length);
    $('#cartTotal').text(total + '$');
    $('#checkoutBtn').prop('disabled', cart.length === 0);
}

function onCartSuccess() {
    cart = [];
    renderCart();
}

// ── Outfit Tab ────────────────────────────────────
function refreshOutfitTab() {
    renderOutfitList();
    renderOutfitInvGrid();
}

function renderOutfitList() {
    var $list = $('#outfitList');
    $list.find('.outfit-card').remove();
    var outfits = shopData.outfitItems || [];

    if (outfits.length === 0) {
        $('#outfitListEmpty').show();
    } else {
        $('#outfitListEmpty').hide();
        outfits.forEach(function(outfit) {
            var $card = $('<div class="outfit-card" data-uid="' + outfit.uniqueId + '">');
            $card.append($('<div class="outfit-card-name">').text(outfit.label || 'Tenue sans nom'));

            var $dots = $('<div class="outfit-slots-dots">');
            if (outfit.data) {
                Object.keys(outfit.data).forEach(function() {
                    $dots.append($('<span class="outfit-slot-dot">'));
                });
            }
            $card.append($dots);

            $card.on('click', function() {
                $('.outfit-card').removeClass('selected');
                $card.addClass('selected');
                loadOutfitForEditing(outfit);
            });

            $list.append($card);
        });
    }
}

function renderOutfitInvGrid() {
    var $grid = $('#outfitInvGrid');
    $grid.html('');

    var clothing = (shopData.playerInventory || []).filter(function(item) {
        return CATEGORIES[item.name] !== undefined;
    });

    clothing.forEach(function(item) {
        var inBuilder = builderSlots[item.name] && builderSlots[item.name].uniqueId === item.uniqueId;
        var $el = $('<div class="outfit-inv-item" data-name="' + item.name + '" data-uid="' + item.uniqueId + '">')
            .css('background-image', "url('../../../inventory/html/img/items/" + item.name + ".png')")
            .addClass(inBuilder ? 'used' : '');
        $('<div class="outfit-inv-item-name">').text(item.label).appendTo($el);
        $el.data('item', item);
        $grid.append($el);
    });

    initOutfitDraggables();
}

// ── Builder Drag & Drop ───────────────────────────
var dragItem = null;
var $dragGhost = null;

function initOutfitDraggables() {
    $('.outfit-inv-item').off('mousedown').on('mousedown', function(e) {
        if (e.which !== 1) return;
        var item = $(this).data('item');
        if (!item) return;
        dragItem = item;

        $dragGhost = $('<div class="clothshop-drag-ghost">')
            .css('background-image', "url('../../../inventory/html/img/items/" + item.name + ".png')");
        $('body').append($dragGhost);
        moveDragGhost(e.clientX, e.clientY);
        e.preventDefault();
    });
}

$(document).on('mousemove', function(e) {
    if ($dragGhost) moveDragGhost(e.clientX, e.clientY);
});

function moveDragGhost(x, y) {
    if ($dragGhost) $dragGhost.css({ left: (x - 26) + 'px', top: (y - 26) + 'px' });
}

$(document).on('mouseup', function(e) {
    if (!dragItem || !$dragGhost) return;

    var $ghost = $dragGhost;
    $dragGhost = null;

    var dropTarget = document.elementFromPoint(e.clientX, e.clientY);
    var $slot = $(dropTarget).closest('.builder-slot');

    if ($slot.length) {
        var slotType = $slot.data('slot');
        if (slotType === dragItem.name) {
            placeItemInBuilderSlot(slotType, dragItem);
        } else {
            var expected = CATEGORIES[dragItem.name] ? CATEGORIES[dragItem.name].label : dragItem.name;
            showToast('Ce vêtement va dans le slot ' + expected + '.', 'error');
        }
    }

    $ghost.remove();
    dragItem = null;
});

function placeItemInBuilderSlot(slot, item) {
    var d = item.data;
    // Lua {drawable, texture} → JSON [drawable, texture] → JS data[0]=drawable, data[1]=texture
    var drawable = d ? (Array.isArray(d) ? d[0] : (d.drawable !== undefined ? d.drawable : 0)) : 0;
    var texture  = d ? (Array.isArray(d) ? d[1] : (d.texture  !== undefined ? d.texture  : 0)) : 0;
    builderSlots[slot] = {
        name:     item.name,
        label:    item.label,
        drawable: drawable,
        texture:  texture,
        uniqueId: item.uniqueId
    };

    var $slot = $('.builder-slot[data-slot="' + slot + '"]');
    $slot.addClass('filled');
    $slot.find('.builder-slot-img')
        .css('background-image', "url('../../../inventory/html/img/items/" + item.name + ".png')")
        .show();
    $slot.find('.builder-slot-remove').show();

    // Pas de preview sur le ped lors du placement — uniquement à la création

    renderOutfitInvGrid();
}

function removeFromBuilderSlot(slot) {
    delete builderSlots[slot];

    var $slot = $('.builder-slot[data-slot="' + slot + '"]');
    $slot.removeClass('filled');
    $slot.find('.builder-slot-img').hide().css('background-image', '');
    $slot.find('.builder-slot-remove').hide();

    renderOutfitInvGrid();
}

// ── Load outfit for editing ───────────────────────
function loadOutfitForEditing(outfit) {
    builderMode = 'edit';
    editingOutfitId = outfit.uniqueId;
    $('#outfitNameInput').val(outfit.label || '');
    $('#builderMode').text('Modification');

    originalOutfitData = outfit.data || null;
    resetBuilderSlots();

    if (outfit.data) {
        Object.keys(outfit.data).forEach(function(slot) {
            var vals     = outfit.data[slot];
            var drawable = Array.isArray(vals) ? vals[0] : (vals.drawable || 0);
            var texture  = Array.isArray(vals) ? vals[1] : (vals.texture  || 0);

            var label = CATEGORIES[slot] ? CATEGORIES[slot].label : slot;
            builderSlots[slot] = {
                name: slot, label: label,
                drawable: drawable, texture: texture,
                uniqueId: null  // Seulement défini si l'utilisateur drag un item depuis l'inventaire
            };

            var $s = $('.builder-slot[data-slot="' + slot + '"]');
            $s.addClass('filled');
            $s.find('.builder-slot-img')
                .css('background-image', "url('../../../inventory/html/img/items/" + slot + ".png')")
                .show();
            $s.find('.builder-slot-remove').show();
        });
    }

    $('#createOutfitBtn').addClass('hidden');
    $('#saveOutfitBtn').removeClass('hidden');
    $('#splitOutfitBtn').removeClass('hidden');
    $('#cancelEditBtn').removeClass('hidden');

    renderOutfitInvGrid();
}

function resetBuilderSlots() {
    builderSlots = {};
    $('.builder-slot').removeClass('filled');
    $('.builder-slot-img').hide().css('background-image', '');
    $('.builder-slot-remove').hide();
}

function resetBuilder() {
    resetBuilderSlots();
    builderMode = 'new';
    editingOutfitId = null;
    originalOutfitData = null;
    $('#outfitNameInput').val('');
    $('#builderMode').text('Nouvelle tenue');
    $('#createOutfitBtn').removeClass('hidden');
    $('#saveOutfitBtn').addClass('hidden');
    $('#splitOutfitBtn').addClass('hidden');
    $('#cancelEditBtn').addClass('hidden');
    $('.outfit-card').removeClass('selected');
}

// ── Builder Slot Hover ────────────────────────────
$(document).on('mouseenter', '.builder-slot', function() {
    if (dragItem) $(this).addClass('drop-hover');
}).on('mouseleave', '.builder-slot', function() {
    $(this).removeClass('drop-hover');
});

// ── Keyboard (Tab bloqué, Échap ferme, flèches navigation) ───
$(document).on('keydown', function(e) {
    if (!$('#shop').hasClass('shop-visible')) return;

    if (e.key === 'Tab') {
        e.preventDefault();
        e.stopImmediatePropagation();
        return false;
    }
    if (e.key === 'Escape') {
        $.post('http://lslegacy/clothshop:close', '{}');
        return;
    }

    // Flèches uniquement sur l'onglet boutique
    if ($('#bodyBrowse').hasClass('hidden')) return;

    var isArrow = e.key === 'ArrowLeft' || e.key === 'ArrowRight' || e.key === 'ArrowUp' || e.key === 'ArrowDown';
    if (!isArrow) return;
    e.preventDefault();

    if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
        var $focused = $('.product-card.previewing').filter(function() {
            return $(this).data('index') !== -1;
        });
        if (!$focused.length) {
            // Aucun article sélectionné → rotation du personnage
            var dir = e.key === 'ArrowLeft' ? -1 : 1;
            $.post('http://lslegacy/clothshop:camera', JSON.stringify({ action: 'rotate', dir: dir }));
            return;
        }
        var fCat = $focused.data('cat');
        var fIdx = $focused.data('index');
        var fKey = fCat + '_' + fIdx;
        var v = currentTextures[fKey] || 0;
        var m = $focused.data('texMax') || 0;
        var nv = e.key === 'ArrowRight' ? Math.min(v + 1, m) : Math.max(v - 1, 0);
        if (nv !== v) {
            currentTextures[fKey] = nv;
            $focused.find('.tex-val').text('Texture : ' + nv + '/' + m);
            $.post('http://lslegacy/clothshop:preview',
                JSON.stringify({ name: fCat, drawable: parseInt(fIdx), texture: nv }));
        }
        return;
    }

    if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
        // Navigation entre cartes
        var $cards  = $('.product-card');
        if (!$cards.length) return;
        var $cur    = $('.product-card.previewing');
        var curIdx  = $cards.index($cur);
        var newIdx;
        if (curIdx === -1) {
            newIdx = e.key === 'ArrowDown' ? 0 : $cards.length - 1;
        } else {
            newIdx = e.key === 'ArrowDown' ? curIdx + 1 : curIdx - 1;
            newIdx = Math.max(0, Math.min(newIdx, $cards.length - 1));
        }
        if (newIdx !== curIdx) {
            var $target = $($cards[newIdx]);
            $target.trigger('click');
            $target[0].scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        }
    }
});

// ── Event Listeners ───────────────────────────────
$(document).ready(function() {
    $('.shop-tab').on('click', function() {
        switchTab($(this).data('tab'));
    });

    $('#closeBtn').on('click', function() {
        $.post('http://lslegacy/clothshop:close', '{}');
    });

    $('.cat-item').on('click', function() {
        selectCategory($(this).data('cat'));
    });

    $('#checkoutBtn').on('click', function() {
        if (cart.length === 0) return;
        var total = cart.reduce(function(sum, item) { return sum + item.price; }, 0);
        $('#shop').removeClass('shop-visible');
        $.post('http://lslegacy/clothshop:checkout', JSON.stringify({ items: cart, total: total }));
    });

    $('#newOutfitBtn').on('click', function() {
        resetBuilder();
    });

    $(document).on('click', '.builder-slot-remove', function() {
        var slot = $(this).closest('.builder-slot').data('slot');
        removeFromBuilderSlot(slot);
    });

    $('#createOutfitBtn').on('click', function() {
        var name = $('#outfitNameInput').val().trim();
        if (!name) { showToast('Donnez un nom à votre tenue.', 'error'); return; }
        if (Object.keys(builderSlots).length === 0) { showToast('Ajoutez au moins un vêtement.', 'error'); return; }

        var itemsData   = {};
        var consumedIds = [];
        Object.keys(builderSlots).forEach(function(slot) {
            var s = builderSlots[slot];
            itemsData[slot] = { drawable: s.drawable, texture: s.texture };
            if (s.uniqueId) consumedIds.push({ name: slot, uniqueId: s.uniqueId });
        });

        // Le Lua callback ferme le shop + met à poil + envoie au serveur
        $.post('http://lslegacy/clothshop:createOutfit', JSON.stringify({
            name:    name,
            items:   itemsData,
            itemIds: consumedIds
        }));
    });

    $('#saveOutfitBtn').on('click', function() {
        if (editingOutfitId == null) return;
        var name = $('#outfitNameInput').val().trim();
        if (!name) { showToast('Donnez un nom à votre tenue.', 'error'); return; }
        if (Object.keys(builderSlots).length === 0) { showToast('La tenue est vide.', 'error'); return; }

        var itemsData    = {};
        var consumedIds  = [];
        var removedSlots = {};
        Object.keys(builderSlots).forEach(function(slot) {
            var s = builderSlots[slot];
            itemsData[slot] = { drawable: s.drawable, texture: s.texture };
            if (s.uniqueId) consumedIds.push({ name: slot, uniqueId: s.uniqueId });
        });
        if (originalOutfitData) {
            Object.keys(originalOutfitData).forEach(function(slot) {
                if (!builderSlots.hasOwnProperty(slot)) {
                    // Slot complètement retiré
                    removedSlots[slot] = originalOutfitData[slot];
                } else if (builderSlots[slot].uniqueId) {
                    // Slot remplacé par un item d'inventaire → rendre l'original
                    removedSlots[slot] = originalOutfitData[slot];
                }
            });
        }

        // Le Lua callback ferme le shop
        $.post('http://lslegacy/clothshop:modifyOutfit', JSON.stringify({
            uniqueId:     editingOutfitId,
            newName:      name,
            items:        itemsData,
            itemIds:      consumedIds,
            removedSlots: removedSlots
        }));
    });

    $('#splitOutfitBtn').on('click', function() {
        if (editingOutfitId == null) return;
        var outfit = (shopData.outfitItems || []).filter(function(o) {
            return o.uniqueId === editingOutfitId;
        })[0];
        if (!outfit) return;
        $.post('http://lslegacy/clothshop:splitOutfit', JSON.stringify({ outfit: outfit }));
    });

    $('#cancelEditBtn').on('click', function() {
        resetBuilder();
    });

    // ── Contrôles caméra ──────────────────────────
    $('#camRotateLeft').on('click', function() {
        $.post('http://lslegacy/clothshop:camera', JSON.stringify({ action: 'rotate', dir: -1 }));
    });
    $('#camRotateRight').on('click', function() {
        $.post('http://lslegacy/clothshop:camera', JSON.stringify({ action: 'rotate', dir: 1 }));
    });
    $(document).on('click', '.cam-preset', function() {
        var preset = $(this).data('preset');
        $('.cam-preset').removeClass('active');
        $(this).addClass('active');
        $.post('http://lslegacy/clothshop:camera', JSON.stringify({ action: 'preset', preset: preset }));
    });
    $('#camToggle').on('click', function() {
        $('#camControls').toggleClass('cam-hidden');
    });

    // Zoom à la molette sur la zone du personnage (hors panneaux/boutons).
    var CAM_INTERACT_BLOCKERS = 'button, input, .cat-item, .product-card, .cart-panel, .cat-sidebar, .outfit-list-panel, .outfit-inventory-panel, .builder-slot, .shop-tab, #camControls, .cam-preset';
    $('#shop').on('wheel', function(e) {
        if ($(e.target).closest(CAM_INTERACT_BLOCKERS).length) return;
        e.preventDefault();
        var delta = e.originalEvent.deltaY > 0 ? 0.2 : -0.2;
        $.post('http://lslegacy/clothshop:camera', JSON.stringify({ action: 'zoom', delta: delta }));
    });

    // Clic gauche maintenu + déplacement souris : la caméra ne se déplace
    // pas, seul son angle change (façon caméra de sécurité).
    var isDraggingLook = false;
    var lastDragX = 0;
    var lastDragY = 0;
    $('#shop').on('mousedown', function(e) {
        if (e.which !== 1 || $(e.target).closest(CAM_INTERACT_BLOCKERS).length) return;
        isDraggingLook = true;
        lastDragX = e.clientX;
        lastDragY = e.clientY;
        e.preventDefault();
    });
    $(document).on('mousemove', function(e) {
        if (!isDraggingLook) return;
        var dx = e.clientX - lastDragX;
        var dy = e.clientY - lastDragY;
        lastDragX = e.clientX;
        lastDragY = e.clientY;
        if (dx !== 0 || dy !== 0) {
            $.post('http://lslegacy/clothshop:camera', JSON.stringify({ action: 'look', dx: dx * 0.15, dy: dy * 0.08 }));
        }
    });
    $(document).on('mouseup', function(e) {
        if (e.which !== 1) return;
        isDraggingLook = false;
    });
});

// ── Toast ─────────────────────────────────────────
function showToast(msg, type) {
    type = type || 'info';
    var icons = {
        success: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z"/></svg>',
        error:   '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>',
        info:    '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/></svg>'
    };
    var $toast = $('<div class="toast toast-' + type + '">').html(icons[type] + ' ' + msg);
    $('#toastContainer').append($toast);
    setTimeout(function() { $toast.remove(); }, 3200);
}

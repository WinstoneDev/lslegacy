// Liste complète des 22 mères nommées du créateur de personnage GTA Online
// (21 génériques + Misty). https://gta.fandom.com/wiki/Mom
const MOTHERS = [
    'Hannah','Audrey','Jasmine','Giselle','Amelia','Isabella','Zoe','Ava',
    'Camila','Violet','Sophia','Evelyn','Nicole','Ashley','Grace','Brianna',
    'Natalie','Olivia','Elizabeth','Charlotte','Emma','Misty',
];

// Liste complète des 24 pères nommés du créateur de personnage GTA Online
// (21 génériques + Claude, Niko, John). https://gta.fandom.com/wiki/Dad
const FATHERS = [
    'Benjamin','Daniel','Joshua','Noah','Andrew','Juan','Alex','Isaac',
    'Evan','Ethan','Vincent','Angel','Diego','Adrian','Gabriel','Michael',
    'Santiago','Kevin','Louis','Samuel','Anthony','Claude','Niko','John',
];

const FIXED_RANGE_SLIDERS = new Set(['resemblance', 'skinTone']);

const MONTHS_FR = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

const TAB_LABELS = {
    appearance: 'Apparence',
    heritage:   'Héritage',
    visage:     'Visage',
    makeup:     'Maquillage',
    identity:   'Identité',
};

class CharacterCreator {
    constructor() {
        this.currentSex = 0;
        this.skinData = {};
        this.identityData = {};
        this.heritageData = { mother: 0, father: 0, resemblance: 5, skinTone: 5 };
        this.motherIndex = 0;
        this.fatherIndex = 0;
        this.init();
    }

    init() {
        this.bindElements();
        this.attachEventListeners();
        this.setupSliders();
        this.initDatePicker();
    }

    bindElements() {
        this.tabButtons  = document.querySelectorAll('.tab-btn');
        this.tabContents = document.querySelectorAll('.tab-content');
        this.sexButtons  = document.querySelectorAll('.sex-btn');
        this.sliders     = document.querySelectorAll('.slider');

        // Héritage
        this.motherPhoto = document.getElementById('motherPhoto');
        this.fatherPhoto = document.getElementById('fatherPhoto');
        this.motherName  = document.getElementById('motherName');
        this.fatherName  = document.getElementById('fatherName');

        // Identité
        this.firstNameInput  = document.getElementById('firstName');
        this.lastNameInput   = document.getElementById('lastName');
        this.heightInput     = document.getElementById('height');
        this.birthPlaceInput = document.getElementById('birthPlace');

        // Date de naissance (calendrier français custom)
        this.dob = null; // { day, month (1-12), year }
        this.dobToggleBtn   = document.getElementById('dateOfBirthInput');
        this.dobText        = document.getElementById('dateOfBirthText');
        this.dobPopup       = document.getElementById('dateOfBirthPopup');
        this.dobMonthSelect = document.getElementById('dobMonthSelect');
        this.dobYearSelect  = document.getElementById('dobYearSelect');
        this.dobDaysGrid    = document.getElementById('dobDaysGrid');

        // Boutons
        this.confirmBtn = document.getElementById('confirmBtn');
        this.resetBtn   = document.getElementById('resetBtn');
        this.rotateLeftBtn  = document.getElementById('rotateLeft');
        this.rotateRightBtn = document.getElementById('rotateRight');

        // Titre du panneau d'options
        this.optionsTitle = document.getElementById('optionsTitle');
    }

    attachEventListeners() {
        this.tabButtons.forEach(btn => {
            btn.addEventListener('click', () => this.switchTab(btn.dataset.tab));
        });

        this.sexButtons.forEach(btn => {
            btn.addEventListener('click', () => this.changeSex(btn.dataset.sex));
        });

        this.sliders.forEach(slider => {
            slider.addEventListener('input', (e) => this.onSliderChange(e));
        });

        document.getElementById('motherPrev')?.addEventListener('click', () => this.stepParent('mother', -1));
        document.getElementById('motherNext')?.addEventListener('click', () => this.stepParent('mother',  1));
        document.getElementById('fatherPrev')?.addEventListener('click', () => this.stepParent('father', -1));
        document.getElementById('fatherNext')?.addEventListener('click', () => this.stepParent('father',  1));

        this.firstNameInput?.addEventListener('input',  () => this.updateIdentity());
        this.lastNameInput?.addEventListener('input',   () => this.updateIdentity());
        this.heightInput?.addEventListener('input',    () => this.updateIdentity());
        this.birthPlaceInput?.addEventListener('input', () => this.updateIdentity());

        this.confirmBtn?.addEventListener('click', () => this.confirm());
        this.resetBtn?.addEventListener('click',   () => this.reset());
        this.rotateLeftBtn?.addEventListener('click',  () => this.sendToGame('rotateCharacter', -10));
        this.rotateRightBtn?.addEventListener('click', () => this.sendToGame('rotateCharacter', 10));

        window.addEventListener('keydown', (e) => this.handleKeydown(e));

        // Zoom molette sur le personnage, sauf au-dessus du panneau d'options
        // (où la molette doit défiler la liste des sliders normalement).
        document.getElementById('creatorContainer')?.addEventListener('wheel', (e) => {
            if (e.target.closest('.options-float')) return;
            e.preventDefault();
            this.sendToGame('wheelZoom', e.deltaY > 0 ? 2 : -2);
        }, { passive: false });

        // Clic gauche maintenu + déplacement de la souris : on ne déplace pas
        // la caméra, on change son angle (façon caméra de sécurité).
        const creatorContainer = document.getElementById('creatorContainer');
        let isDraggingLook = false;
        let lastDragX = 0;
        let lastDragY = 0;

        creatorContainer?.addEventListener('mousedown', (e) => {
            if (e.button !== 0 || e.target.closest('.options-float')) return;
            isDraggingLook = true;
            lastDragX = e.clientX;
            lastDragY = e.clientY;
            e.preventDefault();
        });

        window.addEventListener('mousemove', (e) => {
            if (!isDraggingLook) return;
            const dx = e.clientX - lastDragX;
            const dy = e.clientY - lastDragY;
            lastDragX = e.clientX;
            lastDragY = e.clientY;
            if (dx !== 0 || dy !== 0) {
                this.sendToGame('dragLook', { dx: dx * 0.15, dy: dy * 0.08 });
            }
        });

        window.addEventListener('mouseup', (e) => {
            if (e.button !== 0) return;
            isDraggingLook = false;
        });
    }

    setupSliders() {
        this.sliders.forEach(slider => {
            const display = slider.nextElementSibling;
            if (display?.classList.contains('slider-value')) {
                slider.addEventListener('input', () => {
                    const v = parseFloat(slider.value);
                    display.textContent = (slider.step && parseFloat(slider.step) < 1)
                        ? v.toFixed(1)
                        : Math.floor(v).toString();
                });
            }
        });
    }

    // ─── Calendrier de naissance (français, format JJ/MM/AAAA) ────────────────
    initDatePicker() {
        if (!this.dobMonthSelect || !this.dobYearSelect || !this.dobDaysGrid) return;

        MONTHS_FR.forEach((name, i) => {
            const opt = document.createElement('option');
            opt.value = i + 1;
            opt.textContent = name;
            this.dobMonthSelect.appendChild(opt);
        });

        const currentYear = new Date().getFullYear();
        for (let y = currentYear; y >= currentYear - 100; y--) {
            const opt = document.createElement('option');
            opt.value = y;
            opt.textContent = y;
            this.dobYearSelect.appendChild(opt);
        }

        this.dobViewMonth = new Date().getMonth() + 1;
        this.dobViewYear  = currentYear - 20;
        this.dobMonthSelect.value = this.dobViewMonth;
        this.dobYearSelect.value  = this.dobViewYear;
        this.renderDobDays();

        this.dobToggleBtn?.addEventListener('click', (e) => {
            e.stopPropagation();
            const isOpen = this.dobPopup.classList.toggle('open');
            this.dobToggleBtn.classList.toggle('active', isOpen);
        });

        this.dobMonthSelect.addEventListener('change', () => {
            this.dobViewMonth = parseInt(this.dobMonthSelect.value);
            this.renderDobDays();
        });
        this.dobYearSelect.addEventListener('change', () => {
            this.dobViewYear = parseInt(this.dobYearSelect.value);
            this.renderDobDays();
        });

        document.addEventListener('click', (e) => {
            if (!this.dobPopup || !this.dobPopup.classList.contains('open')) return;
            if (this.dobPopup.contains(e.target) || this.dobToggleBtn.contains(e.target)) return;
            this.dobPopup.classList.remove('open');
            this.dobToggleBtn.classList.remove('active');
        });
    }

    renderDobDays() {
        this.dobDaysGrid.innerHTML = '';
        const year = this.dobViewYear;
        const month = this.dobViewMonth; // 1-12
        const startOffset = (new Date(year, month - 1, 1).getDay() + 6) % 7; // Lundi = 0
        const daysInMonth = new Date(year, month, 0).getDate();

        for (let i = 0; i < startOffset; i++) {
            const empty = document.createElement('span');
            empty.className = 'date-picker-day empty';
            this.dobDaysGrid.appendChild(empty);
        }

        for (let d = 1; d <= daysInMonth; d++) {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'date-picker-day';
            btn.textContent = d;
            if (this.dob && this.dob.day === d && this.dob.month === month && this.dob.year === year) {
                btn.classList.add('selected');
            }
            btn.addEventListener('click', () => this.selectDob(d, month, year));
            this.dobDaysGrid.appendChild(btn);
        }
    }

    selectDob(day, month, year) {
        this.dob = { day, month, year };
        const dd = String(day).padStart(2, '0');
        const mm = String(month).padStart(2, '0');
        if (this.dobText) this.dobText.textContent = `${dd}/${mm}/${year}`;
        this.dobPopup.classList.remove('open');
        this.dobToggleBtn.classList.remove('active');
        this.renderDobDays();
        this.updateIdentity();
    }

    switchTab(tabName) {
        this.tabButtons.forEach(btn => btn.classList.toggle('active', btn.dataset.tab === tabName));
        this.tabContents.forEach(c => c.classList.toggle('active', c.id === tabName));
        if (this.optionsTitle) this.optionsTitle.textContent = TAB_LABELS[tabName] || tabName;
        this.sendToGame('tabChange', tabName);
    }

    changeSex(sex) {
        this.currentSex = parseInt(sex);
        this.sexButtons.forEach(btn => btn.classList.toggle('active', btn.dataset.sex === sex));
        this.sendToGame('changeSex', this.currentSex);
    }

    // ─── Mapping complet id → propriété skinchanger ───────────────────────────
    get sliderMap() {
        return {
            // Apparence
            hairStyle:          'hair_1',
            hairColor1:         'hair_color_1',
            hairColor2:         'hair_color_2',
            beardStyle:         'beard_1',
            beardOpacity:       'beard_2',
            beardColor:         'beard_3',
            chestHair:          'chest_1',
            chestHairOpacity:   'chest_2',
            eyebrows:           'eyebrows_1',
            eyebrowsOpacity:    'eyebrows_2',
            eyebrowsColor:      'eyebrows_3',
            eyeColor:           'eye_color',
            // Traits du visage
            noseWidth:          'nose_1',
            noseHeight:         'nose_2',
            noseLength:         'nose_3',
            noseBridge:         'nose_4',
            noseTip:            'nose_5',
            noseTwist:          'nose_6',
            eyebrowHeight:      'eyebrows_5',
            eyebrowDepth:       'eyebrows_6',
            cheekboneHeight:    'cheeks_1',
            cheekboneWidth:     'cheeks_2',
            cheekWidth:         'cheeks_3',
            eyeOpening:         'eye_squint',   // valeur inversée côté Lua
            lipThickness:       'lip_thickness',
            jawWidth:           'jaw_1',
            jawLength:          'jaw_2',
            chinLowering:       'chin_1',
            chinLength:         'chin_2',
            chinWidth:          'chin_3',
            chinDimple:         'chin_4',
            neckThickness:      'neck_thickness',
            // Héritage (sliders mix)
            resemblance:        'face_md_weight', // transformé côté Lua
            skinTone:           'skin_md_weight', // transformé côté Lua
            // Maquillage
            makeupStyle:        'makeup_1',
            makeupOpacity:      'makeup_2',
            makeupColor:        'makeup_3',
            lipstickStyle:      'lipstick_1',
            lipstickOpacity:    'lipstick_2',
            lipstickColor:      'lipstick_3',
            complexionStyle:    'complexion_1',
            complexionOpacity:  'complexion_2',
            wrinkles:           'age_1',
            wrinklesOpacity:    'age_2',
            bodyBlemishes:      'bodyb_1',
            bodyBlemishesOpacity:'bodyb_2',
            moles:              'moles_1',
            molesOpacity:       'moles_2',
            sunDamage:          'sun_1',
            sunDamageOpacity:   'sun_2',
        };
    }

    onSliderChange(event) {
        const slider  = event.target;
        const id      = slider.id;
        const value   = parseFloat(slider.value);

        const display = slider.nextElementSibling;
        if (display?.classList.contains('slider-value')) {
            display.textContent = (slider.step && parseFloat(slider.step) < 1)
                ? value.toFixed(1)
                : Math.floor(value).toString();
        }

        if (this.sliderMap[id]) {
            this.skinData[id] = value;
            this.sendToGame('updateCharacter', { id, value });
        }

    }

    stepParent(who, dir) {
        if (who === 'mother') {
            this.motherIndex = (this.motherIndex + dir + MOTHERS.length) % MOTHERS.length;
            this.updateParentUI('mother');
        } else {
            this.fatherIndex = (this.fatherIndex + dir + FATHERS.length) % FATHERS.length;
            this.updateParentUI('father');
        }
        this.onHeritageChange();
    }

    updateParentUI(who) {
        if (who === 'mother') {
            const name = MOTHERS[this.motherIndex];
            this.motherName.textContent = name;
            const img = this.motherPhoto;
            if (img) {
                img.style.display = 'block';
                img.nextElementSibling.style.display = 'none';
                img.src = `img/parents/mothers/${name}.png`;
            }
        } else {
            const name = FATHERS[this.fatherIndex];
            this.fatherName.textContent = name;
            const img = this.fatherPhoto;
            if (img) {
                img.style.display = 'block';
                img.nextElementSibling.style.display = 'none';
                img.src = `img/parents/fathers/${name}.png`;
            }
        }
    }

    onHeritageChange() {
        this.heritageData = {
            mother:      this.motherIndex,
            father:      this.fatherIndex,
            resemblance: parseFloat(document.getElementById('resemblance')?.value ?? 5),
            skinTone:    parseFloat(document.getElementById('skinTone')?.value ?? 5),
        };
        this.sendToGame('updateHeritage', this.heritageData);
    }

    updateIdentity() {
        const dob = this.dob
            ? `${String(this.dob.day).padStart(2, '0')}/${String(this.dob.month).padStart(2, '0')}/${this.dob.year}`
            : '';

        this.identityData = {
            firstName:   this.firstNameInput?.value  || '',
            lastName:    this.lastNameInput?.value   || '',
            dateOfBirth: dob,
            height:      parseInt(this.heightInput?.value) || 0,
            birthPlace:  this.birthPlaceInput?.value || '',
        };
        this.sendToGame('updateIdentity', this.identityData);
    }

    confirm() {
        this.sendToGame('confirmCharacter', {
            sex:      this.currentSex,
            skin:     this.skinData,
            heritage: this.heritageData,
            identity: this.identityData,
        });
    }

    reset() {
        this.sliders.forEach(slider => {
            const def = slider.dataset.default
                ?? ((slider.id === 'resemblance' || slider.id === 'skinTone') ? '5' : '0');
            slider.value = def;
            slider.dispatchEvent(new Event('input'));
        });

        this.currentSex = 0;
        this.sexButtons[0]?.click();

        this.motherIndex = 0;
        this.fatherIndex = 0;
        this.updateParentUI('mother');
        this.updateParentUI('father');
        this.onHeritageChange();

        if (this.firstNameInput)  this.firstNameInput.value  = '';
        if (this.lastNameInput)   this.lastNameInput.value   = '';
        this.dob = null;
        if (this.dobText) this.dobText.textContent = 'JJ/MM/AAAA';
        this.renderDobDays();
        if (this.heightInput)     this.heightInput.value     = '';
        if (this.birthPlaceInput) this.birthPlaceInput.value = '';

        this.sendToGame('resetCharacter');
    }


    handleKeydown(event) {
        // Ne pas tourner le personnage si les flèches servent à un contrôle
        // du formulaire (slider, select, champ texte) qui les gère déjà lui-même.
        const tag = event.target?.tagName;
        if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA' || tag === 'BUTTON') return;

        if (event.key === 'ArrowLeft')  this.sendToGame('rotateCharacter', -10);
        else if (event.key === 'ArrowRight') this.sendToGame('rotateCharacter', 10);
    }

    sendToGame(action, data) {
        fetch(`https://${GetParentResourceName()}/creatorAction`, {
            method:  'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body:    JSON.stringify({ action, data }),
        });
    }

    loadSkinData(data) {
        if (data.sex !== undefined) {
            this.currentSex = data.sex;
            this.sexButtons[data.sex]?.click();
        }
        Object.keys(data).forEach(key => {
            const el = document.getElementById(key);
            if (el) {
                el.value = data[key];
                el.dispatchEvent(new Event('input'));
            }
        });
    }

    applyMaxValues(maxVals) {
        console.log('[Creator][DEBUG] applyMaxValues reçu:', maxVals);
        console.log('[Creator][DEBUG] hair_1 dans maxVals =', maxVals?.hair_1);

        // Reverse map: skinchanger prop name → slider id
        const reverseMap = {};
        for (const [sliderId, prop] of Object.entries(this.sliderMap)) {
            reverseMap[prop] = sliderId;
        }
        for (const [prop, max] of Object.entries(maxVals)) {
            if (max == null || max <= 0) {
                console.log(`[Creator][DEBUG] ignoré (max<=0): ${prop} = ${max}`);
                continue;
            }
            const sliderId = reverseMap[prop] ?? prop;
            // 'resemblance'/'skinTone' utilisent une échelle UI fixe 0-10
            // (transformée en 0-100 côté Lua avant d'être envoyée au
            // skinchanger) : le max natif (100) ne doit pas leur être appliqué.
            if (FIXED_RANGE_SLIDERS.has(sliderId)) continue;
            const slider = document.getElementById(sliderId);
            if (!slider) {
                console.log(`[Creator][DEBUG] pas de slider DOM pour: ${prop} -> ${sliderId}`);
                continue;
            }
            console.log(`[Creator][DEBUG] set ${sliderId} (${prop}) max: ${slider.max} -> ${max}`);
            slider.max = max;
            const display = slider.nextElementSibling;
            if (display?.classList.contains('slider-value')) {
                // Clamp value if it now exceeds the new max
                if (parseFloat(slider.value) > max) {
                    slider.value = max;
                    display.textContent = max;
                }
            }
        }
    }

    loadIdentityData(data) {
        if (this.firstNameInput  && data.firstName)  this.firstNameInput.value  = data.firstName;
        if (this.lastNameInput   && data.lastName)   this.lastNameInput.value   = data.lastName;
        if (data.dateOfBirth) {
            const parts = data.dateOfBirth.split('/');
            if (parts.length === 3) {
                const [dd, mm, yyyy] = parts;
                this.dob = { day: parseInt(dd), month: parseInt(mm), year: parseInt(yyyy) };
                if (this.dobText) this.dobText.textContent = `${dd}/${mm}/${yyyy}`;
                this.dobViewMonth = this.dob.month;
                this.dobViewYear  = this.dob.year;
                if (this.dobMonthSelect) this.dobMonthSelect.value = this.dobViewMonth;
                if (this.dobYearSelect)  this.dobYearSelect.value  = this.dobViewYear;
                this.renderDobDays();
            }
        }
        if (this.heightInput  && data.height)     this.heightInput.value  = data.height;
        if (this.birthPlaceInput && data.birthPlace) this.birthPlaceInput.value = data.birthPlace;
    }
}

let creator = null;

document.addEventListener('DOMContentLoaded', () => {
    creator = new CharacterCreator();

    const container = document.getElementById('creatorContainer');
    const isNUI = typeof GetParentResourceName !== 'undefined';

    if (!isNUI) {
        document.body.style.background = 'linear-gradient(135deg, #0f0f0f 0%, #1a1a2e 100%)';
        container.style.display = 'flex';
    }

    window.addEventListener('message', (event) => {
        const data = event.data;
        const inventoryFrame = document.getElementById('inventoryFrame');
        if (data.action === 'show') {
            container.style.display = 'flex';
            if (inventoryFrame) inventoryFrame.style.display = 'none';
            //requestAnimationFrame(() => creator.sendPreviewLayout());
        } else if (data.action === 'creator:hide') {
            container.style.display = 'none';
            if (inventoryFrame) {
                inventoryFrame.style.display = 'block';
                inventoryFrame.style.pointerEvents = 'auto';
            }
        } else if (data.action === 'loadSkinData') {
            creator.loadSkinData(data.data);
        } else if (data.action === 'loadIdentityData') {
            creator.loadIdentityData(data.data);
        } else if (data.action === 'setSliderMaxValues') {
            creator.applyMaxValues(data.data);
        }
    });
});

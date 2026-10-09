/* ════════════════════════════════════════════════════════════════
   MDT POLICE — Onglet « Interventions » (missions PNJ / appels 17)
   ────────────────────────────────────────────────────────────────
   Chargé APRÈS mdt.js, dont il ne modifie rien : il s'enregistre
   dans le point d'extension window.MDT_RENDERERS et réutilise les
   helpers globaux (esc, setContent, emptyState, fetchNui, fmtDate).

   Toutes les lectures passent par le pont dédié `mdtco:*`, servi par
   module/police/server/callouts.lua.
   ════════════════════════════════════════════════════════════════ */

/* Message d'erreur simple. Le MDT expose openModal ; on s'en sert
   plutôt que d'un alert() natif, bloqué dans une NUI. */
function alertBox(msg) {
    openModal('Opération impossible', `<p>${esc(msg)}</p>`,
        `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Fermer</button>`);
}

const coState = {
    page: 1,
    open: {},   // { [calloutId]: true } — lignes dépliées
    regUnit: null,
    regCrew: null,
    cicUnitFilter: 'all',
};

/* ── Libellés ──────────────────────────────────────────────────── */

const CO_STATUS = {
    in_progress: { label: 'En cours',          cls: 'mdt-badge-blue' },
    success:     { label: 'Réussite',          cls: 'mdt-badge-green' },
    failed:      { label: 'Échec',             cls: 'mdt-badge-red' },
    cancelled:   { label: 'Classé sans suite', cls: 'mdt-badge-gray' },
};

/* Trois informations peuvent cohabiter sur un dossier :
     · le résultat de l'intervention (réussite, échec, sans suite) ;
     · une saisine IGPN, qui prime sur le résultat ;
     · le classement par le commissaire, qui remplace le résultat.

   Une affaire classée reste signalée IGPN si une bavure a été commise :
   le classement clôt la procédure, il n'efface pas la faute. */
function coStatus(s, misconducts, closed) {
    const bav = parseInt(misconducts, 10) || 0;
    const igpn = bav > 0
        ? `<span class="mdt-badge mdt-badge-red" title="${esc(
              bav > 1 ? `${bav} bavures constatées` : 'Bavure constatée')}">IGPN</span>`
        : '';

    const filed = '<span class="mdt-badge mdt-badge-blue">Affaire classée</span>';

    /* Une saisine IGPN interdit de qualifier l'intervention de réussite :
       le résultat n'est JAMAIS affiché à côté. Seul le classement peut
       l'accompagner, pour indiquer que la procédure est instruite. */
    if (igpn) {
        return (Number(closed) === 1) ? `${filed}${igpn}` : igpn;
    }

    const m = CO_STATUS[s] || { label: s || '?', cls: 'mdt-badge-gray' };
    const result = `<span class="mdt-badge ${m.cls}">${esc(m.label)}</span>`;

    return (Number(closed) === 1) ? `${result}${filed}` : result;
}

function coDuration(sec) {
    const n = parseInt(sec, 10);
    if (!n || n < 0) return '—';
    if (n < 60) return `${n} s`;
    return `${Math.floor(n / 60)} min ${n % 60} s`;
}

/* Un individu enfui ou non contrôlé n'a jamais d'identité. */
function coPersonName(p) {
    // Nom de famille en majuscules : convention des fiches MDT, pour le
    // distinguer du prénom d'un coup d'œil.
    if (p && p.firstname && p.lastname) return `${p.firstname} ${p.lastname.toUpperCase()}`;
    return (p && p.label) || 'Individu non identifié';
}

/* Le libellé dépend du rôle : « présenté au poste » n'a aucun sens pour
   une personne assistée ou pour un défunt. */
const CO_OUTCOME = {
    delivered: { label: 'Interpellé(e)',     cls: 'mdt-badge-green' },
    dispersed: { label: 'Laissé(e) libre',   cls: 'mdt-badge-blue' },
    dead:      { label: 'Neutralisé',        cls: 'mdt-badge-red' },
    escaped:   { label: 'En fuite',          cls: 'mdt-badge-orange' },
    morgue:    { label: 'Corps à la morgue', cls: 'mdt-badge-gray' },
    cuffed:    { label: 'Menotté(e)',        cls: 'mdt-badge-orange' },
    // Individu jamais engagé individuellement (ex. fêtards d'un tapage,
    // résolu par la coupure de la sono et non par leur propre état).
    idle:      { label: 'N/C',               cls: 'mdt-badge-gray' },
};

const CO_OUTCOME_BY_ROLE = {
    wanderer: {
        delivered: { label: 'Présenté(e) à l\'hôpital', cls: 'mdt-badge-green' },
        dispersed: { label: 'Laissé(e) sur place',     cls: 'mdt-badge-blue' },
    },
    deceased: {
        morgue: { label: 'Corps à la morgue', cls: 'mdt-badge-gray' },
    },
    animal: {
        dead:   { label: 'Animal neutralisé',   cls: 'mdt-badge-red' },
        morgue: { label: 'Dépouille évacuée',   cls: 'mdt-badge-gray' },
    },
};

function coOutcome(o, role) {
    if (!o) return '';
    const byRole = (CO_OUTCOME_BY_ROLE[role] || {})[o];
    const m = byRole || CO_OUTCOME[o] || { label: o, cls: 'mdt-badge-gray' };
    return `<span class="mdt-badge ${m.cls}">${esc(m.label)}</span>`;
}

/* Trame de PV pré-remplie avec les vraies données de la mission, propre
   à chaque type d'intervention (row.scenario_id) — l'agent n'a plus qu'à
   compléter les champs manuels et la partie narrative. Scénarios sans
   trame dédiée : textarea vide, comportement inchangé. */
/* Champs communs à toutes les trames — seule partie réellement
   auto-remplie (identité de l'agent + horodatage) : le reste du PV
   (lieu, personnes, déclarations, constatations…) reste à saisir par
   le joueur, sans quoi rédiger un rapport se limiterait à cliquer sur
   un bouton. */
function coReportAgentFields(row) {
    const dt = row.started_at ? new Date(row.started_at) : null;
    const pad = (n) => String(n).padStart(2, '0');
    return {
        dateStr: dt
            ? `${pad(dt.getDate())} / ${pad(dt.getMonth() + 1)} / ${dt.getFullYear()}`
            : '____ / ____ / ______',
        timeStr: dt ? `${pad(dt.getHours())}:${pad(dt.getMinutes())}` : '______',
        officerName: (state.payload && state.payload.officerName) || '__________________________',
        gradeLabel: (state.payload && state.payload.gradeLabel) || '__________________________',
        matricule: (state.payload && state.payload.matricule) || '__________________________',
        // Indicatif figé à la prise en charge (row.unit_label) : fiable
        // même si l'agent n'est plus inscrit à un groupe d'intervention
        // au moment de rédiger. Repli sur l'indicatif live, puis vide.
        unit: row.unit_label || (state.payload && state.payload.callsign) || '__________________________',
        // row.zone stocke déjà le nom de rue relevé en jeu (repli sur le
        // libellé de quartier) — cf. server/callouts.lua, colonne `zone`.
        address: row.zone || '__________________________',
    };
}

/* Cases à cocher communes à (presque) toutes les trames — dérivées des
   vraies données de la mission (cf. p.wanted/p.wounded/p.outcome dans
   suspects_json). Là où aucun signal fiable n'existe (ex. comportement à
   l'arrivée, non persisté), une estimation raisonnable est faite plutôt
   que de laisser la case vide — signalée par un commentaire. */
function coWantedLine(p) {
    const wanted = !!(p && p.wanted);
    return `${(p && p.repeatOffender) ? '☒' : '☐'} Récidiviste   ${wanted ? '☒' : '☐'} Fiche de recherche : ${
        wanted ? (p.wantedReason || 'motif non précisé') : '__________________________'}`;
}

function coWoundedLine(p) {
    const w = !!(p && p.wounded);
    return `${w ? '☒' : '☐'} Blessé(e) — soigné(e) : ${(w && p.healed) ? '☒' : '☐'} Oui ${(w && !p.healed) ? '☒' : '☐'} Non`;
}

function coOutcomeFlags(p) {
    const o = p && p.outcome;
    return {
        escaped: o === 'escaped', dead: o === 'dead',
        cuffed: o === 'cuffed', delivered: o === 'delivered',
        dispersed: o === 'dispersed',
        caught: o === 'cuffed' || o === 'delivered',
    };
}

// Le comportement (passif/fuite/agressif) n'est pas persisté tel quel :
// estimé à partir de l'issue finale (échappé→fuite, mort→agressif,
// interpellé sans heurt→passif par défaut).
function coBehaviorGuess(p) {
    // Comportement réel persisté, désormais fiable — la déduction depuis
    // l'issue reste un repli pour les dossiers créés avant son ajout.
    if (p && p.behavior) return p.behavior;
    const o = coOutcomeFlags(p);
    if (o.escaped) return 'flee';
    if (o.dead) return 'aggressive';
    return 'passive';
}

// categories: [{ key, test (RegExp) }] testés contre p.seized.
function coFouilleFlags(p, categories) {
    const seized = (p && Array.isArray(p.seized)) ? p.seized : [];
    const out = { rien: seized.length === 0 };
    for (const c of categories) out[c.key] = seized.some((s) => c.test.test(s));
    const leftovers = seized.filter((s) => !categories.some((c) => c.test.test(s)));
    out.autre = leftovers.length > 0;
    out.autreText = leftovers.length ? leftovers.join(', ') : '__________________________';
    return out;
}

// Icône de chaque PV complet, réutilisée pour l'en-tête du PV allégé.
const CO_SCENARIO_ICON = {
    constatation_effraction: '🏠', delit_fuite: '🚧', bagarre_rue: '👊',
    braquage_superette: '🏪', cambriolage: '🏠', chien_dangereux: '🐕',
    decouverte_corps: '⚰️', personne_armee: '🔫', ipm: '🍺',
    personne_errante: '🚶', racolage: '💃', rixe_soiree: '🥊',
    rodeo_urbain: '🏍️',
    tapage: '🔊', trafic_stup: '💊', tuerie_masse: '🔴',
    vol_arrache: '👜', vol_etalage: '🛒', vol_vehicule: '🚗',
};

// Fausse alerte : rien à constater, rien à interpeller — le PV se réduit
// à ce qui a réellement eu lieu (le déplacement et la déposition qui a
// clos l'intervention), sans les sections prévues pour une scène qui ne
// s'est jamais produite. Même principe que les PV complets : ce qui est
// connu du jeu est pré-rempli, le reste (identité du requérant, signature)
// reste à la charge de l'agent.
function coFalseAlarmReport(row) {
    const f = coReportAgentFields(row);
    const icon = CO_SCENARIO_ICON[row.scenario_id] || '🚨';
    const label = (row.label || 'Intervention').toUpperCase();

    return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${icon} PV — ${label}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Lieu : ${f.address}
👤 REQUÉRANT
Nom / Prénom : __________________________
📝 DÉCLARATION DU REQUÉRANT
Le requérant nous déclare :
« ____________________________________________________
____________________________________________________ »

Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
}

function coReportTemplate(row) {
    if (Number(row.false_alarm) === 1) {
        return coFalseAlarmReport(row);
    }

    if (row.scenario_id === 'constatation_effraction') {
        const f = coReportAgentFields(row);
        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏠 PV — CONSTATATION DE VOL PAR EFFRACTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Adresse : ${f.address}
👤 PROPRIÉTAIRE / REQUÉRANT
Nom / Prénom : __________________________
📝 DÉCLARATION DU REQUÉRANT
Le requérant nous déclare :
« ____________________________________________________
____________________________________________________ »
🔎 CONSTATATIONS
À notre arrivée, nous constatons :



Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'delit_fuite') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const suspects = people.filter((p) => p.role === 'suspect');
        const suspect  = suspects[0] || {};
        const s2       = suspects[1];
        // requireAid + requireImpound : la mission n'aboutit (status
        // « success ») qu'une fois la victime soignée ET le véhicule
        // mis en fourrière — fiable comme proxy pour ces deux cases.
        const success = row.status === 'success';
        const seized  = Array.isArray(suspect.seized) ? suspect.seized : [];
        const o1      = coOutcomeFlags(suspect);
        const libre   = o1.dispersed;
        const wanted  = !!suspect.wanted;
        // Pas de distinction fiable entre « resté sur place » et « rattrapé
        // après avoir fui » (comportement non persisté) — comme le scénario
        // fait fuir 90 % des suspects par défaut, un suspect interpellé
        // (sans jamais avoir échappé) est présumé avoir fui puis été
        // rattrapé plutôt que resté immobile.
        const o2 = coOutcomeFlags(s2);

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚧 PV — ACCIDENT VOIE PUBLIQUE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Lieu : ${f.address}
👤 REQUÉRANT
Nom / Prénom : __________________________
📝 DÉCLARATION DU REQUÉRANT
Le requérant nous déclare :
« ____________________________________________________
____________________________________________________ »
👤 VICTIME
Nom / Prénom : __________________________
📝 DÉCLARATION DE LA VICTIME


🚗 VÉHICULE
Marque / modèle : ${row.vehicle_model || '__________________________'}
Plaque : ${row.vehicle_plate || '__________________________'}
📝 CIRCONSTANCES
Déroulement de l'accident :


👤 SUSPECT N°1
Nom / Prénom : __________________________
${coWantedLine(suspect)}
${o1.escaped ? '☒' : '☐'} A pris la fuite
${(!o1.escaped && !o1.caught) ? '☒' : '☐'} Retrouvé sur place
${o1.caught ? '☒' : '☐'} Retrouvé après les faits
Version des faits :

Fouille :
${seized.length ? '☐' : '☒'} Rien
${seized.length ? '☒' : '☐'} Autre : ${seized.length ? seized.join(', ') : '__________________________'}
Suite :
${libre ? '☒' : '☐'} Laissé libre
${o1.caught ? '☒' : '☐'} Menotté / interpellé
👤 SUSPECT N°2 — SI NÉCESSAIRE
Nom / Prénom : __________________________
${coWantedLine(s2)}
Déclaration / circonstances :

Suite : ${o2.dispersed ? '☒' : '☐'} Libre ${o2.caught ? '☒' : '☐'} Menotté / interpellé
🚑 VICTIME
Premiers soins prodigués :
${success ? '☒' : '☐'} Oui
${success ? '☐' : '☒'} Non
🚗 VÉHICULE
${success ? '☐' : '☒'} Laissé sur place
${success ? '☒' : '☐'} Mis en fourrière
📌 OBSERVATIONS

Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'bagarre_rue') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const suspects = people.filter((p) => p.role === 'suspect');
        const count = suspects.length;

        const personBlock = (p) => {
            const wanted = !!p && !!p.wanted;
            return {
                repeat: (p && p.repeatOffender) ? '☒' : '☐',
                wanted: wanted ? '☒' : '☐',
                wantedReason: wanted ? (p.wantedReason || 'motif non précisé') : '__________________________',
                blesse: (p && p.wounded) ? '☒' : '☐',
                soigneOui: (p && p.wounded && p.healed) ? '☒' : '☐',
                soigneNon: (p && p.wounded && !p.healed) ? '☒' : '☐',
                libre: (!!p && p.outcome === 'dispersed') ? '☒' : '☐',
                menotte: (!!p && p.outcome === 'cuffed') ? '☒' : '☐',
                commissariat: (!!p && p.outcome === 'delivered') ? '☒' : '☐',
            };
        };
        const p1 = personBlock(suspects[0]);
        const p2 = personBlock(suspects[1]);

        // Arme partagée par le groupe (weapons.mode='perGroup') : un seul
        // suspect la porte réellement, peu importe lequel.
        const armed = suspects.find((p) => p.weapon);
        const weapon = armed ? armed.weapon : null;
        const bearerName = armed && armed.firstname ? `${armed.firstname} ${armed.lastname.toUpperCase()}` : '__________________________';

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👊 PV — BAGARRE DE RUE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Lieu : ${f.address}
👤 REQUÉRANT
Nom / Prénom : __________________________
📝 DÉCLARATION DU REQUÉRANT
Le requérant nous déclare :
« ____________________________________________________
____________________________________________________ »
📝 CIRCONSTANCES
À notre arrivée, nous constatons une bagarre impliquant :
${count === 2 ? '☒' : '☐'} 2 personnes
${count === 3 ? '☒' : '☐'} 3 personnes
${count >= 4 ? '☒' : '☐'} 4 personnes
Déroulement constaté :


👤 PERSONNES IMPLIQUÉES
Personne N°1 :
Nom / Prénom : __________________________
${p1.repeat} Récidiviste   ${p1.wanted} Fiche de recherche : ${p1.wantedReason}
${p1.blesse} Blessé(e) — soigné(e) : ${p1.soigneOui} Oui ${p1.soigneNon} Non
Version des faits : ________________________________
Fouille : __________________________________________
Arme retrouvée : __________________________________
Suite :
${p1.libre} Laissée libre
${p1.menotte} Menottée
${p1.commissariat} Emmenée au commissariat
Personne N°2 :
Nom / Prénom : __________________________
${p2.repeat} Récidiviste   ${p2.wanted} Fiche de recherche : ${p2.wantedReason}
${p2.blesse} Blessé(e) — soigné(e) : ${p2.soigneOui} Oui ${p2.soigneNon} Non
Version des faits : ________________________________
Fouille : __________________________________________
Arme retrouvée : __________________________________
Suite :
${p2.libre} Laissée libre
${p2.menotte} Menottée
${p2.commissariat} Emmenée au commissariat
Personne N°3 / N°4 si nécessaire :


🔪 ARME
Type : ${weapon === 'Couteau' ? '☒' : '☐'} Couteau ${
    weapon === 'Batte de baseball' ? '☒' : '☐'} Batte de baseball ${
    weapon && weapon !== 'Couteau' && weapon !== 'Batte de baseball' ? '☒' : '☐'} Autre : ${
    (weapon && weapon !== 'Couteau' && weapon !== 'Batte de baseball') ? weapon : '______'}
Porteur identifié : ${bearerName}
Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'braquage_superette') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const all      = people.filter((p) => p.role === 'suspect');
        // Le chauffeur a son propre encart plus bas : les « suspects »
        // numérotés ne doivent lister que le reste de l'équipe (chef +
        // exécutants), sinon il apparaissait deux fois (une fois vide en
        // Suspect N°x, une fois correctement renseigné en Chauffeur) et
        // un vrai exécutant (jusqu'à 3 sur une mission à 4) n'avait
        // jamais que le bloc générique à remplir à la main.
        const crew     = all.filter((p) => !p.isDriver);
        const driver   = all.find((p) => p.isDriver);
        const count    = all.length;

        const behaviorLines = (p) => {
            const b = coBehaviorGuess(p);
            return `${b === 'passive' ? '☒' : '☐'} Passif ${b === 'flee' ? '☒' : '☐'} Fuite ${
                b === 'aggressive' ? '☒' : '☐'} Agressif`;
        };
        const weaponLines = (p) => {
            const w = (p && p.weapon) || '';
            return `${/couteau/i.test(w) ? '☒' : '☐'} Couteau ${/pistolet/i.test(w) ? '☒' : '☐'} Pistolet`;
        };
        const fouilleLines = (p) => coFouilleFlags(p, [
            { key: 'caisse', test: /caisse/i }, { key: 'billets', test: /billets/i },
        ]);
        const dOut = coOutcomeFlags(driver);

        // Autant de blocs « SUSPECT » que de membres réels de l'équipe
        // (chef + exécutants, chauffeur exclu) — ni case vide en trop,
        // ni exécutant laissé sans section.
        const crewBlocks = crew.map((p, i) => {
            const fl = fouilleLines(p);
            const o  = coOutcomeFlags(p);
            return `👤 SUSPECT N°${i + 1}
Nom / Prénom : __________________________
${coWantedLine(p)}
${coWoundedLine(p)}
Comportement :
${behaviorLines(p)}
Arme :
${weaponLines(p)}
Fouille :
${fl.rien ? '☒' : '☐'} Rien
${fl.caisse ? '☒' : '☐'} Argent de caisse
${fl.billets ? '☒' : '☐'} Liasse de billets
${fl.autre ? '☒' : '☐'} Autre : ${fl.autreText}
${o.caught ? '☒' : '☐'} Menotté`;
        }).join('\n');

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏪 PV — BRAQUAGE DE SUPÉRETTE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Commerce : ${f.address}
👤 CAISSIER / REQUÉRANT
Nom / Prénom : __________________________
📝 DÉCLARATION DU REQUÉRANT
Le requérant nous indique :
« ____________________________________________________
____________________________________________________ »
👥 NOMBRE DE SUSPECTS (chef + exécutants + chauffeur)
${count === 2 ? '☒' : '☐'} 2 ${count === 3 ? '☒' : '☐'} 3 ${count >= 4 ? '☒' : '☐'} 4
📝 DÉROULEMENT


${crewBlocks}
🚗 CHAUFFEUR / VÉHICULE DE FUITE
Chauffeur identifié :
Nom / Prénom : __________________________
${coWantedLine(driver)}
${dOut.escaped ? '☒' : '☐'} A pris la fuite avant l'intervention du groupe
${dOut.caught ? '☒' : '☐'} Interpellé sur place
Véhicule :
${dOut.escaped ? '☐' : '☒'} Laissé sur place
☐ Mis en fourrière
${dOut.escaped ? '☒' : '☐'} En fuite, non retrouvé
Signature de l'agent : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'cambriolage') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const all    = people.filter((p) => p.role === 'suspect');
        const driver = all.find((p) => p.isDriver);
        const dOut   = coOutcomeFlags(driver);
        const driverName = driver && driver.firstname ? `${driver.firstname} ${driver.lastname.toUpperCase()}` : '__________________________';
        // Comportement du groupe estimé sur le premier suspect non-chauffeur
        // (behaviors du scénario est global, pas d'AND fiable individu par
        // individu — cf. coBehaviorGuess).
        const groupBehavior = coBehaviorGuess(all.find((p) => !p.isDriver));

        const fouilleLines = (p) => coFouilleFlags(p, [
            { key: 'bijoux', test: /bijoux/i }, { key: 'billets', test: /billets/i },
            { key: 'montre', test: /montre/i },
        ]);
        const p1 = all[0], p2 = all[1], p3 = all[2], p4 = all[3] || driver;
        const fl1 = fouilleLines(p1), fl2 = fouilleLines(p2), fl3 = fouilleLines(p3), fl4 = fouilleLines(p4);
        const o1 = coOutcomeFlags(p1), o2 = coOutcomeFlags(p2), o3 = coOutcomeFlags(p3), o4 = coOutcomeFlags(p4);

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏠 PV — CAMBRIOLAGE RÉSIDENTIEL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Lieu : ${f.address}
👥 SUSPECTS
Nombre : ${all.length || 4}
📝 COMPORTEMENT À L'ARRIVÉE
${groupBehavior === 'flee' ? '☒' : '☐'} Fuite
${groupBehavior === 'aggressive' ? '☒' : '☐'} Agressivité
👤 SUSPECT N°1
Nom / Prénom : __________________________
${coWantedLine(p1)}
${coWoundedLine(p1)}
Arme :
${/couteau/i.test((p1 && p1.weapon) || '') ? '☒' : '☐'} Couteau
${/pistolet/i.test((p1 && p1.weapon) || '') ? '☒' : '☐'} Pistolet
Fouille :
${fl1.rien ? '☒' : '☐'} Rien
${fl1.bijoux ? '☒' : '☐'} Bijoux
${fl1.billets ? '☒' : '☐'} Liasse de billets
${fl1.montre ? '☒' : '☐'} Montre de valeur
${fl1.autre ? '☒' : '☐'} Autre : ${fl1.autreText}
${o1.caught ? '☒' : '☐'} Menotté
👤 SUSPECT N°2
Nom / Prénom : __________________________
${coWantedLine(p2)}
${coWoundedLine(p2)}
Arme : ${(p2 && p2.weapon) || '__________________________'}
Fouille :
${fl2.rien ? '☒' : '☐'} Rien
${fl2.bijoux ? '☒' : '☐'} Bijoux
${fl2.billets ? '☒' : '☐'} Liasse de billets
${fl2.montre ? '☒' : '☐'} Montre de valeur
${fl2.autre ? '☒' : '☐'} Autre : ${fl2.autreText}
${o2.caught ? '☒' : '☐'} Menotté
👤 SUSPECT N°3
Nom / Prénom : __________________________
${coWantedLine(p3)}
${coWoundedLine(p3)}
Arme : ${(p3 && p3.weapon) || '__________________________'}
Fouille :
${fl3.rien ? '☒' : '☐'} Rien
${fl3.bijoux ? '☒' : '☐'} Bijoux
${fl3.billets ? '☒' : '☐'} Liasse de billets
${fl3.montre ? '☒' : '☐'} Montre de valeur
${fl3.autre ? '☒' : '☐'} Autre : ${fl3.autreText}
${o3.caught ? '☒' : '☐'} Menotté
👤 SUSPECT N°4 / CHAUFFEUR
Nom / Prénom : ${driverName}
${coWantedLine(p4)}
${coWoundedLine(p4)}
Arme : ${(p4 && p4.weapon) || '__________________________'}
Fouille :
${fl4.rien ? '☒' : '☐'} Rien
${fl4.bijoux ? '☒' : '☐'} Bijoux
${fl4.billets ? '☒' : '☐'} Liasse de billets
${fl4.montre ? '☒' : '☐'} Montre de valeur
${fl4.autre ? '☒' : '☐'} Autre : ${fl4.autreText}
${o4.caught ? '☒' : '☐'} Menotté
${dOut.escaped ? '☒' : '☐'} A pris la fuite en véhicule avant l'intervention du groupe
📌 OBSERVATIONS


Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'chien_dangereux') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const master = people.find((p) => p.role === 'suspect') || {};
        const animal = people.find((p) => p.role === 'animal');
        const animalDead = !!animal && animal.outcome === 'morgue';
        const o = coOutcomeFlags(master);
        const fl = coFouilleFlags(master, []);
        const success = row.status === 'success';

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🐕 PV — CHIEN DANGEREUX
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Lieu : ${f.address}
👤 REQUÉRANT
Nom / Prénom : __________________________
📝 DÉCLARATION DU REQUÉRANT
Le requérant nous indique :
« ____________________________________________________
____________________________________________________ »
👤 VICTIME
Nom / Prénom : __________________________
📝 DÉCLARATION DE LA VICTIME


📝 CIRCONSTANCES
À notre arrivée, nous constatons que le chien a attaqué la victime.
Déroulement :


Le chien a également attaqué l'agent intervenant : __________________________
🐕 ANIMAL
Race / description : ${(animal && animal.breed) || '_________________________________'}
${animalDead ? '☒' : '☐'} Décès de l'animal constaté
👤 MAÎTRE DU CHIEN
Nom / Prénom : __________________________
${coWantedLine(master)}
${coWoundedLine(master)}
Fouille :
${fl.rien ? '☒' : '☐'} Rien
${fl.autre ? '☒' : '☐'} Autre : ${fl.autreText}
Déclaration :

Suite :
${o.dispersed ? '☒' : '☐'} Laissé libre
${o.caught ? '☒' : '☐'} Menotté / interpellé
🚑 VICTIME
Premiers soins prodigués :
${success ? '☒' : '☐'} Oui
${success ? '☐' : '☒'} Non
Observations sur les blessures :

📌 SUITE DE L'INTERVENTION

Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'decouverte_corps') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const deceased = people.find((p) => p.role === 'deceased' || p.role === 'wanderer') || {};
        // La mission n'aboutit (statut « success ») qu'une fois le décès
        // constaté ET le corps pris en charge (objective='death') —
        // fiable comme proxy pour ces deux cases.
        const deathConstated  = row.status === 'success';
        const familyNotified  = !!deceased.familyContactNotified;

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚰️ PV — DÉCOUVERTE DE CORPS SUR LA VOIE PUBLIQUE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Lieu : ${f.address}
👤 REQUÉRANT
Nom / Prénom : __________________________
📝 DÉCOUVERTE DU CORPS
Le requérant nous indique :
« ____________________________________________________
____________________________________________________ »
👤 VICTIME
Nom / Prénom : __________________________
🔎 CONSTATATIONS
Cause apparente / informations obtenues :

🚑 PRISE EN CHARGE
${deathConstated ? '☒' : '☐'} Décès constaté
${deathConstated ? '☒' : '☐'} Corps pris en charge par les secours
👨‍👩‍👦 FAMILLE
Famille prévenue :
${familyNotified ? '☒' : '☐'} Oui
${familyNotified ? '☐' : '☒'} Non
Nom du proche : __________________________
Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'personne_armee') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const p = people.find((pp) => pp.role === 'suspect') || {};
        const weapon  = p.weapon || '';
        const isKnife = /couteau/i.test(weapon);
        const isGun   = /pistolet/i.test(weapon);
        const o = coOutcomeFlags(p);

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔫 PV — INDIVIDU ARMÉ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Lieu : ${f.address}
👤 REQUÉRANT
Nom / Prénom : __________________________
📝 DÉCLARATION DU REQUÉRANT
Le requérant nous indique :
« ____________________________________________________
____________________________________________________ »
👤 INDIVIDU
Nom / Prénom : __________________________
${coWantedLine(p)}
${coWoundedLine(p)}
🔫 ARME
${isKnife ? '☒' : '☐'} Couteau
${isGun ? '☒' : '☐'} Pistolet
${(weapon && !isKnife && !isGun) ? '☒' : '☐'} Autre : ${(weapon && !isKnife && !isGun) ? weapon : '__________________________'}
📄 PERMIS DE PORT D'ARME
${p.permitValid === true ? '☒' : '☐'} Présent et valide
${p.permitValid === false ? '☒' : '☐'} Présent mais non valide
Absent : __________________________
${(p.permitValid === undefined || p.permitValid === null) ? '☒' : '☐'} Non vérifié
🗣️ EXPLICATIONS DE L'INDIVIDU


🔎 FOUILLE
Résultat :

📌 SUITE
${o.dispersed ? '☒' : '☐'} Laissé libre
${o.caught ? '☒' : '☐'} Menotté / interpellé
Observations :

Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'ipm') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const p = people.find((pp) => pp.role === 'suspect') || {};
        const o = coOutcomeFlags(p);
        const fl = coFouilleFlags(p, [
            { key: 'bouteille', test: /bouteille/i }, { key: 'stup', test: /stupéfiant/i },
        ]);

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🍺 PV — IVRESSE PUBLIQUE MANIFESTE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Lieu : ${f.address}
👤 VIGILE / REQUÉRANT
Nom / Prénom : __________________________
📝 DÉCLARATION DU REQUÉRANT
Le requérant nous indique :
« ____________________________________________________
____________________________________________________ »
👤 PERSONNE CONTRÔLÉE
Nom / Prénom : __________________________
${coWantedLine(p)}
${coWoundedLine(p)}
📝 CONSTATATIONS
État constaté :

🧴 FOUILLE
${fl.rien ? '☒' : '☐'} Rien
${fl.bouteille ? '☒' : '☐'} Bouteille
${fl.stup ? '☒' : '☐'} Stupéfiants
${fl.autre ? '☒' : '☐'} Autre : ${fl.autreText}
🍺 ALCOOTEST
Résultat : ${p.breathalyzer || '__________________________'}
💊 DÉPISTAGE STUPÉFIANTS
Résultat : ${p.drugTest || '__________________________'}
🗣️ VERSION DES FAITS DE L'INDIVIDU


📌 SUITE
${o.dispersed ? '☒' : '☐'} Laissée libre
${o.caught ? '☒' : '☐'} Menottée / interpellée
Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'personne_errante') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const wanderer = people.find((p) => p.role === 'wanderer') || {};
        const identified = !!(wanderer.firstname || wanderer.lastname);
        // p.state passe à 'delivered' une fois déposée à l'hôpital — c'est
        // à ce moment précis que l'établissement en prend la charge.
        const delivered = wanderer.outcome === 'delivered';
        const familyNotified = !!wanderer.familyContactNotified;

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚶 PV — PERSONNE ERRANTE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Lieu : ${f.address}
👤 REQUÉRANT
Nom / Prénom : __________________________
📝 CIRCONSTANCES
Le requérant nous indique :
« ____________________________________________________
____________________________________________________ »
👤 PERSONNE PRISE EN CHARGE
Nom / Prénom : __________________________
🔎 PRISE EN CHARGE
La personne a été :
${identified ? '☒' : '☐'} Identifiée
${delivered ? '☒' : '☐'} Transportée à l'hôpital
${delivered ? '☒' : '☐'} Prise en charge par l'établissement
👨‍👩‍👦 FAMILLE
Famille prévenue :
${familyNotified ? '☒' : '☐'} Oui
${familyNotified ? '☐' : '☒'} Non
Nom du proche : __________________________
Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'racolage') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const suspects = people.filter((p) => p.role === 'suspect');

        // Fouille/suite/récidive-recherche déduites des vraies données —
        // seuls le nom et la version des faits restent à saisir.
        const personBlock = (p) => {
            const seized  = (p && Array.isArray(p.seized)) ? p.seized : [];
            const has     = (re) => seized.some((s) => re.test(s));
            const argent  = has(/argent/i);
            const preserv = has(/préservatif/i);
            const stup    = has(/stupéfiant/i);
            const autres  = seized.filter((s) => !/argent|préservatif|stupéfiant/i.test(s));
            const libre   = !!p && p.outcome === 'dispersed';
            const menotte = !!p && (p.outcome === 'cuffed' || p.outcome === 'delivered');
            const wanted  = !!p && !!p.wanted;
            return {
                repeat: (p && p.repeatOffender) ? '☒' : '☐',
                wanted: wanted ? '☒' : '☐',
                wantedReason: wanted ? (p.wantedReason || 'motif non précisé') : '__________________________',
                rien: (!seized.length) ? '☒' : '☐',
                argent: argent ? '☒' : '☐',
                preserv: preserv ? '☒' : '☐',
                stup: stup ? '☒' : '☐',
                autre: autres.length ? '☒' : '☐',
                autreText: autres.length ? autres.join(', ') : '__________________________',
                libre: libre ? '☒' : '☐',
                menotte: menotte ? '☒' : '☐',
            };
        };
        // Autant de blocs « PERSONNE » que de suspects réels (jusqu'à 3),
        // au lieu d'un 3e bloc générique jamais relié aux vraies données.
        const personBlocks = suspects.map((p, i) => {
            const pb = personBlock(p);
            return `👤 PERSONNE N°${i + 1}
Nom / Prénom : __________________________
${pb.repeat} Récidiviste   ${pb.wanted} Fiche de recherche : ${pb.wantedReason}
Version des faits :

Fouille :
${pb.rien} Rien
${pb.argent} Argent
${pb.preserv} Préservatifs
${pb.stup} Stupéfiants
${pb.autre} Autre : ${pb.autreText}
Suite :
${pb.libre} Laissée libre
${pb.menotte} Menottée / interpellée`;
        }).join('\n');

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💃 PV — RACOLAGE SUR LA VOIE PUBLIQUE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Lieu : ${f.address}
👤 REQUÉRANT
Nom / Prénom : __________________________
📝 CIRCONSTANCES
Le requérant nous indique :
« ____________________________________________________
____________________________________________________ »
${personBlocks}
Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'rixe_soiree') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const suspects = people.filter((p) => p.role === 'suspect');
        const count = suspects.length;

        // Autant de blocs « PERSONNE » que de protagonistes réels de la
        // rixe (5 à 8 selon le tirage) — plus de plafond à deux avec un
        // renvoi générique pour le reste.
        const personBlocks = suspects.map((p, i) => {
            const fl = coFouilleFlags(p, []);
            const o  = coOutcomeFlags(p);
            return `👤 PERSONNE N°${i + 1}
Nom / Prénom : __________________________
${coWantedLine(p)}
Version des faits :

Fouille :
${fl.rien ? '☒' : '☐'} Rien
${fl.autre ? '☒' : '☐'} Autre : ${fl.autreText}
Suite :
${o.dispersed ? '☒' : '☐'} Laissé libre
${o.caught ? '☒' : '☐'} Menotté / interpellé`;
        }).join('\n');

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🥊 PV — RIXE EN SOIRÉE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Lieu : ${f.address}
👥 NOMBRE DE PERSONNES
${count === 5 ? '☒' : '☐'} 5 ${count === 6 ? '☒' : '☐'} 6 ${count === 7 ? '☒' : '☐'} 7 ${count >= 8 ? '☒' : '☐'} 8
📝 DÉROULEMENT


${personBlocks}
Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'rodeo_urbain') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const suspects = people.filter((p) => p.role === 'suspect');

        // Autant de blocs « VÉHICULE »/« PERSONNE » que de motards réels (2 à 5).
        const vehicleBlocks = suspects.map((p, i) => {
            const foves = p.fovesChecked
                ? (p.bikeStolen ? '☒ Signalée volée' : '☒ Non signalée')
                : '☐ Non vérifiée';
            return `🏍️ VÉHICULE N°${i + 1}
Marque / modèle : ${p.bikeModel || '__________________________'}
Plaque : ${p.plateMissing ? 'Absente' : (p.bikePlate || '__________________________')}
${p.helmetMissing ? '☒' : '☐'} Conducteur sans casque
FOVES : ${foves}
${p.bikeImpounded ? '☒' : '☐'} Mise en fourrière`;
        }).join('\n');

        const personBlocks = suspects.map((p, i) => {
            const o = coOutcomeFlags(p);
            return `👤 PERSONNE N°${i + 1} (véhicule N°${i + 1})
Nom / Prénom : __________________________
${coWantedLine(p)}
${coWoundedLine(p)}
Version des faits :

Suite :
${o.escaped ? '☒' : '☐'} En fuite
${o.caught ? '☒' : '☐'} Interpellé(e)`;
        }).join('\n');

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏍️ PV — RODÉO URBAIN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Lieu : ${f.address}

${vehicleBlocks}

${personBlocks}
Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'tapage') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const suspects = people.filter((p) => p.role === 'suspect');
        const p1 = suspects[0];
        // objective='radio' : la mission n'aboutit qu'une fois la musique
        // coupée (objectiveDone) — fiable comme proxy.
        const musicOff = row.status === 'success';
        const anyCaught = suspects.some((p) => p.outcome === 'cuffed' || p.outcome === 'delivered');

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔊 PV — TAPAGE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Lieu : ${f.address}
👥 PERSONNES PRÉSENTES
Nombre : ${suspects.length || '______'}
📝 CONSTATATIONS
Les personnes étaient regroupées autour d'un véhicule diffusant de la musique.
Origine du tapage :

🔎 CONTRÔLES
Personnes identifiées :

${coWantedLine(p1)}
Fouille / constatations particulières :

📢 FIN DE L'INTERVENTION
La musique a été coupée :
${musicOff ? '☒' : '☐'} Oui
${musicOff ? '☐' : '☒'} Non
Le tapage a cessé :
${musicOff ? '☒' : '☐'} Oui
${musicOff ? '☐' : '☒'} Non
Suite donnée :
${anyCaught ? '☐' : '☒'} Personnes laissées libres
${anyCaught ? '☒' : '☐'} Une ou plusieurs personnes interpellées
☐ Autre : __________________________
Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'trafic_stup') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const suspects = people.filter((p) => p.role === 'suspect');
        const [p1, p2] = suspects;
        const fled = suspects.some((p) => coBehaviorGuess(p) === 'flee');

        const dealFouille = (p) => {
            const seized = (p && Array.isArray(p.seized)) ? p.seized : [];
            const stup   = seized.some((s) => /stupéfiant/i.test(s));
            const argent = seized.some((s) => /billets|argent/i.test(s));
            return {
                stupOnly: stup && !argent, argentOnly: argent && !stup,
                both: stup && argent, rien: seized.length === 0,
            };
        };
        const fl1 = dealFouille(p1), fl2 = dealFouille(p2);
        const o1 = coOutcomeFlags(p1), o2 = coOutcomeFlags(p2);

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💊 PV — TRAFIC DE STUPÉFIANTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Lieu : ${f.address}
📝 CIRCONSTANCES
À notre arrivée :
${fled ? '☒' : '☐'} Les suspects prennent la fuite
${fled ? '☐' : '☒'} Les suspects restent sur place
👤 SUSPECT N°1
Nom / Prénom : __________________________
${coWantedLine(p1)}
Fouille :
${fl1.stupOnly ? '☒' : '☐'} Stupéfiants
${fl1.argentOnly ? '☒' : '☐'} Liasse de billets
${fl1.both ? '☒' : '☐'} Stupéfiants + argent
${fl1.rien ? '☒' : '☐'} Rien
☐ Autre : __________________________
Suite : ${o1.caught ? '☒' : '☐'} Menotté ☐ Autre : __________
👤 SUSPECT N°2
Nom / Prénom : __________________________
${coWantedLine(p2)}
Fouille :
${fl2.stupOnly ? '☒' : '☐'} Stupéfiants
${fl2.argentOnly ? '☒' : '☐'} Liasse de billets
${fl2.both ? '☒' : '☐'} Stupéfiants + argent
${fl2.rien ? '☒' : '☐'} Rien
☐ Autre : __________________________
Suite : ${o2.caught ? '☒' : '☐'} Menotté ☐ Autre : __________
Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'tuerie_masse') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const suspect = people.find((p) => p.role === 'suspect');
        const deceased = people.filter((p) => p.role === 'deceased');
        const wounded  = people.filter((p) => p.role === 'victim');
        const identified = !!(suspect && (suspect.firstname || suspect.lastname));
        const weapon = (suspect && suspect.weapon) || '';
        const isAssault = /assaut/i.test(weapon);
        const isSMG = /^mitraillette$/i.test(weapon);
        const isMini = /mini-mitraillette/i.test(weapon);
        const behavior = suspect ? coBehaviorGuess(suspect) : null;
        const success = row.status === 'success';

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴 PV — TUERIE DE MASSE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT RÉDACTEUR
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Lieu : ${f.address}
⚠️ NATURE DE L'INTERVENTION
${suspect ? '☒' : '☐'} Suspect présent
${(suspect && suspect.outcome === 'escaped') ? '☒' : '☐'} Suspect en fuite
Suspect retranché : __________________________
${(suspect && suspect.outcome === 'dead') ? '☒' : '☐'} Suspect neutralisé
${suspect ? '☐' : '☒'} Informations incomplètes
📝 DÉROULEMENT DES FAITS




🔫 SUSPECT
Nom / Prénom : __________________________
${coWantedLine(suspect)}
Situation :
${(suspect && (suspect.outcome === 'cuffed' || suspect.outcome === 'delivered')) ? '☒' : '☐'} Interpellé
${(suspect && suspect.outcome === 'dead') ? '☒' : '☐'} Neutralisé
${(suspect && suspect.outcome === 'escaped') ? '☒' : '☐'} En fuite
${(suspect && suspect.outcome === 'dead') ? '☒' : '☐'} Décédé
${identified ? '☐' : '☒'} Non identifié
Si blessé mais vivant — soigné(e) : ${(suspect && suspect.wounded && suspect.healed) ? '☒' : '☐'} Oui ${(suspect && suspect.wounded && !suspect.healed) ? '☒' : '☐'} Non
Arme :
${isSMG ? '☒' : '☐'} SMG
${isAssault ? '☒' : '☐'} Fusil d'assaut
${isMini ? '☒' : '☐'} Mitraillette
${(weapon && !isSMG && !isAssault && !isMini) ? '☒' : '☐'} Autre : ${(weapon && !isSMG && !isAssault && !isMini) ? weapon : '__________________________'}
Comportement :
${behavior === 'flee' ? '☒' : '☐'} Fuite
${behavior === 'aggressive' ? '☒' : '☐'} Agressif
Fouille :

👥 BLESSÉS / DCD
Nombre de victimes décédées : ${deceased.length || '______'}
Nombre de victimes blessées : ${wounded.length || '______'}
🚨 FIN DE L'INTERVENTION
Situation du suspect réglée :
${(suspect && (suspect.outcome === 'cuffed' || suspect.outcome === 'delivered')) ? '☒' : '☐'} Interpellé
${(suspect && suspect.outcome === 'dead') ? '☒' : '☐'} Neutralisé
${(suspect && suspect.outcome === 'escaped') ? '☒' : '☐'} Fuite constatée
☐ Autre : __________________________
Corps constatés / pris en charge :
${success ? '☒' : '☐'} Oui
${success ? '☐' : '☒'} Non
📌 OBSERVATIONS COMPLÉMENTAIRES


Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'vol_arrache') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const suspects = people.filter((p) => p.role === 'suspect');
        const p1 = suspects[0], p2 = suspects[1];
        const success = row.status === 'success';
        const o1 = coOutcomeFlags(p1), o2 = coOutcomeFlags(p2);
        const fl1 = coFouilleFlags(p1, [
            { key: 'sac', test: /sac à main/i }, { key: 'tel', test: /téléphone/i },
        ]);

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👜 PV — VOL À L'ARRACHÉ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Lieu : ${f.address}
👤 REQUÉRANT
Nom / Prénom : __________________________
📝 DÉCLARATION DU REQUÉRANT
Le requérant nous indique :
« ____________________________________________________
____________________________________________________ »
👤 VICTIME
Nom / Prénom : __________________________
📝 DÉCLARATION DE LA VICTIME


🚑 PREMIERS SOINS
${success ? '☒' : '☐'} Oui
${success ? '☐' : '☒'} Non
👤 SUSPECT N°1
Nom / Prénom : __________________________
${coWantedLine(p1)}
${coWoundedLine(p1)}
${o1.escaped ? '☒' : '☐'} A fui
${o1.dead ? '☒' : '☐'} A attaqué l'agent
${o1.caught ? '☒' : '☐'} Maîtrisé sur place
Fouille :
${fl1.rien ? '☒' : '☐'} Rien
${fl1.sac ? '☒' : '☐'} Sac à main volé
${fl1.tel ? '☒' : '☐'} Téléphone volé
${fl1.autre ? '☒' : '☐'} Autre : ${fl1.autreText}
Suite :
${o1.dispersed ? '☒' : '☐'} Laissé libre
${o1.caught ? '☒' : '☐'} Emmené au commissariat
👤 SUSPECT N°2 — SI NÉCESSAIRE
Nom / Prénom : __________________________
${coWantedLine(p2)}
${coWoundedLine(p2)}
Fouille / éléments retrouvés :

Suite : ${o2.dispersed ? '☒' : '☐'} Libre ${o2.caught ? '☒' : '☐'} Commissariat
Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'vol_etalage') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const suspects = people.filter((p) => p.role === 'suspect');
        const p1 = suspects[0], p2 = suspects[1];
        const o1 = coOutcomeFlags(p1), o2 = coOutcomeFlags(p2);
        const fl1 = coFouilleFlags(p1, [
            { key: 'marchandise', test: /marchandise|vêtement|jeu vidéo|cigarette/i },
            { key: 'bouteille', test: /bouteille/i },
        ]);
        const payOff = (p, o) => ({
            non: !(p && p.payOffAsked),
            accepte: !!(p && p.payOffAsked) && o.dispersed,
            refuse: !!(p && p.payOffAsked) && !o.dispersed,
        });
        const po1 = payOff(p1, o1), po2 = payOff(p2, o2);

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🛒 PV — VOL À L'ÉTALAGE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Commerce : ${f.address}
👤 VIGILE / REQUÉRANT
Nom / Prénom : __________________________
📝 CIRCONSTANCES
Le vigile nous indique :
« ____________________________________________________
____________________________________________________ »
👤 SUSPECT N°1
Nom / Prénom : __________________________
${coWantedLine(p1)}
Fouille :
${fl1.rien ? '☒' : '☐'} Rien
${fl1.marchandise ? '☒' : '☐'} Marchandise
${fl1.bouteille ? '☒' : '☐'} Bouteille
${fl1.autre ? '☒' : '☐'} Autre : ${fl1.autreText}
Déclaration :

💰 PROPOSITION DE PAYER LES ARTICLES
${po1.non ? '☒' : '☐'} Non proposé
${po1.accepte ? '☒' : '☐'} Proposé — a accepté (relâché)
${po1.refuse ? '☒' : '☐'} Proposé — a refusé
Suite :
${o1.dispersed ? '☒' : '☐'} Laissé libre
${o1.caught ? '☒' : '☐'} Menotté / interpellé
👤 SUSPECT N°2 — SI NÉCESSAIRE
Nom / Prénom : __________________________
${coWantedLine(p2)}
Fouille :

Déclaration :

💰 Proposition de payer : ${po2.non ? '☒' : '☐'} Non proposé ${po2.accepte ? '☒' : '☐'} Accepté ${po2.refuse ? '☒' : '☐'} Refusé
Suite :
${o2.dispersed ? '☒' : '☐'} Laissé libre
${o2.caught ? '☒' : '☐'} Menotté / interpellé
Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    if (row.scenario_id === 'vol_vehicule') {
        const f = coReportAgentFields(row);
        let people = [];
        try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }
        const suspects = people.filter((p) => p.role === 'suspect');
        const p1 = suspects[0], p2 = suspects[1];
        const o1 = coOutcomeFlags(p1), o2 = coOutcomeFlags(p2);
        const anyEscaped = suspects.some((p) => p.outcome === 'escaped');
        const anyCaught  = suspects.some((p) => p.outcome === 'cuffed' || p.outcome === 'delivered');
        const fl1 = coFouilleFlags(p1, [
            { key: 'tournevis', test: /tournevis/i }, { key: 'decodeur', test: /décodeur/i },
            { key: 'couteau', test: /couteau/i },
        ]);

        return `━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚗 PV — VOL DE VÉHICULE EN COURS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👮 AGENT
Nom / Prénom : ${f.officerName}
Matricule : ${f.matricule}
Grade : ${f.gradeLabel}
Unité : ${f.unit}
📅 Date : ${f.dateStr}
🕐 Heure : ${f.timeStr}
📍 Lieu : ${f.address}
👤 REQUÉRANT
Nom / Prénom : __________________________
📝 DÉCLARATION DU REQUÉRANT
Le requérant nous indique :
« ____________________________________________________
____________________________________________________ »
🚗 VÉHICULE VISÉ
Marque / modèle : ${row.target_vehicle_model || '__________________________'}
Plaque : ${row.target_vehicle_plate || '__________________________'}
📝 CIRCONSTANCES
À notre arrivée, le ou les individus prennent la fuite à pied.
${anyEscaped ? '☒' : '☐'} Fuite constatée
${anyCaught ? '☒' : '☐'} Individu(s) rattrapé(s)
👤 SUSPECT N°1
Nom / Prénom : __________________________
${coWantedLine(p1)}
${coWoundedLine(p1)}
🔎 Fouille :
${fl1.rien ? '☒' : '☐'} Rien
${fl1.tournevis ? '☒' : '☐'} Tournevis
${fl1.decodeur ? '☒' : '☐'} Décodeur de clé
${fl1.couteau ? '☒' : '☐'} Couteau
${fl1.autre ? '☒' : '☐'} Autre : ${fl1.autreText}
${o1.caught ? '☒' : '☐'} Menotté
👤 SUSPECT N°2 — SI NÉCESSAIRE
Nom / Prénom : __________________________
${coWantedLine(p2)}
${coWoundedLine(p2)}
Fouille : __________________________________________
${o2.caught ? '☒' : '☐'} Menotté
Signature des agents : __________________________
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    }

    return '';
}

const CO_ROLE = {
    suspect:  'Mis en cause',
    caller:   'Requérant(e)',
    victim:   'Victime',
    deceased: 'Personne décédée',
    wanderer: 'Personne assistée',
    animal:   'Animal',
};

/* ── Détail dépliable d'une intervention ───────────────────────── */

/* Contenu du rapport, affiché dans sa propre fenêtre (cf. co-report-view-btn)
   plutôt qu'en ligne dans la fiche d'intervention — plus pratique à lire. */
function coReportModalBody(row) {
    if (!row.report) return '';
    const sig = [row.report_by, row.report_at ? fmtDate(row.report_at) : null]
        .filter(Boolean).join(' · ');
    const closure = Number(row.closed) === 1
        ? `<div class="co-report-closure">Affaire classée par ${esc(row.closed_by || '—')}${
              row.closed_at ? ` le ${esc(fmtDate(row.closed_at))}` : ''}</div>`
        : '';
    return `
        <div class="co-report">
            ${sig ? `<div class="co-report-sig">${esc(sig)}</div>` : ''}
            <div class="co-report-body">${esc(row.report)}</div>
            ${closure}
        </div>`;
}

/* Boutons du dossier. Le classement n'apparaît que pour le commissaire,
   et seulement sur un dossier non classé disposant d'un rapport. */
function coActionBar(row, canManage) {
    const closed = Number(row.closed) === 1;
    const btns = [];

    if (row.report) {
        btns.push(`<button class="mdt-btn co-report-view-btn" data-view-report="${
            esc(row.id)}">Voir le rapport</button>`);
    }

    if (!closed) {
        btns.push(`<button class="mdt-btn co-report-btn" data-report="${esc(row.id)}">${
            row.report ? 'Modifier le rapport' : 'Rédiger le rapport'}</button>`);
    }

    if (canManage && !closed) {
        btns.push(`<button class="mdt-btn mdt-btn-primary co-close-btn" data-close="${
            esc(row.id)}" ${row.report ? '' : 'disabled title="Aucun rapport rédigé"'}>${
            'Classer l\'affaire'}</button>`);
    }

    if (!btns.length) return '';
    return `<div class="co-actions">${btns.join('')}</div>`;
}

function coDetail(row, canManage) {
    let people = [];
    try { people = JSON.parse(row.suspects_json || '[]') || []; } catch (e) { people = []; }

    /* Les saisies sont déjà des désignations lisibles côté serveur :
       armes traduites via C.WeaponLabels, objets nommés par le scénario. */
    const seizedCell = (p) => {
        if (!Array.isArray(p.seized) || p.seized.length === 0) return '—';
        return p.seized.map((it) => esc(it)).join('<br>');
    };

    /* Avec plusieurs agents engagés, le dossier doit dire QUI a fait
       feu, et sur quel motif la bavure a été retenue. */
    const outcomeCell = (p) => {
        let html = coOutcome(p.outcome, p.role);
        if (p.killedBy) {
            html += `<div class="co-killed-by">par ${esc(p.killedBy)}</div>`;
        }
        if (p.releasedBy) {
            html += `<div class="co-killed-by">par ${esc(p.releasedBy)}</div>`;
        }
        if (p.killReason) {
            html += `<div class="co-kill-reason">${esc(p.killReason)}</div>`;
        }
        return html;
    };

    /* Déposition recueillie sur place auprès du mis en cause.
       L'attitude qualifie la valeur de la déclaration : un individu qui
       nie n'a pas dit la même chose qu'un individu qui avoue. */
    const STANCE = {
        nie:      'conteste les faits',
        justifie: 'reconnaît mais se justifie',
        provoque: 'attitude de défi',
        avoue:    'reconnaît les faits',
        silence:  'refuse de répondre',
    };

    const declarationRow = (p) => {
        if (!p.declaration) return '';
        const st = STANCE[p.stance];
        return `<tr class="co-declaration">
            <td colspan="5">« ${esc(p.declaration)} » — ${esc(coPersonName(p))}${
                st ? ` <span class="co-stance">(${esc(st)})</span>` : ''}</td>
        </tr>`;
    };

    /* IPM : taux d'alcoolémie relevé à l'alcootest, consigné pour appuyer
       le rapport. Découverte de corps / personne errante : cause du décès
       et proche à prévenir — un bouton déclenche l'itinéraire côté agent
       tant que ce n'est pas fait (cf. mdtco:familyRoute, police/client). */
    const infoRow = (p) => {
        const bits = [];
        if (p.breathalyzer) bits.push(`Alcootest : ${esc(p.breathalyzer)}`);
        if (p.drugTest) bits.push(`Dépistage stupéfiants : ${esc(p.drugTest)}`);
        if (p.causeOfDeath) bits.push(`Cause du décès : ${esc(p.causeOfDeath)}`);
        if (p.wanted) {
            bits.push(`Fiche de recherche : ${esc(p.wantedReason || 'motif non précisé')}`);
        }
        if (p.releasedWhileWanted) {
            bits.push('<span class="mdt-text-red">Relâché(e) malgré une fiche de recherche active</span>');
        }
        if (p.wounded) {
            bits.push(p.healed
                ? 'Blessé(e) par balle — soigné(e)'
                : '<span class="mdt-text-red">Blessé(e) par balle — non soigné(e)</span>');
        }
        if (p.woundDescription) {
            bits.push(`Constatation médicale : ${esc(p.woundDescription)}`);
        }
        if (p.familyContact) {
            const status = p.familyContactNotified
                ? '<span class="mdt-badge mdt-badge-green">prévenu</span>'
                : `<button class="mdt-btn mdt-btn-primary co-family-btn" ` +
                  `data-callout="${esc(row.id)}">À prévenir</button>`;
            bits.push(`Proche à prévenir : ${esc(p.familyContact)} ${status}`);
        }
        if (!bits.length) return '';
        return `<tr class="co-declaration"><td colspan="5">${bits.join(' — ')}</td></tr>`;
    };

    /* Badges de contrôle d'identité — récidive (informatif) et fiche de
       recherche active (à justifier si l'individu est relâché malgré ça). */
    const nameCell = (p) => {
        let html = esc(coPersonName(p));
        if (p.repeatOffender) html += ' <span class="mdt-badge mdt-badge-blue">récidiviste</span>';
        if (p.wanted) html += ' <span class="mdt-badge mdt-badge-red">recherché</span>';
        return html;
    };

    const rows = people.map((p) => `
        <tr>
            <td>${nameCell(p)}</td>
            <td>${esc(CO_ROLE[p.role] || p.role || '—')}</td>
            <td>${p.weapon ? esc(p.weapon) : '—'}</td>
            <td>${seizedCell(p)}</td>
            <td>${outcomeCell(p)}</td>
        </tr>${declarationRow(p)}${infoRow(p)}`).join('');

    const bav = parseInt(row.misconducts, 10) || 0;

    return `
        <div class="mdt-detail">
            ${bav > 0 ? `<div class="mdt-detail-row mdt-text-red"><b>Saisine IGPN :</b>
                ${bav > 1 ? `${bav} bavures constatées` : 'bavure constatée'}
                durant l'intervention.</div>` : ''}
            <div class="mdt-detail-row"><b>Agents engagés :</b> ${esc(row.agents || '—')}</div>
            <div class="mdt-detail-row"><b>Coordonnées :</b> ${esc(row.coords || '—')}</div>
            <div class="mdt-detail-row"><b>Temps de réponse :</b> ${coDuration(row.response_time)}</div>
            ${row.vehicle_model || row.vehicle_plate ? `<div class="mdt-detail-row"><b>Véhicule :</b> ${
                esc(row.vehicle_model || '—')}${row.vehicle_plate ? ` — ${esc(row.vehicle_plate)}` : ''}</div>` : ''}
            ${row.statement ? `<div class="mdt-detail-row"><b>Déposition du requérant :</b> « ${esc(row.statement)} »</div>` : ''}
            ${row.examine_notes ? `<div class="mdt-detail-row"><b>Constatations :</b> ${esc(row.examine_notes)}</div>` : ''}
            ${coActionBar(row, canManage)}
            ${people.length ? `
            <table class="mdt-table">
                <thead><tr><th>Individu</th><th>Qualité</th><th>Arme portée</th><th>Saisies</th><th>Suite</th></tr></thead>
                <tbody>${rows}</tbody>
            </table>` : `<div class="mdt-detail-row"><i>Aucun individu recensé.</i></div>`}
        </div>`;
}

/* ── Rendu principal ───────────────────────────────────────────── */

async function renderInterventions() {
    setContent(`
        <div class="mdt-page-title">Appel 17</div>
        <div class="mdt-page-sub">Historique des appels 17 et statistiques par agent.</div>
        <div id="co-summary"></div>
        <div class="mdt-searchbar">
            <button class="mdt-btn mdt-btn-primary" id="co-tab-history">📁 Historique</button>
            <button class="mdt-btn" id="co-tab-stats">📊 Statistiques</button>
            <button class="mdt-btn" id="co-tab-reg">🎯 Inscription</button>
            ${has('view_cic') ? `<button class="mdt-btn" id="co-tab-cic">🚨 TN 97</button>` : ''}
        </div>
        <div id="co-body">${emptyState('⏳', 'Chargement…')}</div>
    `);

    /* Bandeau de synthèse — 30 derniers jours */
    const sum = await fetchNui('mdtco:getSummary', {});
    const s = (sum && typeof sum === 'object' && !Array.isArray(sum)) ? sum : {};
    const total = parseInt(s.total, 10) || 0;
    const succ = parseInt(s.successes, 10) || 0;
    const rate = total > 0 ? Math.round((succ / total) * 100) : 0;
    const avg = s.avg_response ? coDuration(Math.round(s.avg_response)) : '—';

    const sumEl = el('co-summary');
    if (sumEl) {
        sumEl.innerHTML = `
            <div class="mdt-stats-row">
                <div class="mdt-stat"><div class="mdt-stat-val">${total}</div>
                     <div class="mdt-stat-lbl">Interventions (30 j)</div></div>
                <div class="mdt-stat"><div class="mdt-stat-val">${rate} %</div>
                     <div class="mdt-stat-lbl">Taux de réussite</div></div>
                <div class="mdt-stat"><div class="mdt-stat-val">${avg}</div>
                     <div class="mdt-stat-lbl">Temps de réponse moyen</div></div>
            </div>`;
    }

    const coSetTab = (activeId) => {
        ['co-tab-history', 'co-tab-stats', 'co-tab-reg', 'co-tab-cic'].forEach((id) => {
            if (el(id)) el(id).className = id === activeId ? 'mdt-btn mdt-btn-primary' : 'mdt-btn';
        });
        if (activeId !== 'co-tab-cic') coStopCicPolling();
    };

    b('co-tab-history', () => { coSetTab('co-tab-history'); coRenderHistory(); });
    b('co-tab-stats',   () => { coSetTab('co-tab-stats');   coRenderStats(); });
    b('co-tab-reg',     () => { coSetTab('co-tab-reg');     coRenderRegistration(); });
    b('co-tab-cic',     () => { coSetTab('co-tab-cic');     coRenderCic(); });

    coRenderHistory();
}

/* ── Historique ────────────────────────────────────────────────── */

async function coRenderHistory() {
    const box = el('co-body');
    if (!box) return;
    box.innerHTML = emptyState('⏳', 'Chargement de l\'historique…');

    const res = await fetchNui('mdtco:getHistory', { page: coState.page });
    if (!el('co-body')) return;

    const payload = (res && typeof res === 'object' && !Array.isArray(res)) ? res : {};
    const rows = asArray(payload.rows);
    const hasMore = !!payload.hasMore;
    const canManage = !!payload.canManage;

    /* Page vide alors qu'on n'est pas à la première : on recule au lieu
       de laisser l'écran bloqué sans pagination. */
    if (!rows.length && coState.page > 1) {
        coState.page -= 1;
        return coRenderHistory();
    }

    const pager = `
        <div class="mdt-searchbar" style="margin-top:12px">
            <button class="mdt-btn" id="co-prev" ${coState.page <= 1 ? 'disabled' : ''}>← Précédent</button>
            <span class="mdt-page-ind">Page ${coState.page}</span>
            <button class="mdt-btn" id="co-next" ${hasMore ? '' : 'disabled'}>Suivant →</button>
            ${canManage ? `<button class="mdt-btn mdt-btn-danger" id="co-reset">🗑 Réinitialiser les compteurs</button>` : ''}
        </div>`;

    if (!rows.length) {
        el('co-body').innerHTML = emptyState('📭', 'Aucune intervention enregistrée.') + pager;
        coBindPager(hasMore, canManage);
        return;
    }

    const html = rows.map((r) => {
        const opened = !!coState.open[r.id];
        return `
        <div class="mdt-list-item co-row" data-id="${esc(r.id)}">
            <div class="mdt-li-main">
                <div class="mdt-li-name">
                    ${esc(r.label || r.scenario_id)}${depBadge(r.department)}
                    ${Number(r.false_alarm) === 1 ? '<span class="mdt-badge mdt-badge-gray">Fausse alerte</span>' : ''}
                </div>
                <div class="mdt-li-sub">
                    ${esc(fmtDate(r.started_at))} · ${esc(r.zone || '—')} ·
                    ${esc(r.suspects_delivered || 0)} interpellé(s),
                    ${esc(r.suspects_killed || 0)} neutralisé(s),
                    ${esc(r.suspects_escaped || 0)} en fuite
                </div>
            </div>
            ${coStatus(r.status, r.misconducts, r.closed)}
            ${canManage ? `<button class="mdt-btn mdt-btn-danger co-del" data-del="${esc(r.id)}" title="Supprimer">✕</button>` : ''}
        </div>
        <div class="co-detail-wrap" data-detail="${esc(r.id)}" ${opened ? '' : 'style="display:none"'}>
            ${coDetail(r, canManage)}
        </div>`;
    }).join('');

    el('co-body').innerHTML = `<div class="mdt-list">${html}</div>` + pager;

    document.querySelectorAll('#co-body .co-row').forEach((it) => {
        it.addEventListener('click', (ev) => {
            if (ev.target.closest('.co-del')) return;   // le ✕ ne déplie pas
            const id = it.dataset.id;
            const d = document.querySelector(`[data-detail="${id}"]`);
            if (!d) return;
            const show = d.style.display === 'none';
            d.style.display = show ? '' : 'none';
            coState.open[id] = show;
        });
    });

    document.querySelectorAll('#co-body .co-del').forEach((btn) => {
        btn.addEventListener('click', (ev) => {
            ev.stopPropagation();
            const id = btn.dataset.del;
            confirmAction(
                'Supprimer définitivement cette intervention ? Les statistiques des agents associées seront également retirées.',
                async () => {
                    await fetchNui('mdtco:deleteCallout', { id: Number(id) });
                    delete coState.open[id];
                    coRenderHistory();
                });
        });
    });

    /* Affichage à la demande du rapport, dans sa propre fenêtre — plus
       pratique à lire que replié dans la fiche d'intervention. */
    document.querySelectorAll('#co-body .co-report-view-btn').forEach((btn) => {
        btn.addEventListener('click', (ev) => {
            ev.stopPropagation();
            const id  = btn.dataset.viewReport;
            const row = rows.find((r) => String(r.id) === String(id)) || {};
            openModal('Rapport d\'intervention', coReportModalBody(row),
                `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Fermer</button>`);
        });
    });

    /* Rédaction du rapport : ouvert à tout agent ayant accès à l'onglet.
       Le clic ne doit pas replier le dossier, d'où le stopPropagation. */
    document.querySelectorAll('#co-body .co-report-btn').forEach((btn) => {
        btn.addEventListener('click', (ev) => {
            ev.stopPropagation();
            const id  = btn.dataset.report;
            const row = rows.find((r) => String(r.id) === String(id)) || {};
            const prefill = row.report || coReportTemplate(row);
            openModal('Rapport d\'intervention', `
                <div class="mdt-form-row">
                    <label>Compte rendu des faits, constatations et suites données</label>
                    <textarea id="co-report-text" class="mdt-textarea" rows="24"
                        placeholder="Rédigez le rapport…">${esc(prefill)}</textarea>
                </div>`,
                `<button class="mdt-btn" onclick="window.__mdtCloseModal()">Annuler</button>
                 <button class="mdt-btn mdt-btn-primary" id="co-report-save">Enregistrer</button>`);
            el('mdt-modal').classList.add('mdt-modal-lg');

            const save = el('co-report-save');
            if (!save) return;
            save.addEventListener('click', async () => {
                const text = (el('co-report-text') || {}).value || '';
                const res = await fetchNui('mdtco:saveReport',
                    { id: Number(id), text: text });
                if (res && res.ok === false) {
                    alertBox(res.reason || 'Enregistrement impossible.');
                    return;
                }
                window.__mdtCloseModal();
                coState.open[id] = true;   // le dossier reste déplié
                coRenderHistory();
            });
        });
    });

    /* Itinéraire vers le proche à prévenir : géré côté agent (client
       Lua, resource police) — le NUI n'attend qu'un ok/msg en retour. */
    document.querySelectorAll('#co-body .co-family-btn').forEach((btn) => {
        btn.addEventListener('click', async (ev) => {
            ev.stopPropagation();
            const id = Number(btn.dataset.callout);
            const res = await fetchNui('mdtco:familyRoute', { calloutId: id });
            if (res && res.ok === false) {
                toast(res.msg || 'Itinéraire indisponible.', false);
                return;
            }
            toast('Itinéraire transmis.', true);
        });
    });

    /* Classement de l'affaire : commissaire uniquement, rapport exigé. */
    document.querySelectorAll('#co-body .co-close-btn').forEach((btn) => {
        btn.addEventListener('click', (ev) => {
            ev.stopPropagation();
            if (btn.hasAttribute('disabled')) return;
            const id = btn.dataset.close;
            confirmAction(
                'Classer définitivement cette affaire ? Le rapport ne pourra plus être modifié.',
                async () => {
                    const res = await fetchNui('mdtco:closeCase', { id: Number(id) });
                    if (res && res.ok === false) {
                        alertBox(res.reason || 'Classement impossible.');
                        return;
                    }
                    coState.open[id] = true;
                    coRenderHistory();
                });
        });
    });

    coBindPager(hasMore, canManage);
}

function coBindPager(hasMore, canManage) {
    b('co-prev', () => {
        if (coState.page > 1) { coState.page -= 1; coRenderHistory(); }
    });
    b('co-next', () => {
        if (hasMore) { coState.page += 1; coRenderHistory(); }
    });
    if (canManage) {
        b('co-reset', () => {
            confirmAction(
                'Réinitialiser tous les compteurs ? Tout l\'historique des interventions et toutes les statistiques par agent seront effacés. Action irréversible.',
                async () => {
                    await fetchNui('mdtco:resetStats', {});
                    coState.page = 1;
                    coState.open = {};
                    renderInterventions();
                });
        });
    }
}

/* ── Statistiques par agent ────────────────────────────────────── */

async function coRenderStats() {
    const box = el('co-body');
    if (!box) return;
    box.innerHTML = emptyState('⏳', 'Calcul des statistiques…');

    const rows = asArray(await fetchNui('mdtco:getStats', {}));
    if (!el('co-body')) return;
    if (!rows.length) {
        el('co-body').innerHTML = emptyState('📊', 'Aucune donnée pour le moment.');
        return;
    }

    const body = rows.map((r) => {
        const inter = parseInt(r.interventions, 10) || 0;
        const succ = parseInt(r.successes, 10) || 0;
        const rate = inter > 0 ? Math.round((succ / inter) * 100) : 0;
        const mis = parseInt(r.misconduct, 10) || 0;
        return `
        <tr>
            <td>${esc(r.name || '—')}${depBadge(r.department)}</td>
            <td>${inter}</td>
            <td>${esc(r.cuffed || 0)}</td>
            <td>${esc(r.delivered || 0)}</td>
            <td>${esc(r.killed || 0)}</td>
            <td>${mis > 0 ? `<span class="mdt-badge mdt-badge-red">${mis}</span>` : '0'}</td>
            <td>${rate} %</td>
        </tr>`;
    }).join('');

    el('co-body').innerHTML = `
        <table class="mdt-table">
            <thead>
                <tr>
                    <th>Agent</th><th>Interventions</th><th>Menottés</th>
                    <th>Présentés</th><th>Neutralisés</th><th>Bavures</th><th>Réussite</th>
                </tr>
            </thead>
            <tbody>${body}</tbody>
        </table>`;
}

/* ── Inscription au groupe d'intervention (unité + équipage) ─────── */

/* Répercute l'indicatif dans l'en-tête MDT sans réouvrir toute la
   fiche — mdt:open n'est renvoyé qu'à la connexion. */
function coApplyCallsignToHeader(callsign) {
    if (state.payload) state.payload.callsign = callsign || state.payload.officerName;
    const nameEl = el('mdt-officer-name');
    if (nameEl) nameEl.textContent = callsign || (state.payload && state.payload.officerName) || '—';
}

async function coRenderRegistration() {
    const box = el('co-body');
    if (!box) return;
    box.innerHTML = emptyState('⏳', 'Chargement…');

    const res = await fetchNui('mdtco:getRegistration', {});
    if (!el('co-body')) return;
    const payload = (res && typeof res === 'object' && !Array.isArray(res)) ? res : {};
    const units = asArray(payload.units);
    const crews = asArray(payload.crews);
    const canManage = !!payload.canManage;
    const current = payload.current || null;

    if (current) {
        el('co-body').innerHTML = `
            <div class="mdt-detail">
                <div class="mdt-detail-row"><b>Indicatif actuel :</b> ${esc(current.callsign || '—')}</div>
                <div class="co-actions">
                    <button class="mdt-btn mdt-btn-danger" id="co-reg-leave">Quitter le groupe d'intervention</button>
                </div>
            </div>`;
        b('co-reg-leave', async () => {
            const r = await fetchNui('mdtco:leaveRegistration', {});
            if (r && r.ok !== false) coApplyCallsignToHeader(null);
            coRenderRegistration();
        });
        return;
    }

    if (!coState.regUnit || !units.find((u) => u.id === coState.regUnit)) {
        coState.regUnit = (units.find((u) => u.locked) || units[0] || {}).id || null;
    }
    if (!coState.regCrew) coState.regCrew = (crews[0] || {}).id || null;

    const unitRows = units.map((u) => `
        <div class="mdt-list-item co-unit-row ${coState.regUnit === u.id ? 'active' : ''}" data-unit="${esc(u.id)}">
            <div class="mdt-li-main">
                <div class="mdt-li-name">${esc(u.label)}${u.locked ? '' : (u.visible
                    ? ' <span class="mdt-badge mdt-badge-green">Active</span>'
                    : ' <span class="mdt-badge mdt-badge-gray">Inactive</span>')}</div>
            </div>
            ${(canManage && !u.locked) ? `<button class="mdt-btn co-unit-toggle" data-toggle="${esc(u.id)}">${
                u.visible ? 'Désactiver' : 'Activer'}</button>` : ''}
        </div>`).join('');

    const crewOpts = crews.map((c) => {
        const full = c.count >= c.max;
        return `<div class="mdt-pill ${coState.regCrew === c.id ? 'active' : ''}"
            data-crew="${esc(c.id)}" ${full ? 'title="Complet"' : ''}>${esc(c.label)} (${c.count}/${c.max})</div>`;
    }).join('');

    el('co-body').innerHTML = `
        <div class="mdt-page-sub">Choisissez votre unité puis votre équipage pour rejoindre Appel 17.</div>
        <div class="mdt-list">${unitRows}</div>
        <div class="mdt-page-sub" style="margin-top:12px">Équipage</div>
        <div class="mdt-searchbar">${crewOpts}</div>
        <div class="co-actions" style="margin-top:12px">
            <button class="mdt-btn mdt-btn-primary" id="co-reg-join">Rejoindre</button>
        </div>`;

    document.querySelectorAll('#co-body .co-unit-row').forEach((it) => {
        it.addEventListener('click', (ev) => {
            if (ev.target.closest('.co-unit-toggle')) return;
            coState.regUnit = it.dataset.unit;
            coRenderRegistration();
        });
    });
    document.querySelectorAll('#co-body .co-unit-toggle').forEach((btn) => {
        btn.addEventListener('click', async (ev) => {
            ev.stopPropagation();
            await fetchNui('mdtco:toggleUnit', { unit: btn.dataset.toggle });
            coRenderRegistration();
        });
    });
    document.querySelectorAll('#co-body [data-crew]').forEach((p) => {
        p.addEventListener('click', () => {
            coState.regCrew = p.dataset.crew;
            coRenderRegistration();
        });
    });

    b('co-reg-join', async () => {
        if (!coState.regUnit || !coState.regCrew) return;
        const r = await fetchNui('mdtco:setRegistration', { unit: coState.regUnit, crew: coState.regCrew });
        if (r && r.ok === false) {
            alertBox(r.reason || 'Inscription impossible.');
            return;
        }
        coApplyCallsignToHeader(r && r.current && r.current.callsign);
        coRenderRegistration();
    });
}

/* ── TN 97 (Centre d'Information et de Commandement) ─────────────── */

function coStopCicPolling() {
    if (coState.cicTimer) { clearInterval(coState.cicTimer); coState.cicTimer = null; }
}

const CIC_STATUS = {
    enroute: 'En route', onscene: 'Sur place',
    available: 'Disponible', unavailable: 'Indisponible',
};

function coCicWait(sec) {
    const n = Math.max(0, Math.floor(Date.now() / 1000 - sec));
    if (n < 60) return `${n} s`;
    return `${Math.floor(n / 60)} min`;
}

/* Distance 2D simple : suffisante pour suggérer l'équipage le plus
   proche, pas besoin de tenir compte du relief. */
function coCicDist(a, b) {
    if (!a || !b) return Infinity;
    return Math.hypot(a.x - b.x, a.y - b.y);
}

async function coRenderCic(silent) {
    const box = el('co-body');
    if (!box) return;
    if (!silent) box.innerHTML = emptyState('⏳', 'Chargement…');

    const res = await fetchNui('mdtco:getCicBoard', {});
    if (!el('co-body')) return;
    if (res && res.ok === false) {
        el('co-body').innerHTML = emptyState('🔒', res.reason || 'Accès refusé.');
        return;
    }
    const payload = (res && typeof res === 'object') ? res : {};
    const pending = asArray(payload.pending);
    const active = asArray(payload.active);
    const crews = asArray(payload.crews);
    const history = asArray(payload.history);
    const dangerCfg = (state.payload && state.payload.dangerLevels) || {};

    const units = Array.from(new Set(
        crews.flatMap((c) => asArray(c.members).map((m) => m.unit).filter(Boolean))));

    const dangerBadge = (lvl) => {
        const d = dangerCfg[lvl] || dangerCfg[1];
        if (!d) return '';
        return `<span class="mdt-badge" style="background:${esc(d.color)};color:#fff">${esc(d.label)}</span>`;
    };

    const crewOptionsFor = (call, excludeId) => crews
        .filter((c) => (!c.busy || c.id === excludeId) && c.id !== excludeId)
        .map((c) => ({ ...c, dist: coCicDist(c.coords, call.coords) }))
        .sort((a, b) => a.dist - b.dist);

    const pendingCards = pending.map((p) => {
        const opts = crewOptionsFor(p, null);
        const nearestId = opts.length && opts[0].coords ? opts[0].id : null;
        const select = opts.length
            ? `<select class="mdt-input cic-crew-select" data-call="${esc(p.id)}">
                ${opts.map((c) => `<option value="${esc(c.id)}">${esc(c.label)}${
                    c.id === nearestId ? ' — recommandé (plus proche)' : ''}</option>`).join('')}
               </select>
               <button class="mdt-btn mdt-btn-primary cic-dispatch-btn" data-call="${esc(p.id)}">Envoyer</button>`
            : `<span class="mdt-text-red">Aucun équipage disponible</span>`;
        return `
        <div class="mdt-list-item">
            <div class="mdt-li-main">
                <div class="mdt-li-name">${p.backup ? '🆘 Renfort — ' : ''}${esc(p.label)} ${dangerBadge(p.danger)}</div>
                <div class="mdt-li-sub">${esc(p.zoneLabel || '—')} · en attente depuis ${coCicWait(p.waitingSince)}</div>
            </div>
            <div class="cic-dispatch">${select}</div>
        </div>`;
    }).join('');

    const activeCards = active.map((a) => {
        const opts = crewOptionsFor(a, a.crew);
        const select = opts.length
            ? `<select class="mdt-input cic-crew-select" data-active="${esc(a.id)}">
                ${opts.map((c) => `<option value="${esc(c.id)}">${esc(c.label)}</option>`).join('')}
               </select>
               <button class="mdt-btn cic-reassign-btn" data-active="${esc(a.id)}">Réaffecter</button>`
            : '';
        return `
        <div class="mdt-list-item">
            <div class="mdt-li-main">
                <div class="mdt-li-name">${esc(a.label)}</div>
                <div class="mdt-li-sub">${esc(a.zoneLabel || '—')} · équipage actuel : ${esc(a.crewLabel)}</div>
            </div>
            <div class="cic-dispatch">${select}</div>
        </div>`;
    }).join('');

    const filteredCrews = crews.filter((c) => coState.cicUnitFilter === 'all'
        || asArray(c.members).some((m) => m.unit === coState.cicUnitFilter));

    const crewCards = filteredCrews.map((c) => {
        const membersHtml = asArray(c.members).map((m) => `
            <div class="cic-member">
                <span>${esc(m.name)} <span class="mdt-text-dim">(${esc(m.grade || '—')}${m.unit ? ` · ${esc(m.unit)}` : ''})</span></span>
                ${m.mission ? `<span class="mdt-badge mdt-badge-blue">${esc(m.mission)}${
                    m.status ? ` — ${esc(CIC_STATUS[m.status] || m.status)}` : ''}</span>` : ''}
            </div>`).join('');
        return `
        <div class="mdt-list-item" style="flex-direction:column;align-items:stretch;gap:6px">
            <div class="mdt-li-name">${esc(c.label)} ${c.busy
                ? '<span class="mdt-badge mdt-badge-orange">En mission</span>'
                : '<span class="mdt-badge mdt-badge-green">Disponible</span>'}</div>
            <div>${membersHtml}</div>
        </div>`;
    }).join('');

    const historyHtml = history.slice().reverse().slice(0, 15).map((h) => `
        <div class="mdt-li-sub">Appel « ${esc(h.label)} » → ${esc(h.crew)} par ${esc(h.cic)}
            (${h.kind === 'reassign' ? 'réaffectation' : h.kind === 'renfort' ? 'renfort' : 'affectation'}) — ${esc(fmtDate(h.at * 1000))}</div>
    `).join('') || `<div class="mdt-li-sub">Aucune affectation pour le moment.</div>`;

    box.innerHTML = `
        <div class="co-actions">
            <button class="mdt-btn ${payload.isCic ? 'mdt-btn-danger' : 'mdt-btn-primary'}" id="cic-toggle">${
                payload.isCic ? 'Quitter le poste TN 97' : 'Prendre le poste TN 97'}</button>
        </div>
        <div class="mdt-detail-row"><b>Statut :</b> ${payload.cicOnline
            ? '<span class="mdt-badge mdt-badge-green">Au moins un CIC en ligne</span>'
            : '<span class="mdt-badge mdt-badge-gray">Aucun CIC en ligne — auto-accept actif</span>'}</div>

        ${units.length ? `
        <div class="mdt-searchbar" style="margin-top:10px">
            <div class="mdt-pill ${coState.cicUnitFilter === 'all' ? 'active' : ''}" data-unit="all">Toutes unités</div>
            ${units.map((u) => `<div class="mdt-pill ${coState.cicUnitFilter === u ? 'active' : ''}" data-unit="${esc(u)}">${esc(u)}</div>`).join('')}
        </div>` : ''}

        <div class="mdt-page-sub" style="margin-top:14px">Appels en attente d'affectation</div>
        <div class="mdt-list">${pendingCards || emptyState('✅', 'Aucun appel en attente.')}</div>

        <div class="mdt-page-sub" style="margin-top:14px">Interventions en cours</div>
        <div class="mdt-list">${activeCards || emptyState('📭', 'Aucune intervention en cours.')}</div>

        <div class="mdt-page-sub" style="margin-top:14px">Équipages</div>
        <div class="mdt-list">${crewCards || emptyState('👥', 'Aucun équipage inscrit.')}</div>

        <div class="mdt-page-sub" style="margin-top:14px">Dernières affectations</div>
        ${historyHtml}
    `;

    b('cic-toggle', async () => {
        const r = await fetchNui('mdtco:cicToggle', {});
        if (r && r.ok === false) { alertBox(r.reason || 'Action impossible.'); return; }
        // Prendre le poste TN 97 quitte automatiquement l'équipage en cours.
        if (r && r.active) coApplyCallsignToHeader(null);
        coRenderCic();
    });
    document.querySelectorAll('#co-body [data-unit]').forEach((p) => {
        p.addEventListener('click', () => { coState.cicUnitFilter = p.dataset.unit; coRenderCic(); });
    });
    document.querySelectorAll('#co-body .cic-dispatch-btn').forEach((btn) => {
        btn.addEventListener('click', async () => {
            const callId = btn.dataset.call;
            const sel = document.querySelector(`.cic-crew-select[data-call="${callId}"]`);
            if (!sel || !sel.value) return;
            btn.disabled = true;
            const r = await fetchNui('mdtco:cicDispatch', { id: Number(callId), crew: sel.value });
            if (r && r.ok === false) alertBox(r.reason || 'Affectation impossible.');
            coRenderCic();
        });
    });
    document.querySelectorAll('#co-body .cic-reassign-btn').forEach((btn) => {
        btn.addEventListener('click', async () => {
            const callId = btn.dataset.active;
            const sel = document.querySelector(`.cic-crew-select[data-active="${callId}"]`);
            if (!sel || !sel.value) return;
            btn.disabled = true;
            const r = await fetchNui('mdtco:cicDispatch', { id: Number(callId), crew: sel.value });
            if (r && r.ok === false) alertBox(r.reason || 'Réaffectation impossible.');
            coRenderCic();
        });
    });

    if (!coState.cicTimer) {
        coState.cicTimer = setInterval(() => {
            if (state.currentTab !== 'interventions' || !el('co-tab-cic')
                || el('co-tab-cic').className.indexOf('mdt-btn-primary') === -1) {
                coStopCicPolling();
                return;
            }
            coRenderCic(true);
        }, 4000);
    }
}

/* ════════════════════════════════════════════════════════════════
   Enregistrement dans le point d'extension de mdt.js
   ════════════════════════════════════════════════════════════════ */
window.MDT_RENDERERS = Object.assign(window.MDT_RENDERERS || {}, {
    interventions: renderInterventions,
});

/* Poussé par le serveur (mdt:result → mdt:refresh) à chaque évolution
   notable d'une intervention en cours (cf. UpdateCalloutRecord côté
   police) : sans ça, le bouton « À prévenir » n'apparaît qu'en quittant
   puis rouvrant l'onglet — la fiche semblait figée. On ne retouche
   l'écran que si l'onglet Historique est bien celui affiché, pour ne
   pas couper l'agent au milieu des Statistiques / Inscription / TN 97. */
window.MDT_EXT_REFRESH = (refresh) => {
    if (!refresh || refresh.view !== 'callouts') return false;
    if (state.currentTab !== 'interventions') return false;
    const historyBtn = el('co-tab-history');
    if (historyBtn && historyBtn.classList.contains('mdt-btn-primary')) {
        coRenderHistory();
    }
    return true;
};

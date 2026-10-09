-- Braquage de conducteur PNJ : viser un PNJ au volant d'un véhicule ambiant
-- (cf. client/population.lua) avec une arme létale chargée a une chance de le
-- faire sortir mains en l'air puis prendre la fuite en laissant le véhicule
-- déverrouillé. Fouiller la boîte à gants du véhicule abandonné a ensuite une
-- chance de faire tomber les clés (bonne plaque). Config partagée client + serveur.

PNJVehicule = PNJVehicule or {}
PNJVehicule.Config = {}

local C = PNJVehicule.Config

C.Enabled = true

-- ── Menace / mains en l'air ──────────────────────────────────────────
C.AimRange        = 15.0  -- distance max (m) pour que viser le PNJ conducteur soit pris en compte
C.HandsUpChance    = 70    -- % de chance que le PNJ conducteur visé lève les mains
C.RetryCooldownMs  = 8000  -- si le tirage échoue, délai (ms) avant de pouvoir retenter sur le même véhicule
C.HandsUpDuration  = 5000  -- ms passées mains en l'air avant que le PNJ prenne la fuite
C.FleeRadius       = 100.0 -- distance de fuite du PNJ (TaskSmartFleePed)
C.ExitVehicleTimeout = 8000 -- ms max d'attente que le PNJ sorte du véhicule (TaskLeaveVehicle) avant les mains en l'air

-- Armes considérées comme "létales" pour déclencher la menace (noms d'armes, cf. GetHashKey).
C.LethalWeapons = {
    'weapon_pistol', 'weapon_combatpistol', 'weapon_pistol_mk2', 'weapon_machinepistol',
    'weapon_pistol50', 'weapon_heavypistol', 'weapon_vintagepistol', 'weapon_snspistol',
    'weapon_snspistol_mk2', 'weapon_revolver', 'weapon_revolver_mk2', 'weapon_doubleaction',
    'weapon_ceramicpistol', 'weapon_navyrevolver',
    'weapon_microsmg', 'weapon_smg', 'weapon_smg_mk2', 'weapon_assaultsmg', 'weapon_combatpdw', 'weapon_minismg',
    'weapon_assaultrifle', 'weapon_assaultrifle_mk2', 'weapon_carbinerifle', 'weapon_carbinerifle_mk2',
    'weapon_advancedrifle', 'weapon_specialcarbine', 'weapon_specialcarbine_mk2', 'weapon_bullpuprifle',
    'weapon_bullpuprifle_mk2', 'weapon_compactrifle', 'weapon_militaryrifle',
    'weapon_pumpshotgun', 'weapon_pumpshotgun_mk2', 'weapon_sawnoffshotgun', 'weapon_assaultshotgun',
    'weapon_bullpupshotgun', 'weapon_musket', 'weapon_heavyshotgun', 'weapon_dbshotgun', 'weapon_autoshotgun',
    'weapon_sniperrifle', 'weapon_heavysniper', 'weapon_heavysniper_mk2', 'weapon_marksmanrifle',
    'weapon_marksmanrifle_mk2', 'weapon_precisionrifle',
    'weapon_mg', 'weapon_combatmg', 'weapon_combatmg_mk2', 'weapon_gusenberg',
}

-- ── Boîte à gants / clés ─────────────────────────────────────────────
-- % de chance que la clé du véhicule soit déjà dans la boîte à gants à la
-- création de son datastore (dès qu'on monte au volant du véhicule abandonné).
C.GloveboxKeyChance = 100

-- Messages affichés (configurables).
C.Messages = {
    handsUp   = "Le conducteur lève les mains !",
    fled      = "Le conducteur a pris la fuite, le véhicule est déverrouillé.",
    keysFound = "Vous trouvez les clés du véhicule dans la boîte à gants !",
}

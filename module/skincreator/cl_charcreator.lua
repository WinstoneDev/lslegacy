MadeInFrance.RegisterClientEvent('CreatePerso', function()
    local player = PlayerPedId()
    local interior = GetInteriorAtCoordsWithType(vector3(399.9, -998.7, -100.0), "v_mugshot")
    LoadInterior(interior)
    while not IsInteriorReady(interior) do
        Wait(0)
    end
    MadeInFrance.SendEventToServer("SetBucket", math.random(1, 25000))
    MadeInFrance.TriggerLocalEvent('skinchanger:change', 'sex', 0)
    Wait(150)
    MadeInFrance.TriggerLocalEvent('skinchanger:loadSkin', {
        sex      = 0,
        tshirt_1 = 15,
        tshirt_2 = 0,
        arms     = 15,
        arms_2   = 0,
        face_ped = 0,
        face_ped2 = 0,
        torso_1  = 15,
        torso_2  = 0,
        pants_1  = 14,
        pants_2  = 0,
        shoes_1  = 34,
        shoes_2  = 0,
        helmet_1  = -1,
        helmet_2  = 0,
        glasses_1  = -1,
        glasses_2  = 0,
        chain_1 = 0,
        chain_2 = 0,
        decals_1 = 0,
        decals_2 = 0,
        bags_1 = 0,
        bags_2 = 0
    })
    FreezeEntityPosition(player, false)
    SetEntityCoords(GetPlayerPed(-1), 399.9, -998.7, -100.0)
    DoScreenFadeOut(1500)
    Wait(3000)
    DoScreenFadeIn(1500)
    DisplayRadar(false)
    CreatorLoadContent()
    AnimationIntro()
    Wait(1000)
    FreezeEntityPosition(player, true)
    ClearPlayerWantedLevel(PlayerId())
    MenuCreaPerso()
end)


CreaPerso = {
    Diamond = true,
    HairListingIndex = 1,
    HairValue = {},

    BeardListingIndex = 1,
    BeardListingIndex2 = 1,
    BeardValue = {},

    EyebrownListingIndex = 1,
    EyebrownListingIndex2 = 1,
    EyebrowValue = {},

    BodyblemishesListingIndex = 1,
    BodyblemishesListingIndex2 = 1,
    BodyblemishesValue = {},

    WrinklesListingIndex = 1,
    WrinklesListingIndex2 = 1,
    WrinklesValue = {},

    SunListingIndex = 1,
    SunListingIndex2 = 1,
    SunValue = {},

    EyesValue = {"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19","20","21","22","23","24","25","26","27","28","29","30","31","32","33"},
    EyesListingIndex = 1,

    FrecklesListingIndex = 1,
    FrecklesListingIndex2 = 1,
    FrecklesValue = {},

    ChestListingIndex = 1,
    ChestListingIndex2 = 1,
    VisagePed = 1,
    HautPed = 1,
    BasPed = 1,
    CasquePed = 1,
    MasquePed = 1,
    ChestValue = {},

    MakeupListingIndex = 1,
    MakeupListingIndex2 = 1,
    MakeupValue = {},

    LipstickListingIndex = 1,
    LipstickListingIndex2 = 1,
    LipstickValue = {},

    ComplexionListingIndex = 1,
    ComplexionListingIndex2 = 1,
    ComplexionValue = {},

    actionRessemblance = 5,
    actionPeau = 5,
    actionFather = 1,
    actionMother = 1,
    MotherListCreator = { "Hannah", "Aubrey", "Jasmine", "Gisele", "Amelia", "Isabella", "Zoe", "Ava", "Camila", "Violet", "Sophia", "Evelyn", "Nicole", "Ashley", "Gracie", "Brianna", "Natalie", "Olivia", "Elizabeth", "Charlotte", "Emma", "Hannah", "Aubrey", "Jasmine", "Gisele", "Amelia", "Isabella", "Zoe", "Ava", "Camila", "Violet", "Sophia", "Evelyn", "Nicole", "Ashley", "Gracie", "Brianna", "Natalie", "Olivia", "Elizabeth", "Charlotte", "Emma", "Amelia", "Isabella", "Zoe", "Ava"},
	FatherListCreator = { "Benjamin", "Daniel", "Joshua", "Noah", "Andrew", "Juan", "Alex", "Isaac", "Evan", "Ethan", "Vincent", "Angel", "Diego", "Adrian", "Gabriel", "Michael", "Santiago", "Kevin", "Louis", "Samuel", "Anthony", " Claude", "Niko", "Daniel", "Joshua", "Noah", "Andrew", "Juan", "Alex", "Isaac", "Evan", "Ethan", "Vincent", "Angel", "Diego", "Adrian", "Gabriel", "Michael", "Santiago", "Kevin", "Louis", "Samuel", "Anthony", " Claude", "Niko", "Titouan"},

    Color = {
        Hair = { 1, 1 },
        Hair2 = { 1, 1 },
        Beard = { 1, 1 },
        Makeup = { 1, 1 },
        EyeBrows = { 1, 1 }
    },

    Tenue = 1,

    ListePersonage = {
        'g_m_importexport_01',
        'g_m_m_armboss_01',
        'g_m_m_armgoon_01',
        'g_m_m_armlieut_01',
        'g_m_m_chemwork_01',
        'g_m_m_chiboss_01',
        'g_m_m_chicold_01',
        'g_m_m_chigoon_01',
        'g_m_m_chigoon_02',
        'g_m_m_korboss_01',
        'g_m_m_mexboss_01',
        'g_m_m_mexboss_02',
        'g_m_y_armgoon_02',
        'g_m_y_azteca_01',
        'g_m_y_ballaeast_01',
        'g_m_y_ballaorig_01',
        'g_m_y_ballasout_01',
        'g_m_y_famca_01',
        'g_m_y_famdnf_01',
        'g_m_y_famfor_01',
        'a_m_m_soucent_04',
        'a_m_m_og_boss_01',
        'g_m_y_korean_01',
        'g_m_y_korean_02',
        'g_m_y_korlieut_01',
        'g_m_y_lost_01',
        'g_m_y_lost_02',
        'g_m_y_lost_03',
        'g_m_y_mexgang_01',
        'g_m_y_mexgoon_01',
        'g_m_y_mexgoon_02',
        'g_m_y_mexgoon_03',
        'g_m_y_pologoon_01',
        'g_m_y_pologoon_02',
        'g_m_y_salvaboss_01',
        'g_m_y_salvagoon_01',
        'g_m_y_salvagoon_02',
        'g_m_y_salvagoon_03',
        'g_m_y_strpunk_01',
        'g_m_y_strpunk_02',
        --Gang Female
        'g_f_importexport_01',
        'g_f_y_ballas_01',
        'g_f_y_families_01',
        'g_f_y_lost_01',
        'g_f_y_vagos_01',
        --Multiplayer
        'mp_f_bennymech_01',
        'mp_f_boatstaff_01',
        'mp_f_cardesign_01',
        'mp_f_chbar_01',
        'mp_f_counterfeit_01',
        'mp_f_forgery_01',
        'mp_f_helistaff_01',
        'mp_f_weed_01',
        'mp_g_m_pros_01',
        'mp_m_boatstaff_01',
        'mp_m_counterfeit_01',
        'mp_m_exarmy_01',
        'mp_m_forgery_01',
        'mp_m_g_vagfun_01',
        'mp_m_waremech_01',
        'mp_m_weapexp_01',
        'mp_m_weapwork_01',
        'mp_m_weed_01',
        --Scenario female
        's_f_m_fembarber',
        's_f_m_maid_01',
        's_f_m_sweatshop_01',
        's_f_y_airhostess_01',
        's_f_y_bartender_01',
        's_f_y_clubbar_01',
        's_f_y_hooker_01',
        's_f_y_hooker_02',
        's_f_y_hooker_03',
        's_f_y_migrant_01',
        's_f_y_movprem_01',
        's_f_y_scrubs_01',
        's_f_y_shop_low',
        's_f_y_shop_mid',
        's_f_y_stripper_01',
        's_f_y_stripper_02',
        's_f_y_sweatshop_01',
        's_f_y_casino_01',
        --Scenario male
        's_m_m_ammucountry',
        's_m_m_autoshop_01',
        's_m_m_autoshop_02',
        's_m_m_bouncer_01',
        's_m_m_ccrew_01',
        's_m_m_cntrybar_01',
        's_m_m_dockwork_01',
        's_m_m_doctor_01',
        's_m_m_fiboffice_01',
        's_m_m_fiboffice_02',
        's_m_m_gaffer_01',
        's_m_m_gardener_01',
        's_m_m_gentransport',
        's_m_m_hairdress_01',
        's_m_m_highsec_01',
        's_m_m_highsec_02',
        's_m_m_janitor',
        's_m_m_lathandy_01',
        's_m_m_lifeinvad_01',
        's_m_m_linecook',
        's_m_m_lsmetro_01',
        's_m_m_mariachi_01',
        's_m_m_migrant_01',
        's_m_m_movprem_01',
        's_m_m_paramedic_01',
        's_m_m_postal_01',
        's_m_m_postal_02',
        's_m_m_scientist_01',
        's_m_m_strpreach_01',
        's_m_m_strvend_01',
        's_m_m_trucker_01',
        's_m_m_ups_01',
        's_m_m_ups_02',
        's_m_o_busker_01',
        's_m_y_airworker',
        's_m_y_ammucity_01',
        's_m_y_armymech_01',
        's_m_y_autopsy_01',
        's_m_y_barman_01',
        's_m_y_busboy_01',
        's_m_y_chef_01',
        's_m_y_clown_01',
        's_m_y_clubbar_01',
        's_m_y_construct_01',
        'a_m_m_soucent_01',
        's_m_y_dealer_01',
        's_m_y_devinsec_01',
        's_m_y_dockwork_01',
        's_m_y_doorman_01',
        's_m_y_dwservice_01',
        's_m_y_dwservice_02',
        's_m_y_garbage',
        's_m_y_grip_01',
        's_m_y_mime',
        's_m_y_prismuscl_01',
        's_m_y_prisoner_01',
        's_m_y_robber_01',
        's_m_y_shop_mask',
        's_m_y_strvend_01',
        's_m_y_valet_01',
        's_m_y_waiter_01',
        's_m_y_waretech_01',
        's_m_y_winclean_01',
        's_m_y_xmech_02',
        --Story
        'ig_abigail',
        'ig_ashley',
        'ig_avon',
        'ig_bankman',
        'ig_barry',
        'ig_benny',
        'ig_bestmen',
        'ig_beverly',
        'ig_bride',
        'ig_car3guy1',
        'ig_car3guy2',
        'ig_chengsr',
        'ig_clay',
        'ig_claypain',
        'ig_cletus',
        'ig_dale',
        'ig_dix',
        'ig_djblamadon',
        'ig_djblamrupert',
        'ig_djblamryans',
        'ig_djdixmanager',
        'ig_djgeneric_01',
        'ig_djsolfotios',
        'ig_djsoljakob',
        'ig_djsolmanager',
        'ig_djsolmike',
        'ig_djsolrobt',
        'ig_djtalaurelia',
        'ig_djtalignazio',
        'ig_dreyfuss',
        'ig_englishdave',
        'ig_fbisuit_01',
        'ig_g',
        'ig_groom',
        'ig_hao',
        'ig_janet',
        'ig_jewelass',
        'ig_jimmyboston',
        'ig_jimmyboston_02',
        'ig_joeminuteman',
        'ig_josef',
        'ig_josh',
        'ig_kerrymcintosh',
        'ig_kerrymcintosh_02',
        'ig_lacey_jones_02',
        'ig_lazlow_2',
        'ig_lestercrest_2',
        'ig_lifeinvad_01',
        'ig_lifeinvad_02',
        'ig_magenta',
        'ig_malc',
        'ig_manuel',
        'ig_marnie',
        'ig_maryann',
        'ig_maude',
        'ig_money',
        'ig_mrs_thornhill',
        'ig_mrsphillips',
        'ig_natalia',
        'ig_nigel',
        'ig_old_man1a',
        'ig_old_man2',
        'ig_oneil',
        'ig_ortega',
        'ig_paige',
        'ig_paper',
        'ig_popov',
        'ig_priest',
        'csb_ramp_gang',
        'ig_ramp_hic',
        'ig_ramp_hipster',
        'ig_ramp_mex',
        'ig_rashcosvki',
        'ig_roccopelosi',
        'ig_russiandrunk',
        'ig_sacha',
        'ig_screen_writer',
        'ig_sol',
        'ig_talcc',
        'ig_talina',
        'ig_talmm',
        'ig_tanisha',
        'ig_terry',
        'ig_tomepsilon',
        'ig_tonya',
        'ig_tonyprince',
        'ig_tylerdix',
        'ig_tylerdix_02',
        'ig_vagspeak',
        'ig_zimbor',
        --Story scenario female
        'u_f_m_miranda',
        'u_f_m_miranda_02',
        'u_f_m_promourn_01',
        'u_f_o_moviestar',
        'u_f_o_prolhost_01',
        'u_f_y_bikerchic',
        'u_f_y_comjane',
        'u_f_y_danceburl_01',
        'u_f_y_dancelthr_01',
        'u_f_y_dancerave_01',
        'u_f_y_hotposh_01',
        'u_f_y_jewelass_01',
        'u_f_y_mistress',
        'u_f_y_poppymich',
        'u_f_y_poppymich_02',
        'u_f_y_princess',
        'u_f_y_spyactress',
        --Story scenario male
        'u_m_m_aldinapoli',
        'u_m_m_bankman',
        'u_m_m_bikehire_01',
        'u_m_m_doa_01',
        'u_m_m_edtoh',
        'u_m_m_fibarchitect',
        'u_m_m_filmdirector',
        'u_m_m_glenstank_01',
        'u_m_m_griff_01',
        'u_m_m_jesus_01',
        'u_m_m_jewelsec_01',
        'u_m_m_jewelthief',
        'u_m_m_markfost',
        'u_m_m_partytarget',
        'u_m_m_promourn_01',
        'u_m_m_rivalpap',
        'u_m_m_spyactor',
        'u_m_m_willyfist',
        'u_m_o_finguru_01',
        'u_m_o_taphillbilly',
        'u_m_o_tramp_01',
        'u_m_y_abner',
        'u_m_y_antonb',
        'u_m_y_baygor',
        'u_m_y_burgerdrug_01',
        'u_m_y_chip',
        'u_m_y_cyclist_01',
        'u_m_y_babyd',
        'u_m_y_danceburl_01',
        'u_m_y_dancelthr_01',
        'u_m_y_dancerave_01',
        'u_m_y_fibmugger_01',
        'u_m_y_guido_01',
        'u_m_y_gunvend_01',
        'u_m_y_hippie_01',
        'u_m_y_imporage',
        'u_m_y_justin',
        'u_m_y_mani',
        'u_m_y_militarybum',
        'u_m_y_paparazzi',
        'u_m_y_party_01',
        'u_m_y_prisoner_01',
        'u_m_y_sbike',
        'u_m_y_smugmech_01',
        'u_m_y_staggrm_01',
        'u_m_y_tattoo_01',
        --Cutscene
        'csb_grove_str_dlr',
        'csb_hugh',
        'csb_imran',
        'csb_jackhowitzer',
        'csb_janitor',
        'csb_mrs_r',
        'csb_oscar',
        'csb_porndudes',
        'csb_undercover',
        --Ambient female
        'a_f_m_beach_01',
        'a_f_m_bevhills_01',
        'a_f_m_bevhills_02',
        'a_f_m_business_02',
        'a_f_m_downtown_01',
        'a_f_m_eastsa_01',
        'a_f_m_eastsa_02',
        'a_f_m_fatbla_01',
        'a_f_m_fatcult_01',
        'a_f_m_fatwhite_01',
        'a_f_m_ktown_01',
        'a_f_m_ktown_02',
        'a_f_m_prolhost_01',
        'a_f_m_salton_01',
        'a_f_m_skidrow_01',
        'a_f_m_soucent_01',
        'a_f_m_soucent_02',
        'a_f_m_soucentmc_01',
        'a_f_m_tourist_01',
        'a_f_m_tramp_01',
        'a_f_m_trampbeac_01',
        'a_f_o_genstreet_01',
        'a_f_o_indian_01',
        'a_f_o_ktown_01',
        'a_f_o_salton_01',
        'a_f_o_soucent_01',
        'a_f_o_soucent_02',
        'a_f_y_beach_01',
        'a_f_y_bevhills_01',
        'a_f_y_bevhills_02',
        'a_f_y_bevhills_03',
        'a_f_y_bevhills_04',
        'a_f_y_business_01',
        'a_f_y_business_02',
        'a_f_y_business_03',
        'a_f_y_business_04',
        'a_f_y_clubcust_01',
        'a_f_y_clubcust_02',
        'a_f_y_clubcust_03',
        'a_f_y_eastsa_01',
        'a_f_y_eastsa_02',
        'a_f_y_eastsa_03',
        'a_f_y_epsilon_01',
        'a_f_y_femaleagent',
        'a_f_y_fitness_01',
        'a_f_y_fitness_02',
        'a_f_y_genhot_01',
        'a_f_y_golfer_01',
        'a_f_y_hiker_01',
        'a_f_y_hippie_01',
        'a_f_y_hipster_01',
        'a_f_y_hipster_02',
        'a_f_y_hipster_03',
        'a_f_y_hipster_04',
        'a_f_y_indian_01',
        'a_f_y_juggalo_01',
        'a_f_y_runner_01',
        'a_f_y_rurmeth_01',
        'a_f_y_scdressy_01',
        'a_f_y_skater_01',
        'a_f_y_soucent_01',
        'a_f_y_soucent_02',
        'a_f_y_soucent_03',
        'a_f_y_tennis_01',
        'a_f_y_topless_01',
        'a_f_y_tourist_01',
        'a_f_y_tourist_02',
        'a_f_y_vinewood_01',
        'a_f_y_vinewood_02',
        'a_f_y_vinewood_03',
        'a_f_y_vinewood_04',
        'a_f_y_yoga_01',
        'a_m_m_acult_01',
        'a_m_m_afriamer_01',
        'a_m_m_beach_01',
        'a_m_m_beach_02',
        'a_m_m_bevhills_01',
        'a_m_m_bevhills_02',
        'a_m_m_business_01',
        'a_m_m_eastsa_01',
        'a_m_m_eastsa_02',
        'a_m_m_farmer_01',
        'a_m_m_fatlatin_01',
        'a_m_m_genfat_01',
        'a_m_m_genfat_02',
        'a_m_m_golfer_01',
        'a_m_m_hasjew_01',
        'a_m_m_hillbilly_01',
        'a_m_m_hillbilly_02',
        'a_m_m_indian_01',
        'a_m_m_ktown_01',
        'a_m_m_malibu_01',
        'a_m_m_mexcntry_01',
        'a_m_m_mexlabor_01',
        'a_m_m_og_boss_01',
        'a_m_m_paparazzi_01',
        'a_m_m_polynesian_01',
        'a_m_m_prolhost_01',
        'a_m_m_rurmeth_01',
        'a_m_m_salton_01',
        'a_m_m_salton_02',
        'a_m_m_salton_03',
        'a_m_m_salton_04',
        'a_m_m_skater_01',
        'a_m_m_skidrow_01',
        'a_m_m_socenlat_01',
        'a_m_m_soucent_01',
        'a_m_m_soucent_02',
        'a_m_m_soucent_03',
        'a_m_m_soucent_04',
        'a_m_m_stlat_02',
        'a_m_m_tennis_01',
        'a_m_m_tourist_01',
        'a_m_m_tramp_01',
        'a_m_m_trampbeac_01',
        'a_m_m_tranvest_01',
        'a_m_m_tranvest_02',
        'a_m_o_acult_01',
        'a_m_o_acult_02',
        'a_m_o_beach_01',
        'a_m_o_genstreet_01',
        'a_m_o_ktown_01',
        'a_m_o_salton_01',
        'a_m_o_soucent_01',
        'a_m_o_soucent_02',
        'a_m_o_soucent_03',
        'a_m_o_tramp_01',
        'a_m_y_acult_01',
        'a_m_y_acult_02',
        'a_m_y_beach_01',
        'a_m_y_beach_02',
        'a_m_y_beach_03',
        'a_m_y_beachvesp_01',
        'a_m_y_beachvesp_02',
        'a_m_y_bevhills_01',
        'a_m_y_bevhills_02',
        'a_m_y_breakdance_01',
        'a_m_y_busicas_01',
        'a_m_y_business_01',
        'a_m_y_business_02',
        'a_m_y_business_03',
        'a_m_y_clubcust_01',
        'a_m_y_clubcust_02',
        'a_m_y_clubcust_03',
        'a_m_y_cyclist_01',
        'a_m_y_dhill_01',
        'a_m_y_downtown_01',
        'a_m_y_eastsa_01',
        'a_m_y_eastsa_02',
        'a_m_y_epsilon_01',
        'a_m_y_epsilon_02',
        'a_m_y_gay_01',
        'a_m_y_gay_02',
        'a_m_y_genstreet_01',
        'a_m_y_genstreet_02',
        'a_m_y_golfer_01',
        'a_m_y_hasjew_01',
        'a_m_y_hiker_01',
        'a_m_y_hippy_01',
        'a_m_y_hipster_01',
        'a_m_y_hipster_02',
        'a_m_y_hipster_03',
        'a_m_y_indian_01',
        'a_m_y_jetski_01',
        'a_m_y_juggalo_01',
        'a_m_y_ktown_01',
        'a_m_y_ktown_02',
        'a_m_y_latino_01',
        'a_m_y_methhead_01',
        'a_m_y_mexthug_01',
        'a_m_y_motox_01',
        'a_m_y_motox_02',
        'a_m_y_musclbeac_01',
        'a_m_y_musclbeac_02',
        'a_m_y_polynesian_01',
        'a_m_y_roadcyc_01',
        'a_m_y_runner_01',
        'a_m_y_runner_02',
        'a_m_y_salton_01',
        'a_m_y_skater_01',
        'a_m_y_skater_02',
        'a_m_y_soucent_01',
        'a_m_y_soucent_02',
        'a_m_y_soucent_03',
        'a_m_y_soucent_04',
        'a_m_y_stbla_01',
        'a_m_y_stbla_02',
        'a_m_y_stlat_01',
        'a_m_y_stwhi_01',
        'a_m_y_stwhi_02',
        'a_m_y_sunbathe_01',
        'a_m_y_surfer_01',
        'a_m_y_vindouche_01',
        'a_m_y_vinewood_01',
        'a_m_y_vinewood_02',
        'a_m_y_vinewood_03',
        'a_m_y_vinewood_04',
        'a_m_y_yoga_01',
        'cs_jimmydisanto',
    },
    Board = true,
    NDF = nil,
    Prenom = nil,
    DDN = nil,
    Sexe = nil,
    Taille = 0,
    LDN = nil,

    Traits = {
        LNezIndex = 1,
        HNezIndex = 1,
        LONezIndex = 1,
        ANezIndex = 1,
        APNezIndex = 1,
        TNezIndex1 = 1,
        TNezIndex2 = 1,
        HSIndex = 1,
        PSIndex = 1,
        HPIndex = 1,
        LPIndex = 1,
        LJIndex = 1,
        EOIndex = 1,
        ELIndex = 1,
        LMIndex = 1,
        LDMIndex = 1,
        AMIndex = 1,
        LMOIndex = 1,
        LAMIndex = 1,
        TMIndex = 1,
        ECIndex = 1
    },

    SexPerso = 0,

    VariationsFace = {
        min = 0,
        ind = 1,
        max = 5,
    },
    VariationsHaut = {
        min = 0,
        ind = 1,
        max = 5,
    },
    VariationsBas = {
        min = 0,
        ind = 1,
        max = 5,
    },
    VariationsChapeau = {
        min = 0,
        ind = 1,
        max = 5,
    },
    VariationsMasque = {
        min = 0,
        ind = 1,
        max = 5,
    },
}

local inIdentity = false

CreaPerso.openedMenu = false
CreaPerso.menu = RageUI.CreateMenu("Personnage", "Personnage")
CreaPerso.Personnage = RageUI.CreateSubMenu(CreaPerso.menu, "Personnage", "Personnage")
CreaPerso.CharHeritageMenu = RageUI.CreateSubMenu(CreaPerso.menu, "Héritage", "Héritage")
CreaPerso.Appearance = RageUI.CreateSubMenu(CreaPerso.menu, "Apparence", "Apparence")
CreaPerso.TraitVisage = RageUI.CreateSubMenu(CreaPerso.menu, "Visage", "Visage")
CreaPerso.TraitVisage2 = RageUI.CreateSubMenu(CreaPerso.menu, "Visage", "Visage")
CreaPerso.VetementPed = RageUI.CreateSubMenu(CreaPerso.menu, "Vêtement", "Vêtement")
CreaPerso.Makeup = RageUI.CreateSubMenu(CreaPerso.menu, "Makeup", "Makeup")
CreaPerso.Identity = RageUI.CreateSubMenu(CreaPerso.menu, "Identité", "Identité")
CreaPerso.ChooseSpawn = RageUI.CreateSubMenu(CreaPerso.menu, "Choix de spawn",  "Choix de spawn")
CreaPerso.CharHeritageMenu.Closed = function()
    CreatorZoomOut(GetCreatorCam())
end
CreaPerso.TraitVisage2.Closed = function()
    CreatorZoomOut(GetCreatorCam())
end

CreaPerso.TraitVisage.EnableMouse = true
CreaPerso.TraitVisage2.EnableMouse = true
CreaPerso.VetementPed.EnableMouse = true

CreaPerso.menu.Closable = false

CreaPerso.menu.Closed = function()
    CreaPerso.openedMenu = false
end

CreaPerso.Identity.Closed = function()
    inIdentity = false
end

CreaPerso.Personnage.Closed = function()
    RageUI.ResetFiltre()
end

CreaPerso.Appearance.EnableMouse = true
CreaPerso.Makeup.EnableMouse = true
CreaPerso.CharHeritageMenu.EnableMouse = true
CreaPerso.Personnage:AcceptFilter(true)

local IsDateGood = function(date)
    if (string.match(date, "^%d+%p%d+%p%d%d%d%d$")) then
        local d, m, y = string.match(date, "(%d+)%p(%d+)%p(%d+)")
        d, m, y = tonumber(d), tonumber(m), tonumber(y)
        local dm2 = d*m*m
        if  d>31 or m>12 or dm2==0 or dm2==116 or dm2==120 or dm2==124 or dm2==496 or dm2==1116 or dm2==2511 or dm2==3751 then
            if dm2==116 and (y%400 == 0 or (y%100 ~= 0 and y%4 == 0)) then
                return true
            else
                return false
            end
        else
            return true
        end
    else
        return false
    end
end

function firstToUpper(str)
    return (str:gsub("^%l", string.upper))
end

local inPrincipal = true
local itemButton = false
local inCamera = false

function MenuCreaPerso()
    if not CreaPerso.openedMenu then
        for i = 1, GetNumberOfPedDrawableVariations(PlayerPedId(), 2) do
            table.insert(CreaPerso.HairValue, {Name = tostring(i)})
        end
        
        for i = 1,GetNumHeadOverlayValues(7)-1 do
            table.insert(CreaPerso.SunValue, {Name = tostring(i)})
        end
        
        for i = 1, GetNumHeadOverlayValues(3)-1 do
            table.insert(CreaPerso.WrinklesValue, {Name = tostring(i)})
        end
        
        for i = 1, GetPedHeadOverlayNum(1) do
            table.insert(CreaPerso.BeardValue, {Name = tostring(i)})
        end
        
        for i = 1, GetNumberOfPedDrawableVariations(PlayerPedId(), 0)-12 do
            table.insert(CreaPerso.EyebrowValue, {Name = tostring(i)})
        end
        
        for i = 1, GetNumHeadOverlayValues(9)-1 do
            table.insert(CreaPerso.FrecklesValue, {Name = tostring(i)})
        end
        
        for i = 1, GetNumHeadOverlayValues(10)-1 do
            table.insert(CreaPerso.ChestValue, {Name = tostring(i)})
        end
        
        for i = 1, GetNumHeadOverlayValues(4)-1 do
            table.insert(CreaPerso.MakeupValue, {Name = tostring(i)})
        end
        
        for i = 1, GetNumHeadOverlayValues(8)-1 do
            table.insert(CreaPerso.LipstickValue, {Name = tostring(i)})
        end
        
        for i = 1, GetNumHeadOverlayValues(6)-1 do
            table.insert(CreaPerso.ComplexionValue, {Name = tostring(i)})
        end
        Wait(1000)
        CreaPerso.openedMenu = true
        RageUI.Visible(CreaPerso.menu, true)
        Citizen.CreateThread(function()
            while CreaPerso.openedMenu do
                if not inIdentity then
                    local ToucheGauche, ToucheDroite = IsDisabledControlPressed(1, 44), IsDisabledControlPressed(1, 51)
                    if ToucheGauche or ToucheDroite then
                        local PlayerPed = PlayerPedId()
                        SetEntityHeading(PlayerPed, ToucheGauche and GetEntityHeading(PlayerPed) - 2.0 or ToucheDroite and GetEntityHeading(PlayerPed) + 2.0)
                    end
                end
                Disable()
                RageUI.IsVisible(CreaPerso.menu, function()
                    if not CreaPerso.Board then
                        CreateBoard()
                        RequestAnimDict("mp_character_creation@customise@male_a")
                        Wait(100)
                        TaskPlayAnim(GetPlayerPed(-1), "mp_character_creation@customise@male_a", "loop", 2.5, -1.0,-1, 2, 0, 0, 0,0)
                        CreaPerso.Board = true
                    end
                    if not inPrincipal then inPrincipal = true CreatorZoomOut(GetCreatorCam()) end
                    if itemButton then itemButton = false end
                    RageUI.Button("Personnage", false, {}, true, {}, CreaPerso.Personnage)
                    if CreaPerso.SexPerso <= 1 then
                        RageUI.Button("Héritage", false, {}, true, {
                            onSelected = function()
                                CreatorZoomIn(GetCreatorCam())
                            end
                        }, CreaPerso.CharHeritageMenu)
                        RageUI.Button("Apparence", false, {}, true, {}, CreaPerso.Appearance)
                        RageUI.Button("Maquillage", false, {}, true, {
                            onSelected = function()
                                CreatorZoomIn(GetCreatorCam())
                            end
                        }, CreaPerso.Makeup)
                        RageUI.Button("Traits du visage", false, {}, true, {
                            onSelected = function()
                                CreatorZoomIn(GetCreatorCam())
                            end
                        }, CreaPerso.TraitVisage)
                    else
                        RageUI.Button("Traits du visage", false, {}, true, {
                            onSelected = function()
                                CreatorZoomIn(GetCreatorCam())
                            end
                        }, CreaPerso.TraitVisage2)
                        RageUI.Button("Vêtement", false, {}, true, {}, CreaPerso.VetementPed)
                    end
                    RageUI.Button("Identité", false, {}, true, {
                        onSelected = function()
                            inIdentity = true
                            CreatorZoomIn(GetCreatorCam())
                        end
                    }, CreaPerso.Identity)
                    RageUI.Button("~g~Valider & continuer", false, {}, true, {
                        onSelected = function()
                            if CreaPerso.NDF ~= nil then
                                if string.match(CreaPerso.NDF, "^%s*$") then
                                    CreaPerso.NDF = nil
                                end
                            end
                            if CreaPerso.Prenom ~= nil then
                                if string.match(CreaPerso.Prenom, "^%s*$") then
                                    CreaPerso.Prenom = nil
                                end
                            end
                            if CreaPerso.DDN ~= nil then
                                if string.match(CreaPerso.DDN, "^%s*$") then
                                    CreaPerso.DDN = nil
                                end
                            end
                            if tonumber(CreaPerso.Taille) == 0 then
                                CreaPerso.Taille = nil
                            end
                            if CreaPerso.Sexe ~= nil then
                                if tostring(CreaPerso.Sexe) ~= "M" then
                                    if tostring(CreaPerso.Sexe) ~= "F" then
                                        CreaPerso.Sexe = nil
                                    end
                                end
                                if tostring(CreaPerso.Sexe) ~= "F" then
                                    if tostring(CreaPerso.Sexe) ~= "M" then
                                        CreaPerso.Sexe = nil
                                    end
                                end
                            end
                            if CreaPerso.Sexe ~= nil then
                                if string.match(CreaPerso.LDN, "^%s*$") then
                                    CreaPerso.LDN = nil
                                end
                            end
                            if CreaPerso.NDF == nil or CreaPerso.Prenom == nil or CreaPerso.DDN == nil or CreaPerso.Taille == nil or CreaPerso.Sexe == nil or CreaPerso.LDN == nil then
                                MadeInFrance.ShowNotification(nil, "Veuillez réessayer de faire votre identité", 'error')
                            else
                                MadeInFrance.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    MadeInFrance.SendEventToServer('saveskin', skin)
                                end)
                                MadeInFrance.SendEventToServer("SetIdentity", CreaPerso.NDF, CreaPerso.Prenom, CreaPerso.DDN, CreaPerso.Sexe, CreaPerso.Taille, CreaPerso.LDN)
                                CreatorZoomOut(GetCreatorCam())
                                CreaPerso.openedMenu = false
                                RageUI.CloseAll()
                                Wait(1000)
                                PlaySoundFrontend(-1, "Lights_On", "GTAO_MUGSHOT_ROOM_SOUNDS", true)
                                DoScreenFadeOut(2500)
                                Wait(2500)
                                DestroyAllCams(true)
                                RenderScriptCams(false, false, 0, true, true)
                                FreezeEntityPosition(PlayerPedId(), false)
                                ClearPedTasksImmediately(PlayerPedId())
                                DeleteBoard()
                                MadeInFrance.SendEventToServer("SetBucket", 0)
                                -- local nombre = math.random(1,5)
                                -- if nombre == 1 then
                                --     ESX.Game.Teleport(PlayerPedId(), vector3(-1245.411, -742.6087, 20.366))
                                -- elseif nombre == 2 then
                                --     ESX.Game.Teleport(PlayerPedId(), vector3(-569.8499, -451.2148, 34.253))
                                -- elseif nombre == 3 then
                                --     ESX.Game.Teleport(PlayerPedId(), vector3(-1037.45, -2737.51, 20.16))
                                -- elseif nombre == 4 then
                                --     ESX.Game.Teleport(PlayerPedId(), vector3(917.56, 50.56, 80.89))
                                -- elseif nombre == 5 then
                                --     ESX.Game.Teleport(PlayerPedId(), vector3(-134.91, -254.29, 43.59))
                                -- end
                                MadeInFrance.SetCoords(vector3(-780.1779, -1048.915, 12.980))
                                SetEntityHeading(GetPlayerPed(-1), 125.39)
                                Wait(2500)
                                DoScreenFadeIn(2500)
                                MadeInFrance.ShowNotification(nil, "Vous avez créé votre personnage.", 'success')
                            end
                        end
                    })
                end)

                RageUI.IsVisible(CreaPerso.TraitVisage2, function()
                    RageUI.List('Visage', {"1", "2", "3", "4", "5"}, CreaPerso.VisagePed, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.VisagePed = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'face_ped', CreaPerso.VisagePed-1)
                        end,
                        onActive = function()
                            itemButton = false
                        end
                    })
                    RageUI.SliderPanel(CreaPerso.VariationsFace.ind, CreaPerso.VariationsFace.min, "Variations", CreaPerso.VariationsFace.max, {
                        onSliderChange = function(Index)
                            CreaPerso.VariationsFace.ind = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'face_ped2', CreaPerso.VariationsFace.ind)
                        end
                    }, 1)
                end)
                RageUI.IsVisible(CreaPerso.VetementPed, function()
                    RageUI.List('Haut', {"1", "2", "3", "4", "5"}, CreaPerso.HautPed, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.HautPed = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'arms', CreaPerso.HautPed-1)
                        end,
                        onActive = function()
                            itemButton = false
                        end
                    })
                    RageUI.List('Bas', {"1", "2", "3", "4", "5"}, CreaPerso.BasPed, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.BasPed = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'pants_1', CreaPerso.BasPed-1)
                        end,
                        onActive = function()
                            itemButton = false
                        end
                    })
                    RageUI.List('Chapeau', {"1", "2", "3", "4", "5"}, CreaPerso.CasquePed, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.CasquePed = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'helmet_1', CreaPerso.CasquePed-2)
                        end,
                        onActive = function()
                            itemButton = false
                        end
                    })
                    RageUI.List('Masque', {"1", "2", "3", "4", "5"}, CreaPerso.MasquePed, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.MasquePed = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'tshirt_1', CreaPerso.MasquePed-2)
                        end,
                        onActive = function()
                            itemButton = false
                        end
                    })
                    RageUI.SliderPanel(CreaPerso.VariationsHaut.ind, CreaPerso.VariationsHaut.min, "Variations", CreaPerso.VariationsHaut.max, {
                        onSliderChange = function(Index)
                            CreaPerso.VariationsHaut.ind = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'arms_2', CreaPerso.VariationsHaut.ind)
                        end
                    }, 1)
                    RageUI.SliderPanel(CreaPerso.VariationsBas.ind, CreaPerso.VariationsBas.min, "Variations", CreaPerso.VariationsBas.max, {
                        onSliderChange = function(Index)
                            CreaPerso.VariationsBas.ind = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'pants_2', CreaPerso.VariationsBas.ind)
                        end
                    }, 2)
                    RageUI.SliderPanel(CreaPerso.VariationsChapeau.ind, CreaPerso.VariationsChapeau.min, "Variations", CreaPerso.VariationsChapeau.max, {
                        onSliderChange = function(Index)
                            CreaPerso.VariationsChapeau.ind = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'helmet_2', CreaPerso.VariationsChapeau.ind)
                        end
                    }, 3)
                    RageUI.SliderPanel(CreaPerso.VariationsMasque.ind, CreaPerso.VariationsMasque.min, "Variations", CreaPerso.VariationsMasque.max, {
                        onSliderChange = function(Index)
                            CreaPerso.VariationsMasque.ind = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'tshirt_2', CreaPerso.VariationsMasque.ind)
                        end
                    }, 4)
                end)

                RageUI.IsVisible(CreaPerso.Personnage, function()
                    SetPlayerCanUseCover(PlayerId(), false)
                    if CreaPerso.Board then
                        DeleteBoard()
                        ClearPedTasks(PlayerPedId())
                        RequestAnimDict("mp_character_creation@customise@male_a")
                        TaskPlayAnim(GetPlayerPed(-1), "mp_character_creation@customise@male_a", "drop_loop", 3.0, -1.0, -1, 2, 0, 0, 0, 0)
                        CreaPerso.Board = false
                    end
                    inPrincipal = false
                    RageUI.Button("mp_m_freemode_01", false, {}, true, {
                        onActive = function()
                            if CreaPerso.SexPerso ~= 0 then
                                MadeInFrance.TriggerLocalEvent('skinchanger:change', 'sex', 0)
                                FreezeEntityPosition(player, false)
                                SetEntityCoords(GetPlayerPed(-1), 402.9375, -996.9771, -99.00025-1.0)
                                SetEntityHeading(GetPlayerPed(-1), 181.046)
                                FreezeEntityPosition(PlayerPedId(), true)
                                CreaPerso.SexPerso = 0
                                MadeInFrance.TriggerLocalEvent('skinchanger:loadSkin', {
                                    sex      = 0,
                                    tshirt_1 = 15,
                                    tshirt_2 = 0,
                                    arms     = 15,
                                    arms_2   = 0,
                                    face_ped = 0,
                                    face_ped2 = 0,
                                    torso_1  = 15,
                                    torso_2  = 0,
                                    pants_1  = 13,
                                    pants_2  = 0,
                                    shoes_1  = 33,
                                    shoes_2  = 0,
                                    helmet_1  = -1,
                                    helmet_2  = 0,
                                    glasses_1  = -1,
                                    glasses_2  = 0,
                                    chain_1 = 0,
                                    chain_2 = 0,
                                    decals_1 = 0,
                                    decals_2 = 0,
                                    bags_1 = 0,
                                    bags_2 = 0
                                })
                            end
                        end
                    })
                    RageUI.Button("mp_f_freemode_01", false, {}, true, {
                        onActive = function()
                            if CreaPerso.SexPerso ~= 1 then
                                MadeInFrance.TriggerLocalEvent('skinchanger:change', 'sex', 1)
                                FreezeEntityPosition(player, false)
                                SetEntityCoords(GetPlayerPed(-1), 402.9375, -996.9771, -99.00025-1.0)
                                SetEntityHeading(GetPlayerPed(-1), 181.046)
                                FreezeEntityPosition(PlayerPedId(), true)
                                CreaPerso.SexPerso = 1
                                MadeInFrance.TriggerLocalEvent('skinchanger:loadSkin', {
                                    sex      = 1,
                                    tshirt_1 = 15,
                                    tshirt_2 = 0,
                                    arms     = 15,
                                    arms_2   = 0,
                                    face_ped = 0,
                                    face_ped2 = 0,
                                    torso_1  = 15,
                                    torso_2  = 0,
                                    pants_1  = 14,
                                    pants_2  = 0,
                                    shoes_1  = 34,
                                    shoes_2  = 0,
                                    helmet_1  = -1,
                                    helmet_2  = 0,
                                    glasses_1  = -1,
                                    glasses_2  = 0,
                                    chain_1 = 0,
                                    chain_2 = 0,
                                    decals_1 = 0,
                                    decals_2 = 0,
                                    bags_1 = 0,
                                    bags_2 = 0
                                })
                            end
                        end
                    })
                    for k,v in pairs(CreaPerso.ListePersonage) do
                        if CreaPerso.Diamond then
                            RageUI.Button(v, false, {}, true, {
                                onActive = function()
                                    skin = k+1
                                    if CreaPerso.SexPerso ~= skin then
                                        MadeInFrance.TriggerLocalEvent('skinchanger:change', 'sex', skin)
                                        FreezeEntityPosition(player, false)
                                        SetEntityCoords(GetPlayerPed(-1), 402.9375, -996.9771, -99.00025-1.0)
                                        SetEntityHeading(GetPlayerPed(-1), 181.046)
                                        FreezeEntityPosition(PlayerPedId(), true)
                                        CreaPerso.SexPerso = skin
                                    end
                                end
                            })
                        else
                            RageUI.Button(v.name, false, {}, false, {})
                        end
                    end
                end)

                RageUI.IsVisible(CreaPerso.Identity, function()
                    DisableControlAction(0, 51, true)
                    DisableControlAction(0, 44, true)
                    inPrincipal = false
                    RageUI.Button("Prénom", nil, {RightLabel = CreaPerso.Prenom and CreaPerso.Prenom or ""}, true, {
                        onSelected = function()
                            local Input = MadeInFrance.KeyboardInput("Prénom", 15) 
                            if Input ~= nil then
                                if string.match(Input ,"%d+") then
                                    MadeInFrance.Notification("~r~Veuillez ne pas indiquer des nombres")
                                else
                                    CreaPerso.Prenom = tostring(Input)
                                end
                            end
                        end
                    })
                    RageUI.Button("Nom de famille", nil, {RightLabel = CreaPerso.NDF and CreaPerso.NDF or ""}, true, {
                        onSelected = function()
                            local Input = MadeInFrance.KeyboardInput("Nom de famille", 15) 
                            if Input ~= nil then
                                if string.match(Input ,"%d+") then
                                    MadeInFrance.Notification("~r~Veuillez ne pas indiquer des nombres")
                                else
                                    CreaPerso.NDF = tostring(Input)
                                end
                            end
                        end
                    })
                    RageUI.Button("Date de naissance", nil, {RightLabel = CreaPerso.DDN and CreaPerso.DDN or ""}, true, {
                        onSelected = function()
                            local Input = MadeInFrance.KeyboardInput("Date de naissance", 15) 
                            if Input ~= nil then
                                if not IsDateGood(Input) then
                                    MadeInFrance.Notification("~r~Veuillez indiquer une bonne date")
                                else
                                    CreaPerso.DDN = tostring(Input)
                                end
                            end
                        end
                    })
                    RageUI.Button("Sexe", nil, {RightLabel = CreaPerso.Sexe and CreaPerso.Sexe or "M/F"}, true, {
                        onSelected = function()
                            local Input = MadeInFrance.KeyboardInput("Sexe", 0) 
                            if Input ~= nil then
                                if string.match(Input ,"%d+") then
                                    MadeInFrance.Notification("~r~Veuillez ne pas indiquer des nombres")
                                else
                                    CreaPerso.Sexe = tostring(firstToUpper(Input))
                                end
                            end
                        end
                    })
                    RageUI.Button("Taille", nil, {RightLabel = CreaPerso.Taille and CreaPerso.Taille.."cm" or ""}, true, {
                        onSelected = function()
                            local Input = MadeInFrance.KeyboardInput("Taille", 3) 
                            if Input ~= nil then
                                if not string.match(Input ,"%d+") then
                                    MadeInFrance.Notification("~r~Veuillez indiquer des nombres")
                                else
                                    CreaPerso.Taille = tonumber(Input)
                                end
                            end
                        end
                    })
                    RageUI.Button("Lieu de naissance", nil, {RightLabel = CreaPerso.LDN and CreaPerso.LDN or ""}, true, {
                        onSelected = function()
                            local Input = MadeInFrance.KeyboardInput("Lieu de naissance", 15) 
                            if Input ~= nil then
                                if string.match(Input ,"%d+") then
                                    MadeInFrance.Notification("~r~Veuillez ne pas indiquer des nombres")
                                else
                                    CreaPerso.LDN = tostring(Input)
                                end
                            end
                        end
                    })
                end)

                RageUI.IsVisible(CreaPerso.TraitVisage, function()
                    inPrincipal = false
                    RageUI.Button("Largeur du nez", false, {}, true, {}) 
                    RageUI.Button("Hauteur du nez", false, {}, true, {})
                    RageUI.Button("Longueur du nez", false, {}, true, {})
                    RageUI.Button("Abaissement du nez", false, {}, true, {})
                    RageUI.Button("Abaissement pic du nez", false, {}, true, {})
                    RageUI.Button("Torsion du nez", false, {}, true, {})
                    RageUI.Button("Hauteur des sourcils", false, {}, true, {})
                    RageUI.Button("Profondeur des sourcils", false, {}, true, {})
                    RageUI.Button("Hauteur des pommettes", false, {}, true, {})
                    RageUI.Button("Largeur des pommettes", false, {}, true, {})
                    RageUI.Button("Largeur des joues", false, {}, true, {})
                    RageUI.Button("Ouverture des yeux", false, {}, true, {})
                    RageUI.Button("Épaisseur des lèvres", false, {}, true, {})
                    RageUI.Button("Largeur de la mâchoire", false, {}, true, {})
                    RageUI.Button("Longueur du dos de la mâchoire", false, {}, true, {})
                    RageUI.Button("Abaissement du menton", false, {}, true, {})
                    RageUI.Button("Longueur de l'os du menton", false, {}, true, {})
                    RageUI.Button("Largeur du menton", false, {}, true, {})
                    RageUI.Button("Trou du menton", false, {}, true, {})
                    RageUI.Button("Épaisseur du cou", false, {}, true, {})
                    RageUI.PercentagePanel(CreaPerso.Traits.LNezIndex, 'Petite (Gauche) - Grande (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.LNezIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'nose_1', Percentage*10)
                        end
                    }, 1)
                    RageUI.PercentagePanel(CreaPerso.Traits.HNezIndex, 'Haute (Gauche) - Bas (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.HNezIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'nose_2', Percentage*10)
                        end
                    }, 2)
                    RageUI.PercentagePanel(CreaPerso.Traits.LONezIndex, 'Long (Gauche) - Court (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.LONezIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'nose_3', Percentage*10)
                        end
                    }, 3)
                    RageUI.PercentagePanel(CreaPerso.Traits.ANezIndex, 'Bombé (Gauche) - Creusé (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.ANezIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'nose_4', Percentage*10)
                        end
                    }, 4)
                    RageUI.PercentagePanel(CreaPerso.Traits.APNezIndex, 'Haut (Gauche) - Bas (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.APNezIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'nose_5', Percentage*10)
                        end
                    }, 5)
                    RageUI.PercentagePanel(CreaPerso.Traits.TNezIndex1, 'Gauche', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.TNezIndex1 = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'nose_6', Percentage*10)
                        end
                    }, 6)
                    RageUI.PercentagePanel(CreaPerso.Traits.TNezIndex2, 'Droit', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.TNezIndex2 = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'nose_6', -Percentage*10)
                        end
                    }, 6)
                    RageUI.PercentagePanel(CreaPerso.Traits.HSIndex, 'Haut (Gauche) - Bas (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.HSIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'eyebrows_5', Percentage*10)
                        end
                    }, 7)
                    RageUI.PercentagePanel(CreaPerso.Traits.PSIndex, 'Creusé (Gauche) - Bombé (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.PSIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'eyebrows_6', Percentage*10)
                        end
                    }, 8)
                    RageUI.PercentagePanel(CreaPerso.Traits.HPIndex, 'Hautes (Gauche) - Basses (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.HPIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'cheeks_1', Percentage*10)
                        end
                    }, 10)
                    RageUI.PercentagePanel(CreaPerso.Traits.LPIndex, 'Fines (Gauche) - Larges (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.LPIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'cheeks_2', Percentage*10)
                        end
                    }, 9)
                    RageUI.PercentagePanel(CreaPerso.Traits.LJIndex, 'Larges (Gauche) - Fines (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.LJIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'cheeks_3', Percentage*10)
                        end
                    }, 11)
                    RageUI.PercentagePanel(CreaPerso.Traits.EOIndex, 'Ouverts (Gauche) - Fermés (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.EOIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'eye_open', Percentage*10)
                        end
                    }, 12)
                    RageUI.PercentagePanel(CreaPerso.Traits.ELIndex, 'Epaisses (Gauche) - Fines (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.ELIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'lips_thick', Percentage*10)
                        end
                    }, 13)
                    RageUI.PercentagePanel(CreaPerso.Traits.LMIndex, 'Fine (Gauche) - Large (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.LMIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'jaw_1', Percentage*10)
                        end
                    }, 14)
                    RageUI.PercentagePanel(CreaPerso.Traits.LDMIndex, 'Court (Gauche) - Long (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.LDMIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'jaw_2', Percentage*10)
                        end
                    }, 15)
                    RageUI.PercentagePanel(CreaPerso.Traits.AMIndex, 'Haut (Gauche) - Bas (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.AMIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'chin_height', Percentage*10)
                        end
                    }, 16)
                    RageUI.PercentagePanel(CreaPerso.Traits.LMOIndex, 'Court (Gauche) - Long (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.LMOIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'chin_lenght', Percentage*10)
                        end
                    }, 17)
                    RageUI.PercentagePanel(CreaPerso.Traits.LAMIndex, 'Fin (Gauche) - Large (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.LAMIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'chin_width', Percentage*10)
                        end
                    }, 18)
                    RageUI.PercentagePanel(CreaPerso.Traits.TMIndex, 'Exterieur (Gauche) - Interieur (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.TMIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'chin_hole', Percentage*10)
                        end
                    }, 19)
                    RageUI.PercentagePanel(CreaPerso.Traits.ECIndex, 'Fin (Gauche) - Large (Droite)', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.Traits.ECIndex = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'neck_thick', Percentage*10)
                        end
                    }, 20)
                end)

                RageUI.IsVisible(CreaPerso.CharHeritageMenu, function()
                    inPrincipal = false
                    RageUI.Window.Heritage(CreaPerso.actionMother, CreaPerso.actionFather)
                    RageUI.List("Mère", CreaPerso.MotherListCreator, CreaPerso.actionMother, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.actionMother = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'mom', CreaPerso.actionMother-1)
                        end,
                    })

                    RageUI.List("Père", CreaPerso.FatherListCreator, CreaPerso.actionFather, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.actionFather = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'dad', CreaPerso.actionFather-1)
                        end,
                    })
                    RageUI.UISliderHeritage('Ressemblance', CreaPerso.actionRessemblance, nil, {
                        onSliderChange = function(Float, Index)
                            CreaPerso.actionRessemblance = Index;
                            ressemblance = Float
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'face', ressemblance)
                        end,
                    })
                    RageUI.UISliderHeritage('Teint de peau', CreaPerso.actionPeau, nil, {
                        onSliderChange = function(Float, Index)
                            CreaPerso.actionPeau = Index;
                            CreaPerso.CouleurPeau = Float
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'skin', CreaPerso.CouleurPeau*2)
                        end,
                    })
                end)

                RageUI.IsVisible(CreaPerso.Appearance, function()
                    if itemButton then
                        if not inCamera then
                            CreatorZoomIn(GetCreatorCam())
                            inCamera = true
                        end
                    else
                        if inCamera then
                            CreatorZoomOut(GetCreatorCam())
                            inCamera = false
                        end
                    end
                    inPrincipal = false
                    RageUI.List('Liste des coiffures', CreaPerso.HairValue, CreaPerso.HairListingIndex, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.HairListingIndex = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'hair_1', CreaPerso.HairListingIndex-1)
                        end,
                        onActive = function()
                            itemButton = true
                        end
                    })
                    RageUI.List('Couleur des yeux', CreaPerso.EyesValue, CreaPerso.EyesListingIndex, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.EyesListingIndex = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'eye_color', CreaPerso.EyesListingIndex)
                        end,
                        onActive = function()
                            itemButton = true
                        end
                    })
                    RageUI.List('Liste des barbes', CreaPerso.BeardValue, CreaPerso.BeardListingIndex, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.BeardListingIndex = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'beard_1', CreaPerso.BeardListingIndex)
                        end,
                        onActive = function()
                            itemButton = true
                        end
                    })
                    RageUI.List('Pilosité torse', CreaPerso.ChestValue, CreaPerso.ChestListingIndex, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.ChestListingIndex = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'chest_1', CreaPerso.ChestListingIndex)
                        end,
                        onActive = function()
                            itemButton = false
                        end
                    })
                    RageUI.List('Liste des sourcils', CreaPerso.EyebrowValue, CreaPerso.EyebrownListingIndex, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.EyebrownListingIndex = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'eyebrows_1', CreaPerso.EyebrownListingIndex)
                        end,
                        onActive = function()
                            itemButton = true
                        end
                    })
                    RageUI.List('Liste des rides', CreaPerso.WrinklesValue, CreaPerso.WrinklesListingIndex, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.WrinklesListingIndex = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'age_1', CreaPerso.WrinklesListingIndex)
                        end,
                        onActive = function()
                            itemButton = true
                        end
                    })
                    RageUI.List('Taches corps', {"1","2","3","4","5","6","7","8","9","10","11"}, CreaPerso.BodyblemishesListingIndex, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.BodyblemishesListingIndex = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'bodyb_1', CreaPerso.BodyblemishesListingIndex)
                        end,
                        onActive = function()
                            itemButton = false
                        end
                    })
                    RageUI.List('Taches cutanées', CreaPerso.FrecklesValue, CreaPerso.FrecklesListingIndex, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.FrecklesListingIndex = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'moles_1', CreaPerso.FrecklesListingIndex)
                        end,
                        onActive = function()
                            itemButton = true
                        end
                    })
                    RageUI.List('Dommage solaire', CreaPerso.SunValue, CreaPerso.SunListingIndex, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.SunListingIndex = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'sun_1', CreaPerso.SunListingIndex)
                        end,
                        onActive = function()
                            itemButton = true
                        end
                    })
                    -- [Percentage Panel]
                    RageUI.PercentagePanel(CreaPerso.FrecklesListingIndex2, 'Opacité', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.FrecklesListingIndex2 = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'moles_2', Percentage*10)
                        end
                    }, 9)
                    RageUI.PercentagePanel(CreaPerso.SunListingIndex2, 'Opacité', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.SunListingIndex2 = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'sun_2', Percentage*10)
                        end
                    }, 8)
                    RageUI.PercentagePanel(CreaPerso.BodyblemishesListingIndex2, 'Opacité', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.BodyblemishesListingIndex2 = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'bodyb_2', Percentage*10)
                        end
                    }, 7)
                    RageUI.PercentagePanel(CreaPerso.WrinklesListingIndex2, 'Opacité', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.WrinklesListingIndex2 = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'age_2', Percentage*10)
                        end
                    }, 6)
                    RageUI.PercentagePanel(CreaPerso.ChestListingIndex2, 'Pilosité', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.ChestListingIndex2 = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'chest_2', Percentage*10)
                        end
                    }, 4)
                    RageUI.PercentagePanel(CreaPerso.EyebrownListingIndex2, 'Opacité', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.EyebrownListingIndex2 = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'eyebrows_2', Percentage*10)
                        end
                    }, 5)
                    RageUI.ColourPanel("Couleur de cheveux", RageUI.PanelColour.HairCut, CreaPerso.Color.Hair[1], CreaPerso.Color.Hair[2], {
                        onColorChange = function(MinimumIndex, CurrentIndex)
                            CreaPerso.Color.Hair[1] = MinimumIndex
                            CreaPerso.Color.Hair[2] = CurrentIndex
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'hair_color_1', CurrentIndex-1)
                        end
                    }, 1)
                    RageUI.ColourPanel("Couleur de cheveux 2", RageUI.PanelColour.HairCut, CreaPerso.Color.Hair2[1], CreaPerso.Color.Hair2[2], {
                        onColorChange = function(MinimumIndex, CurrentIndex)
                            CreaPerso.Color.Hair2[1] = MinimumIndex
                            CreaPerso.Color.Hair2[2] = CurrentIndex
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'hair_color_2', CurrentIndex-1)
                        end
                    }, 1)
                    RageUI.PercentagePanel(CreaPerso.BeardListingIndex2, 'Taille de la barbe', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.BeardListingIndex2 = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'beard_2', Percentage*10)
                        end
                    }, 3)
                    RageUI.ColourPanel("Couleur de barbe", RageUI.PanelColour.HairCut, CreaPerso.Color.Beard[1], CreaPerso.Color.Beard[2], {
                        onColorChange = function(MinimumIndex, CurrentIndex)
                            CreaPerso.Color.Beard[1] = MinimumIndex
                            CreaPerso.Color.Beard[2] = CurrentIndex
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'beard_3', CurrentIndex-1)
                        end
                    }, 3)
                    RageUI.ColourPanel("Couleur des sourcils", RageUI.PanelColour.HairCut, CreaPerso.Color.EyeBrows[1], CreaPerso.Color.EyeBrows[2], {
                        onColorChange = function(MinimumIndex, CurrentIndex)
                            CreaPerso.Color.EyeBrows[1] = MinimumIndex
                            CreaPerso.Color.EyeBrows[2] = CurrentIndex
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'eyebrows_3', CurrentIndex-1)
                        end
                    }, 5)
                end)

                RageUI.IsVisible(CreaPerso.Makeup, function()
                    inPrincipal = false
                    RageUI.List('Visage', CreaPerso.MakeupValue, CreaPerso.MakeupListingIndex, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.MakeupListingIndex = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'makeup_1', CreaPerso.MakeupListingIndex-2)
                        end
                    })
                    RageUI.List('Rouge à lèvres', CreaPerso.LipstickValue, CreaPerso.LipstickListingIndex, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.LipstickListingIndex = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'lipstick_1', CreaPerso.LipstickListingIndex-2)
                        end
                    })
                    RageUI.List('Teint', CreaPerso.ComplexionValue, CreaPerso.ComplexionListingIndex, nil, {}, true, {
                        onListChange = function(Index)
                            CreaPerso.ComplexionListingIndex = Index
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'complexion_1', CreaPerso.ComplexionListingIndex-2)
                        end
                    })
                    RageUI.ColourPanel("Couleur du makeup", RageUI.PanelColour.HairCut, CreaPerso.Color.Makeup[1], CreaPerso.Color.Makeup[2], {
                        onColorChange = function(MinimumIndex, CurrentIndex)
                            CreaPerso.Color.Makeup[1] = MinimumIndex
                            CreaPerso.Color.Makeup[2] = CurrentIndex
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'makeup_3', CurrentIndex-1)
                        end
                    }, 1)
                    RageUI.ColourPanel("Couleur du rouge à lèvres", RageUI.PanelColour.HairCut, CreaPerso.Color.Makeup[1], CreaPerso.Color.Makeup[2], {
                        onColorChange = function(MinimumIndex, CurrentIndex)
                            CreaPerso.Color.Makeup[1] = MinimumIndex
                            CreaPerso.Color.Makeup[2] = CurrentIndex
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'lipstick_3', CurrentIndex-1)
                        end
                    }, 2)
                    -- [Percentage Panel]
                    RageUI.PercentagePanel(CreaPerso.MakeupListingIndex2, 'Opacité', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.MakeupListingIndex2 = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'makeup_2', Percentage*10)
                        end
                    }, 1)
                    RageUI.PercentagePanel(CreaPerso.LipstickListingIndex2, 'Opacité', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.LipstickListingIndex2 = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'lipstick_2', Percentage*10)
                        end
                    }, 2)
                    RageUI.PercentagePanel(CreaPerso.ComplexionListingIndex2, 'Opacité', '0', '10', {
                        onProgressChange = function(Percentage)
                            CreaPerso.ComplexionListingIndex2 = Percentage
                            MadeInFrance.TriggerLocalEvent('skinchanger:change', 'complexion_2', Percentage*10)
                        end
                    }, 3)
                end)
                Wait(1)
            end
        end)
    end
end

function Disable()
    DisableControlAction(0, 138, true)
    DisableControlAction(0, 0, true)
    DisableControlAction(0, 0, true)
    DisableControlAction(0, 0, true)
    DisableControlAction(0, 1, true)
    DisableControlAction(0, 2, true)
    DisableControlAction(0, 6, true)
    DisableControlAction(0, 288, true)
    DisableControlAction(0, 318, true)
    DisableControlAction(0, 168, true)
    DisableControlAction(0, 327, true)
    DisableControlAction(0, 166, true)
    DisableControlAction(0, 289, true)
    DisableControlAction(0, 305, true)
    DisableControlAction(0, 331, true)
    DisableControlAction(0, 330, true)
    DisableControlAction(0, 329, true)
    DisableControlAction(0, 132, true)
    DisableControlAction(0, 246, true)
    DisableControlAction(0, 36, true)
    DisableControlAction(0, 18, true)
    DisableControlAction(0, 106, true)
    DisableControlAction(0, 122, true)
    DisableControlAction(0, 135, true)
    DisableControlAction(0, 218, true)
    DisableControlAction(0, 200, true)
    DisableControlAction(0, 219, true)
    DisableControlAction(0, 220, true)
    DisableControlAction(0, 221, true)
    DisableControlAction(0, 202, true)
    DisableControlAction(0, 199, true)
    DisableControlAction(0, 177, true)
    DisableControlAction(0, 19, true) -- INPUT_CHARACTER_WHEEL
    DisableControlAction(0, 22, true) -- INPUT_JUMP
    DisableControlAction(0, 23, true) -- INPUT_ENTER
    DisableControlAction(0, 24, true) -- INPUT_ATTACK
    DisableControlAction(0, 25, true) -- INPUT_AIM
    DisableControlAction(0, 26, true) -- INPUT_LOOK_BEHIND
    DisableControlAction(0, 38, true) -- INPUT KEY
    --DisableControlAction(0, 44, true) -- INPUT_COVER
    DisableControlAction(0, 45, true) -- INPUT_RELOAD
    DisableControlAction(0, 50, true) -- INPUT_ACCURATE_AIM
    --DisableControlAction(0, 51, true) -- CONTEXT KEY
    DisableControlAction(0, 58, true) -- INPUT_THROW_GRENADE
    DisableControlAction(0, 59, true) -- INPUT_VEH_MOVE_LR
    DisableControlAction(0, 60, true) -- INPUT_VEH_MOVE_UD
    DisableControlAction(0, 61, true) -- INPUT_VEH_MOVE_UP_ONLY
    DisableControlAction(0, 62, true) -- INPUT_VEH_MOVE_DOWN_ONLY
    DisableControlAction(0, 63, true) -- INPUT_VEH_MOVE_LEFT_ONLY
    DisableControlAction(0, 64, true) -- INPUT_VEH_MOVE_RIGHT_ONLY
    DisableControlAction(0, 65, true) -- INPUT_VEH_SPECIAL
    DisableControlAction(0, 66, true) -- INPUT_VEH_GUN_LR
    DisableControlAction(0, 67, true) -- INPUT_VEH_GUN_UD
    DisableControlAction(0, 68, true) -- INPUT_VEH_AIM
    DisableControlAction(0, 69, true) -- INPUT_VEH_ATTACK
    DisableControlAction(0, 70, true) -- INPUT_VEH_ATTACK2
    DisableControlAction(0, 71, true) -- INPUT_VEH_ACCELERATE
    DisableControlAction(0, 72, true) -- INPUT_VEH_BRAKE
    DisableControlAction(0, 73, true) -- INPUT_VEH_DUCK
    DisableControlAction(0, 74, true) -- INPUT_VEH_HEADLIGHT
    DisableControlAction(0, 75, true) -- INPUT_VEH_EXIT
    DisableControlAction(0, 76, true) -- INPUT_VEH_HANDBRAKE
    DisableControlAction(0, 86, true) -- INPUT_VEH_HORN
    DisableControlAction(0, 92, true) -- INPUT_VEH_PASSENGER_ATTACK
    DisableControlAction(0, 114, true) -- INPUT_VEH_FLY_ATTACK
    DisableControlAction(0, 140, true) -- INPUT_MELEE_ATTACK_LIGHT
    DisableControlAction(0, 141, true) -- INPUT_MELEE_ATTACK_HEAVY
    DisableControlAction(0, 261, true) -- INPUT_PREV_WEAPON
    DisableControlAction(0, 262, true) -- INPUT_NEXT_WEAPON
    DisableControlAction(0, 263, true) -- INPUT_MELEE_ATTACK1
    DisableControlAction(0, 264, true) -- INPUT_MELEE_ATTACK2
    DisableControlAction(0, 142, true) -- INPUT_MELEE_ATTACK_ALTERNATE
    DisableControlAction(0, 143, true) -- INPUT_MELEE_BLOCK
    DisableControlAction(0, 144, true) -- PARACHUTE DEPLOY
    DisableControlAction(0, 145, true) -- PARACHUTE DETACH
    DisableControlAction(0, 156, true) -- INPUT_MAP
    DisableControlAction(0, 157, true) -- INPUT_SELECT_WEAPON_UNARMED
    DisableControlAction(0, 158, true) -- INPUT_SELECT_WEAPON_MELEE
    DisableControlAction(0, 159, true) -- INPUT_SELECT_WEAPON_HANDGUN
    DisableControlAction(0, 160, true) -- INPUT_SELECT_WEAPON_SHOTGUN
    DisableControlAction(0, 161, true) -- INPUT_SELECT_WEAPON_SMG
    DisableControlAction(0, 162, true) -- INPUT_SELECT_WEAPON_AUTO_RIFLE
    DisableControlAction(0, 243, true) -- INPUT_ENTER_CHEAT_CODE
    DisableControlAction(0, 257, true) -- INPUT_ATTACK2
    DisableControlAction(0, 183, true) -- GCPHONE
    DisableControlAction(0, 244, true) -- GCPHONE
    DisableControlAction(0, 163, true) -- INPUT_SELECT_WEAPON_SNIPER
    DisableControlAction(0, 164, true) -- INPUT_SELECT_WEAPON_HEAVY
    DisableControlAction(0, 165, true) -- INPUT_SELECT_WEAPON_SPECIAL
    DrawScaleformMovieFullscreen(setupScaleform(), 255, 255, 255, 255, 0)
end
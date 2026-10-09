-- Repris de config/models.lua de mnr_sitanywhere (MIT, github.com/Monarch-Devs/mnr_sitanywhere) : props calibrés en jeu (offset local x, y, z, heading par place).

Sit = Sit or {}
Sit.Models = {
	[`apa_mp_h_din_chair_04`] = {
		name = 'apa_mp_h_din_chair_04',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`apa_mp_h_din_chair_08`] = {
		name = 'apa_mp_h_din_chair_08',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`apa_mp_h_din_chair_09`] = {
		name = 'apa_mp_h_din_chair_09',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.1, 0.5, 180.0),
		},
	},
	[`apa_mp_h_din_chair_12`] = {
		name = 'apa_mp_h_din_chair_12',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairarm_01`] = {
		name = 'apa_mp_h_stn_chairarm_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairarm_02`] = {
		name = 'apa_mp_h_stn_chairarm_02',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.5, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairarm_03`] = {
		name = 'apa_mp_h_stn_chairarm_03',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.4, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairarm_09`] = {
		name = 'apa_mp_h_stn_chairarm_09',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.3, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairarm_11`] = {
		name = 'apa_mp_h_stn_chairarm_11',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.3, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairarm_12`] = {
		name = 'apa_mp_h_stn_chairarm_12',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairarm_13`] = {
		name = 'apa_mp_h_stn_chairarm_13',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.45, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairarm_23`] = {
		name = 'apa_mp_h_stn_chairarm_23',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairarm_24`] = {
		name = 'apa_mp_h_stn_chairarm_24',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.45, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairarm_25`] = {
		name = 'apa_mp_h_stn_chairarm_25',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.3, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairarm_26`] = {
		name = 'apa_mp_h_stn_chairarm_26',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.7, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairstool_12`] = {
		name = 'apa_mp_h_stn_chairstool_12',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.1, 0.45, 180.0),
		},
	},
	[`apa_mp_h_stn_chairstrip_01`] = {
		name = 'apa_mp_h_stn_chairstrip_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairstrip_02`] = {
		name = 'apa_mp_h_stn_chairstrip_02',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairstrip_03`] = {
		name = 'apa_mp_h_stn_chairstrip_03',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairstrip_04`] = {
		name = 'apa_mp_h_stn_chairstrip_04',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairstrip_05`] = {
		name = 'apa_mp_h_stn_chairstrip_05',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairstrip_06`] = {
		name = 'apa_mp_h_stn_chairstrip_06',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairstrip_07`] = {
		name = 'apa_mp_h_stn_chairstrip_07',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`apa_mp_h_stn_chairstrip_08`] = {
		name = 'apa_mp_h_stn_chairstrip_08',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`apa_mp_h_yacht_armchair_03`] = {
		name = 'apa_mp_h_yacht_armchair_03',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`apa_mp_h_yacht_armchair_04`] = {
		name = 'apa_mp_h_yacht_armchair_04',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`apa_mp_h_yacht_strip_chair_01`] = {
		name = 'apa_mp_h_yacht_strip_chair_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.2, 0.5, 180.0),
		},
	},
	[`ba_prop_battle_club_chair_01`] = {
		name = 'ba_prop_battle_club_chair_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.05, -0.08, 180.0),
		},
	},
	[`ba_prop_battle_club_chair_02`] = {
		name = 'ba_prop_battle_club_chair_02',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, -0.1, 180.0),
		},
	},
	[`ba_prop_battle_club_chair_03`] = {
		name = 'ba_prop_battle_club_chair_03',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, -0.1, 180.0),
		},
	},
	[`bkr_int_02_chair_bar_table_01`] = {
		name = 'bkr_int_02_chair_bar_table_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.4, 180.0),
		},
	},
	[`bkr_int_02_chair_bar_table_02`] = {
		name = 'bkr_int_02_chair_bar_table_02',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.4, 180.0),
		},
	},
	[`bkr_int_02_strip_chair`] = {
		name = 'bkr_int_02_strip_chair',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`bkr_prop_biker_boardchair01`] = {
		name = 'bkr_prop_biker_boardchair01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, -0.1, 180.0),
		},
	},
	[`bkr_prop_biker_chair_01`] = {
		name = 'bkr_prop_biker_chair_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`bkr_prop_biker_chairstrip_01`] = {
		name = 'bkr_prop_biker_chairstrip_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`bkr_prop_biker_chairstrip_02`] = {
		name = 'bkr_prop_biker_chairstrip_02',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`bkr_prop_clubhouse_armchair_01a`] = {
		name = 'bkr_prop_clubhouse_armchair_01a',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.75, -0.2, 0.5, 180.0),
		},
	},
	[`bkr_prop_clubhouse_chair_01`] = {
		name = 'bkr_prop_clubhouse_chair_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, -0.1, 180.0),
		},
	},
	[`bkr_prop_clubhouse_chair_03`] = {
		name = 'bkr_prop_clubhouse_chair_03',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`bkr_prop_clubhouse_offchair_01a`] = {
		name = 'bkr_prop_clubhouse_offchair_01a',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, -0.1, 180.0),
		},
	},
	[`bkr_prop_weed_chair_01a`] = {
		name = 'bkr_prop_weed_chair_01a',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`ch_prop_casino_chair_01a`] = {
		name = 'ch_prop_casino_chair_01a',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.8, 0.0),
		},
	},
	[`ch_prop_casino_chair_01b`] = {
		name = 'ch_prop_casino_chair_01b',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.7, 0.0),
		},
	},
	[`ch_prop_casino_chair_01c`] = {
		name = 'ch_prop_casino_chair_01c',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.07, -0.05, 0.8, 270.0),
		},
	},
	[`ch_prop_casino_track_chair_01`] = {
		name = 'ch_prop_casino_track_chair_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.1, 0.5, 180.0),
		},
	},
	[`ex_mp_h_din_chair_04`] = {
		name = 'ex_mp_h_din_chair_04',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`ex_mp_h_din_chair_08`] = {
		name = 'ex_mp_h_din_chair_08',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`ex_mp_h_din_chair_09`] = {
		name = 'ex_mp_h_din_chair_09',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.1, 0.5, 180.0),
		},
	},
	[`ex_mp_h_din_chair_12`] = {
		name = 'ex_mp_h_din_chair_12',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`ex_mp_h_stn_chairarm_03`] = {
		name = 'ex_mp_h_stn_chairarm_03',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.2, 0.5, 180.0),
		},
	},
	[`ex_mp_h_stn_chairarm_24`] = {
		name = 'ex_mp_h_stn_chairarm_24',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.3, 0.5, 180.0),
		},
	},
	[`ex_mp_h_stn_chairstrip_01`] = {
		name = 'ex_mp_h_stn_chairstrip_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.05, 0.5, 180.0),
		},
	},
	[`ex_mp_h_stn_chairstrip_07`] = {
		name = 'ex_mp_h_stn_chairstrip_07',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`ex_mp_h_stn_chairstrip_010`] = {
		name = 'ex_mp_h_stn_chairstrip_010',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`ex_mp_h_stn_chairstrip_011`] = {
		name = 'ex_mp_h_stn_chairstrip_011',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`ex_prop_offchair_exec_03`] = {
		name = 'ex_prop_offchair_exec_03',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.05, -0.1, 180.0),
		},
	},
	[`hei_prop_hei_skid_chair`] = {
		name = 'hei_prop_hei_skid_chair',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.1, 180.0),
		},
	},
	[`hei_prop_heist_off_chair`] = {
		name = 'hei_prop_heist_off_chair',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`hei_prop_yah_seat_01`] = {
		name = 'hei_prop_yah_seat_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.6, 180.0),
		},
	},
	[`hei_prop_yah_seat_02`] = {
		name = 'hei_prop_yah_seat_02',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.6, 180.0),
		},
	},
	[`hei_prop_yah_seat_03`] = {
		name = 'hei_prop_yah_seat_03',
		maxSeats = 2,
		action = 'bench',
		seats = {
			[1] = vec4(0.4, 0.0, 0.6, 180.0),
			[2] = vec4(-0.4, 0.0, 0.6, 180.0),
		},
	},
	[`p_armchair_01_s`] = {
		name = 'p_armchair_01_s',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
		},
	},
	[`p_clb_officechair_s`] = {
		name = 'p_clb_officechair_s',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`p_dinechair_01_s`] = {
		name = 'p_dinechair_01_s',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`p_ilev_p_easychair_s`] = {
		name = 'p_ilev_p_easychair_s',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.55, 180.0),
		},
	},
	[`p_yacht_chair_01_s`] = {
		name = 'p_yacht_chair_01_s',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.0, 180.0),
		},
	},
	[`p_yacht_sofa_01_s`] = {
		name = 'p_yacht_sofa_01_s',
		maxSeats = 2,
		action = 'bench',
		seats = {
			[1] = vec4(0.4, 0.0, 0.0, 180.0),
			[2] = vec4(-0.4, 0.0, 0.0, 180.0),
		},
	},
	[`prop_armchair_01`] = {
		name = 'prop_armchair_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`prop_bar_stool_01`] = {
		name = 'prop_bar_stool_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.1, 0.8, 180.0),
		},
	},
	[`prop_bench_01a`] = {
		name = 'prop_bench_01a',
		maxSeats = 3,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.05, 0.5, 180.0),
			[2] = vec4(-0.7, -0.05, 0.5, 180.0),
			[3] = vec4(0.7, -0.05, 0.5, 180.0),
		},
	},
	[`prop_bench_01b`] = {
		name = 'prop_bench_01b',
		maxSeats = 3,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.05, 0.5, 180.0),
			[2] = vec4(-0.7, -0.05, 0.5, 180.0),
			[3] = vec4(0.7, -0.05, 0.5, 180.0),
		},
	},
	[`prop_bench_01c`] = {
		name = 'prop_bench_01c',
		maxSeats = 3,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.05, 0.5, 180.0),
			[2] = vec4(-0.7, -0.05, 0.5, 180.0),
			[3] = vec4(0.7, -0.05, 0.5, 180.0),
		},
	},
	[`prop_bench_02`] = {
		name = 'prop_bench_02',
		maxSeats = 3,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.05, 0.5, 180.0),
			[2] = vec4(-0.7, -0.05, 0.5, 180.0),
			[3] = vec4(0.7, -0.05, 0.5, 180.0),
		},
	},
	[`prop_bench_03`] = {
		name = 'prop_bench_03',
		maxSeats = 2,
		action = 'bench',
		seats = {
			[1] = vec4(-0.5, -0.02, 0.4, 180.0),
			[2] = vec4(0.5, -0.02, 0.4, 180.0),
		},
	},
	[`prop_bench_04`] = {
		name = 'prop_bench_04',
		maxSeats = 2,
		action = 'bench',
		seats = {
			[1] = vec4(-0.6, -0.02, 0.5, 180.0),
			[2] = vec4(0.6, -0.02, 0.5, 180.0),
		},
	},
	[`prop_bench_05`] = {
		name = 'prop_bench_05',
		maxSeats = 3,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.05, 0.45, 180.0),
			[2] = vec4(-0.9, -0.05, 0.45, 180.0),
			[3] = vec4(0.9, -0.05, 0.45, 180.0),
		},
	},
	[`prop_bench_06`] = {
		name = 'prop_bench_06',
		maxSeats = 3,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
			[2] = vec4(-0.9, 0.0, 0.5, 180.0),
			[3] = vec4(0.9, 0.0, 0.5, 180.0),
		},
	},
	[`prop_bench_07`] = {
		name = 'prop_bench_07',
		maxSeats = 3,
		action = 'bench',
		seats = {
			[1] = vec4(0.95, -0.12, 0.51, 180.0),
			[2] = vec4(0.0, -0.12, 0.51, 180.0),
			[3] = vec4(1.9, -0.12, 0.51, 180.0),
		},
	},
	[`prop_bench_08`] = {
		name = 'prop_bench_08',
		maxSeats = 2,
		action = 'bench',
		seats = {
			[1] = vec4(-0.7, 0.05, 0.45, 180.0),
			[2] = vec4(0.7, 0.05, 0.45, 180.0),
		},
	},
	[`prop_bench_09`] = {
		name = 'prop_bench_09',
		maxSeats = 3,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.05, 0.3, 180.0),
			[2] = vec4(-0.8, -0.05, 0.3, 180.0),
			[3] = vec4(0.8, -0.05, 0.3, 180.0),
		},
	},
	[`prop_bench_10`] = {
		name = 'prop_bench_10',
		maxSeats = 3,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.5, 180.0),
			[2] = vec4(-0.9, -0.1, 0.5, 180.0),
			[3] = vec4(0.9, -0.1, 0.5, 180.0),
		},
	},
	[`prop_bench_11`] = {
		name = 'prop_bench_11',
		maxSeats = 3,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.4, 180.0),
			[2] = vec4(-0.9, 0.0, 0.4, 180.0),
			[3] = vec4(0.9, 0.0, 0.4, 180.0),
		},
	},
	[`prop_chair_01a`] = {
		name = 'prop_chair_01a',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.08, 0.5, 180.0),
		},
	},
	[`prop_chair_01b`] = {
		name = 'prop_chair_01b',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.02, 0.5, 180.0),
		},
	},
	[`prop_chair_02`] = {
		name = 'prop_chair_02',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.02, 0.5, 180.0),
		},
	},
	[`prop_chair_03`] = {
		name = 'prop_chair_03',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.02, 0.5, 180.0),
		},
	},
	[`prop_chair_04a`] = {
		name = 'prop_chair_04a',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.02, 0.5, 180.0),
		},
	},
	[`prop_chair_04b`] = {
		name = 'prop_chair_04b',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.02, 0.5, 180.0),
		},
	},
	[`prop_chair_05`] = {
		name = 'prop_chair_05',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.02, 0.5, 180.0),
		},
	},
	[`prop_chair_06`] = {
		name = 'prop_chair_06',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`prop_chair_07`] = {
		name = 'prop_chair_07',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`prop_chair_08`] = {
		name = 'prop_chair_08',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.0, 180.0),
		},
	},
	[`prop_chair_09`] = {
		name = 'prop_chair_09',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`prop_chair_10`] = {
		name = 'prop_chair_10',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`prop_chateau_chair_01`] = {
		name = 'prop_chateau_chair_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.0, 180.0),
		},
	},
	[`prop_clown_chair`] = {
		name = 'prop_clown_chair',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.25, 0.3, 0.5, 180.0),
		},
	},
	[`prop_cs_office_chair`] = {
		name = 'prop_cs_office_chair',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`prop_direct_chair_01`] = {
		name = 'prop_direct_chair_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.05, 0.2, 180.0),
		},
	},
	[`prop_direct_chair_02`] = {
		name = 'prop_direct_chair_02',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.05, 0.2, 180.0),
		},
	},
	[`prop_gc_chair02`] = {
		name = 'prop_gc_chair02',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.0, 180.0),
		},
	},
	[`prop_ld_farm_chair01`] = {
		name = 'prop_ld_farm_chair01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.1, 0.0, 0.0),
		},
	},
	[`prop_off_chair_01`] = {
		name = 'prop_off_chair_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`prop_off_chair_03`] = {
		name = 'prop_off_chair_03',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.45, 180.0),
		},
	},
	[`prop_off_chair_04`] = {
		name = 'prop_off_chair_04',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.45, 180.0),
		},
	},
	[`prop_off_chair_04_s`] = {
		name = 'prop_off_chair_04_s',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`prop_off_chair_05`] = {
		name = 'prop_off_chair_05',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.45, 180.0),
		},
	},
	[`prop_old_deck_chair`] = {
		name = 'prop_old_deck_chair',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, -0.1, 180.0),
		},
	},
	[`prop_old_wood_chair`] = {
		name = 'prop_old_wood_chair',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.1, 180.0),
		},
	},
	[`prop_rock_chair_01`] = {
		name = 'prop_rock_chair_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.1, 180.0),
		},
	},
	[`prop_skid_chair_01`] = {
		name = 'prop_skid_chair_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.1, 180.0),
		},
	},
	[`prop_skid_chair_02`] = {
		name = 'prop_skid_chair_02',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.1, 180.0),
		},
	},
	[`prop_skid_chair_03`] = {
		name = 'prop_skid_chair_03',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.1, 180.0),
		},
	},
	[`prop_sol_chair`] = {
		name = 'prop_sol_chair',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`prop_stool_01`] = {
		name = 'prop_stool_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.1, 0.8, 180.0),
		},
	},
	[`prop_t_sofa`] = {
		name = 'prop_t_sofa',
		maxSeats = 2,
		action = 'sunlounger',
		seats = {
			[1] = vec4(0.5, 0.15, 0.05, 180.0),
			[2] = vec4(-0.5, 0.0, 0.05, 180.0),
		},
	},
	[`prop_t_sofa_02`] = {
		name = 'prop_t_sofa_02',
		maxSeats = 2,
		action = 'sunlounger',
		seats = {
			[1] = vec4(0.5, 0.0, 0.05, 180.0),
			[2] = vec4(-0.5, -0.1, 0.05, 180.0),
		},
	},
	[`prop_table_01_chr_a`] = {
		name = 'prop_table_01_chr_a',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.05, 0.0, 180.0),
		},
	},
	[`prop_toilet_01`] = {
		name = 'prop_toilet_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`prop_ven_market_stool`] = {
		name = 'prop_ven_market_stool',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.1, 0.25, 180.0),
		},
	},
	[`prop_waiting_seat_01`] = {
		name = 'prop_waiting_seat_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`prop_yacht_seat_01`] = {
		name = 'prop_yacht_seat_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.6, 180.0),
		},
	},
	[`prop_yacht_seat_02`] = {
		name = 'prop_yacht_seat_02',
		maxSeats = 2,
		action = 'bench',
		seats = {
			[1] = vec4(0.4, 0.0, 0.6, 180.0),
			[2] = vec4(-0.4, 0.0, 0.6, 180.0),
		},
	},
	[`prop_yacht_seat_03`] = {
		name = 'prop_yacht_seat_03',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.6, 180.0),
		},
	},
	[`prop_yaught_chair_01`] = {
		name = 'prop_yaught_chair_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.0, 180.0),
		},
	},
	[`prop_yaught_sofa_01`] = {
		name = 'prop_yaught_sofa_01',
		maxSeats = 2,
		action = 'bench',
		seats = {
			[1] = vec4(-0.3, -0.05, 0.0, 180.0),
			[2] = vec4(0.3, -0.05, 0.0, 180.0),
		},
	},
	[`sf_prop_sf_sofa_chefield_01a`] = {
		name = 'sf_prop_sf_sofa_chefield_01a',
		maxSeats = 2,
		action = 'bench',
		seats = {
			[1] = vec4(0.4, 0.0, 0.5, 180.0),
			[2] = vec4(-0.4, 0.0, 0.5, 180.0),
		},
	},
	[`sf_prop_sf_sofa_chefield_02a`] = {
		name = 'sf_prop_sf_sofa_chefield_02a',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`v_club_officechair`] = {
		name = 'v_club_officechair',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`v_corp_bk_chair1`] = {
		name = 'v_corp_bk_chair1',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.1, 0.13, 180.0),
		},
	},
	[`v_corp_bk_chair2`] = {
		name = 'v_corp_bk_chair2',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.0, 180.0),
		},
	},
	[`v_corp_bk_chair3`] = {
		name = 'v_corp_bk_chair3',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`v_corp_cd_chair`] = {
		name = 'v_corp_cd_chair',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`v_corp_lazychair`] = {
		name = 'v_corp_lazychair',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`v_corp_lazychairfd`] = {
		name = 'v_corp_lazychairfd',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`v_corp_offchair`] = {
		name = 'v_corp_offchair',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`v_corp_offchairfd`] = {
		name = 'v_corp_offchairfd',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`v_corp_sidechair`] = {
		name = 'v_corp_sidechair',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`v_corp_sidechairfd`] = {
		name = 'v_corp_sidechairfd',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`v_ilev_chair02_ped`] = {
		name = 'v_ilev_chair02_ped',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.0, 180.0),
		},
	},
	[`v_ilev_fh_kitchenstool`] = {
		name = 'v_ilev_fh_kitchenstool',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.1, 0.9, 180.0),
		},
	},
	[`v_ilev_hd_chair`] = {
		name = 'v_ilev_hd_chair',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.65, 180.0),
		},
	},
	[`v_ilev_m_dinechair`] = {
		name = 'v_ilev_m_dinechair',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`v_ilev_p_easychair`] = {
		name = 'v_ilev_p_easychair',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.55, 180.0),
		},
	},
	[`v_ilev_tort_stool`] = {
		name = 'v_ilev_tort_stool',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.1, 0.15, 180.0),
		},
	},
	[`v_ret_gc_chair03`] = {
		name = 'v_ret_gc_chair03',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, -0.1, 180.0),
		},
	},
	[`v_tre_sofa_mess_b_s`] = {
		name = 'v_tre_sofa_mess_b_s',
		maxSeats = 2,
		action = 'bench',
		seats = {
			[1] = vec4(0.5, 0.0, 0.5, 180.0),
			[2] = vec4(-0.5, 0.0, 0.5, 180.0),
		},
	},
	[`v_tre_sofa_mess_c_s`] = {
		name = 'v_tre_sofa_mess_c_s',
		maxSeats = 2,
		action = 'bench',
		seats = {
			[1] = vec4(0.5, 0.0, 0.5, 180.0),
			[2] = vec4(-0.5, 0.0, 0.5, 180.0),
		},
	},
	[`vw_prop_casino_chair_01a`] = {
		name = 'vw_prop_casino_chair_01a',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, -0.05, 0.8, 0.0),
		},
	},
	[`vw_prop_casino_track_chair_01`] = {
		name = 'vw_prop_casino_track_chair_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.05, 0.5, 180.0),
		},
	},
	[`vw_prop_vw_offchair_01`] = {
		name = 'vw_prop_vw_offchair_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, -0.1, 180.0),
		},
	},
	[`vw_prop_vw_offchair_02`] = {
		name = 'vw_prop_vw_offchair_02',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`vw_prop_vw_offchair_03`] = {
		name = 'vw_prop_vw_offchair_03',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, -0.1, 180.0),
		},
	},
	[`prop_table_03b_chr`] = {
		name = 'prop_table_03b_chr',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`turbosaif_lsia_bench01`] = {
		name = 'turbosaif_lsia_bench01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.45, 0.0, 0.5, 0),
		},
	},
	[`turbosaif_lsia_coffeeseat`] = {
		name = 'turbosaif_lsia_coffeeseat',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.2, 180.0),
		},
	},
	[`johanni_aldentes_asset_chair_ext`] = {
		name = 'johanni_aldentes_asset_chair_ext',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`johanni_aldentes_asset_barstool_ext`] = {
		name = 'johanni_aldentes_asset_barstool_ext',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.8, 270),
		},
	},
	[`johanni_aldentes_asset_seating02_ext`] = {
		name = 'johanni_aldentes_asset_seating02_ext',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.15, 0.2, 0.05, 0),
		},
	},
	[`xm_lab_chairarm_26`] = {
		name = 'xm_lab_chairarm_26',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.120, -0.958, 0.596, 166.2),
		},
	},
	[`tstudio_jhn_resort_asset_int_sofa01`] = {
		name = 'tstudio_jhn_resort_asset_int_sofa01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.704, -0.332, 0.484, 180.0),
		},
	},
	[`tstudio_jhn_resort_asset_int_sofa02`] = {
		name = 'tstudio_jhn_resort_asset_int_sofa02',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.012, -0.400, 0.550, 180.0),
		},
	},
	[`tstudio_jhn_resort_asset_int_chair01`] = {
		name = 'tstudio_jhn_resort_asset_int_chair01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.002, 0.008, 0.528, 180.0),
		},
	},
	[`prop_rub_couch02`] = {
		name = 'prop_rub_couch02',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.106, -0.320, 0.498, 180.0),
		},
	},
	[`tstudio_legiontowers_asset_fh_sofa`] = {
		name = 'tstudio_legiontowers_asset_fh_sofa',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(1.378, -0.406, 0.576, 180.0),
		},
	},
	[`prop_table_04_chr`] = {
		name = 'prop_table_04_chr',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`tstudio_jhn_resort_ext_asset_sofa04`] = {
		name = 'tstudio_jhn_resort_ext_asset_sofa04',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.426, -0.004, 0.170, 272.0),
		},
	},
	[`tstudio_jhn_resort_ext_asset_sofa05`] = {
		name = 'tstudio_jhn_resort_ext_asset_sofa05',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.022, 0.266, 0.112, 359.6),
		},
	},
	[`tstudio_jhn_resort_ext_asset_sofa02`] = {
		name = 'tstudio_jhn_resort_ext_asset_sofa02',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.012, -0.352, 0.552, 180.0),
		},
	},
	[`tstudio_vw_estate_ext_asset_armchair02`] = {
		name = 'tstudio_vw_estate_ext_asset_armchair02',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.016, 0.274, 0.090, 7.6),
		},
	},
	[`tstudio_vw_estate_ext_asset_int_sofa`] = {
		name = 'tstudio_vw_estate_ext_asset_int_sofa',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.036, 0.148, 0.118, 359.8),
		},
	},
	[`tstudio_vw_estate_ext_asset_teracceseat`] = {
		name = 'tstudio_vw_estate_ext_asset_teracceseat',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.436, 1.046, 0.044, 93.0),
		},
	},
	[`tstudio_jhn_vw_estate_asset_sofa03`] = {
		name = 'tstudio_jhn_vw_estate_asset_sofa03',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.288, 0.002, 0.014, 96.0),
		},
	},
	[`tstudio_jhn_vw_estate_asset_sofa04`] = {
		name = 'tstudio_jhn_vw_estate_asset_sofa04',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.400, -0.150, 0.278, 77.4),
		},
	},
	[`tstudio_jhn_vw_estate_asset_sofa02`] = {
		name = 'tstudio_jhn_vw_estate_asset_sofa02',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.4, -0.15, 0.4, 180.0),
		},
	},
	[`tstudio_jhn_vw_estate_asset_armchair_brown`] = {
		name = 'tstudio_jhn_vw_estate_asset_armchair_brown',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.002, -0.216, -0.042, 180.0),
		},
	},
	[`turbosaif_vmc_seating`] = {
		name = 'turbosaif_vmc_seating',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.396, -0.450, 0.024, 180.0),
		},
	},
	[`turbosaif_johanni_vmc_chair01`] = {
		name = 'turbosaif_johanni_vmc_chair01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.066, 0.192, 0.006, 180.0),
		},
	},
	[`johanni_jurassic_asset_blckjack_01b`] = {
		name = 'johanni_jurassic_asset_blckjack_01b',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.486, -0.818, 0.536, 12.0),
		},
	},
	[`apa_mp_h_yacht_barstool_01`] = {
		name = 'apa_mp_h_yacht_barstool_01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.1, 0.8, 180.0),
		},
	},
	[`tstudio_lsextension_asset_chair01`] = {
		name = 'tstudio_lsextension_asset_chair01',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, 0.5, 180.0),
		},
	},
	[`lounge_armchair_whs_lks`] = {
		name = 'lounge_armchair_whs_lks',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.510, 0.052, 0.110, 79.6),
		},
	},
	[`lounge_sofa_01_whs_lks`] = {
		name = 'lounge_sofa_01_whs_lks',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.006, -1.680, 0.010, 358.8),
		},
	},
	[`lounge_pouf_whs_lks`] = {
		name = 'lounge_pouf_whs_lks',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.120, 0.126, 0.098, 315.4),
		},
	},
	[`lounge_sofa_02_whs_lks`] = {
		name = 'lounge_sofa_02_whs_lks',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.590, -0.330, -0.014, 180.0),
		},
	},
	[`kitchen_chair_whs_lks`] = {
		name = 'kitchen_chair_whs_lks',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.006, -0.030, -0.090, 279.8),
		},
	},
	[`kitchen_stool_whs_lks`] = {
		name = 'kitchen_stool_whs_lks',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.000, 0.000, 0.212, 266.8),
		},
	},
	[`xm_lab_chairarm_02`] = {
		name = 'xm_lab_chairarm_02',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.002, -0.648, 0.420, 180.0),
		},
	},
	[`chair_garden_whs_lks`] = {
		name = 'chair_garden_whs_lks',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.0, 0.0, -0.05, 180.0),
		},
	},
	[`office_armchair_whs_lks`] = {
		name = 'office_armchair_whs_lks',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.212, 0.088, 0.156, 77.6),
		},
	},
	[`office_chair_whs_lks`] = {
		name = 'office_chair_whs_lks',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.008, -0.016, 0.010, 276.6),
		},
	},
	[`hall_bench_whs_lks`] = {
		name = 'hall_bench_whs_lks',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(0.026, 0.030, 0.276, 78.4),
		},
	},
	[`bedroom_2_sofa_whs_lks`] = {
		name = 'bedroom_2_sofa_whs_lks',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.4, -0.15, 0.35, 180.0),
		},
	},
	[`bedroom_armchair_whs_lks`] = {
		name = 'bedroom_armchair_whs_lks',
		maxSeats = 1,
		action = 'bench',
		seats = {
			[1] = vec4(-0.218, 0.090, -0.008, 75.8),
		},
	},
}
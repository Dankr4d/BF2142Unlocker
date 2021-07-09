import host
import bf2
from bf2.stats.constants import *

globalKeysNeeded = {}
rank_data = {}

LIMIT_SINGLE = 0		# can get only once in career
LIMIT_MULTI = 1			# can get several in career and round


# criteria functions

def player_score (player_attr, value=None):
	if value == None:
		def _player_score (player):
			return getattr (player.score, player_attr)
	else:
		def _player_score (player):
			return getattr (player.score, player_attr) >= value
	return _player_score

def player_score_multiple_times (player_attr, value, id):
	def player_score_multiple_times (player):
		new_time_value = (value * (times_awarded(id, player)+1))
		return getattr (player.score, player_attr) >= new_time_value
	return player_score_multiple_times 

def player_stat (player_attr, value=None):
	if value == None:
		def _player_stat (player):
			return getattr (player.stats, player_attr)
	else:
		def _player_stat (player):	
			return getattr (player.stats, player_attr) >= value
	return _player_stat

def player_stat_range (player_attr, min, max):
	def _player_stat (player):
		stat = getattr (player.stats, player_attr)
		return  stat >= min and stat <= max
	return _player_stat

def player_stat_set (player_attr, value, new_value):
	def _player_stat (player):
		stat = getattr (player.stats, player_attr)

		if stat >= value:
			setattr (player.stats, player_attr, new_value)

		return  stat >= value
	return _player_stat

def player_stat_multiple_times (player_attr, value, id):
	def _player_stat_multiple_times (player):
		new_time_value = (value * (times_awarded(id, player)+1))
		return getattr (player.stats, player_attr) >= value
	return _player_stat_multiple_times

def object_stat_multiple_times (object_type, item_attr, item_type, value, id, diff = 0):
	if diff == 1:
		def _object_stat_multiple_times (player):
			new_time_value = (value * (times_awarded(id, player)))
			returnValue = getattr (getattr (player.stats, object_type)[item_type], item_attr)

			if returnValue - new_time_value >= 0:
				return returnValue - new_time_value
			else:
				return 0
	else:
		def _object_stat_multiple_times (player):
			new_time_value = (value * (times_awarded(id, player)+1))
			return getattr (getattr (player.stats, object_type)[item_type], item_attr) >= new_time_value
	return _object_stat_multiple_times

def object_stat (object_type, item_attr, item_type, value=None):
	if value == None:
		def _object_stat (player):
			return getattr (getattr (player.stats, object_type)[item_type], item_attr)
	else:
		def _object_stat (player):
			return getattr (getattr (player.stats, object_type)[item_type], item_attr) >= value
	return _object_stat

def has_medal (id, level=1):
	def _has_medal (player):
		return id in player.medals.roundMedals and player.medals.roundMedals[id] >= level
	return _has_medal

def times_awarded(id, player):
	if id in player.medals.roundMedals:
		return player.medals.roundMedals[id] # TIMES awarded, not level
	else:
		return 0

def global_stat (stat_key, value=None):
	globalKeysNeeded[stat_key] = 1
	if value == None:
		def _global_stat (player):
			if stat_key in player.medals.globalKeys: return player.medals.globalKeys[stat_key]
			else: return 0
	else:
		def _global_stat (player):
			return stat_key in player.medals.globalKeys and player.medals.globalKeys[stat_key] >= value
	return _global_stat


def has_rank (rank):
	def _has_rank (player):
		return player.score.rank == rank
	return _has_rank

# game functions

def game_mode_time (mode, value = None):
	def _game_mode_time (player):
		if int(getGameModeId(bf2.serverSettings.getGameMode())) == mode:
			if value:
				return 1
			else:
				return player.stats.timePlayed
		else:
			return 0
	return _game_mode_time

def game_mode_kills (mode, value=None):
	if value == None:
		def _game_mode_kills (player):			
			if int(getGameModeId(bf2.serverSettings.getGameMode())) == mode:
				return player.score.kills
			else:
				return 0
	else:		
		def _game_mode_kills (player):
			if int(getGameModeId(bf2.serverSettings.getGameMode())) == mode:
				return player.score.kills >= value
			else:
				return 0
	return _game_mode_kills

def army_time (army, value=None):
	if value == None:
		def _army_time (player):
			if player.stats.army == army:
				return int(player.stats.timePlayed)
			else:
				return 0
	else:
		def _army_time (player):
			if player.stats.army == army:
				return int(player.stats.timePlayed) >= value
			return 0
		
	return _army_time

def gpm_wins (mode, value=None):
	globalKeysNeeded['mwin-0-0'] = 1
	globalKeysNeeded['mwin-0-1'] = 1
	globalKeysNeeded['mwin-0-2'] = 1
	globalKeysNeeded['mwin-0-3'] = 1
	globalKeysNeeded['mwin-0-4'] = 1
	globalKeysNeeded['mwin-0-5'] = 1
	globalKeysNeeded['mwin-0-6'] = 1
	globalKeysNeeded['mwin-0-7'] = 1
	globalKeysNeeded['mwin-0-8'] = 1
	globalKeysNeeded['mwin-0-9'] = 1

	globalKeysNeeded['mwin-1-0'] = 1
	globalKeysNeeded['mwin-1-1'] = 1
	globalKeysNeeded['mwin-1-2'] = 1
	globalKeysNeeded['mwin-1-3'] = 1
	globalKeysNeeded['mwin-1-4'] = 1
	globalKeysNeeded['mwin-1-5'] = 1
	globalKeysNeeded['mwin-1-6'] = 1
	globalKeysNeeded['mwin-1-7'] = 1
	globalKeysNeeded['mwin-1-8'] = 1
	globalKeysNeeded['mwin-1-9'] = 1

	if value == None:
		def _gpm_wins  (player):
			wins = 0
			i = 0
			for map in mapMap:
				key = 'mwin-' + str(mode) + '-' + str(i)
				
				if key in player.medals.globalKeys: wins += player.medals.globalKeys[key]
				i += 1

			return wins
	else:
		def _gpm_wins  (player):
			wins = 0
			i = 0
			for map in mapMap:
				key = 'mwin-' + str(mode) + '-' + str(i)
				
				if key in player.medals.globalKeys: wins += player.medals.globalKeys[key]
				i += 1

			return wins >= value
	
	return _gpm_wins

def played_all_maps (army):
	globalKeysNeeded['mtt-0-0'] = 1
	globalKeysNeeded['mtt-0-1'] = 1
	globalKeysNeeded['mtt-0-2'] = 1
	globalKeysNeeded['mtt-0-3'] = 1
	globalKeysNeeded['mtt-0-4'] = 1
	globalKeysNeeded['mtt-0-5'] = 1
	globalKeysNeeded['mtt-0-6'] = 1
	globalKeysNeeded['mtt-0-7'] = 1
	globalKeysNeeded['mtt-0-8'] = 1
	globalKeysNeeded['mtt-0-9'] = 1

	globalKeysNeeded['mtt-1-0'] = 1
	globalKeysNeeded['mtt-1-1'] = 1
	globalKeysNeeded['mtt-1-2'] = 1
	globalKeysNeeded['mtt-1-3'] = 1
	globalKeysNeeded['mtt-1-4'] = 1
	globalKeysNeeded['mtt-1-5'] = 1
	globalKeysNeeded['mtt-1-6'] = 1
	globalKeysNeeded['mtt-1-7'] = 1
	globalKeysNeeded['mtt-1-8'] = 1
	globalKeysNeeded['mtt-1-9'] = 1

	def _played_all_maps (player):
		time = 1
		maps = 0
		for map in mapMap:
			if int(getMapArmy(map)) == army and getMapId(map) != UNKNOWN_MAP:
				
				key = 'mtt-' + '0-' + str(getMapId(map))	
				if key in player.medals.globalKeys:	
					time *= player.medals.globalKeys[key]
					maps = maps + 1


				key = 'mtt-' + '1-' + str(getMapId(map))
				if key in player.medals.globalKeys: 
					time *= player.medals.globalKeys[key]
					maps = maps + 1
												
		return (time * maps) > 0

	return _played_all_maps

def played_map_time (army, value=None):
	if value == None:
		def _played_map_time  (player):
			map = bf2.serverSettings.getMapName()
			return int(int(getMapArmy(map)) == army and getMapId(map) != UNKNOWN_MAP) * player.stats.timePlayed
	else:
		def _played_map_time (player):
			map = bf2.serverSettings.getMapName()
			return (int(int(getMapArmy(map)) == army and getMapId(map) != UNKNOWN_MAP) * player.stats.timePlayed) >= value
		
	return _played_map_time

def gpm_bestRound (mode, value=None):
	globalKeysNeeded['mbr-0-0'] = 1
	globalKeysNeeded['mbr-0-1'] = 1
	globalKeysNeeded['mbr-0-2'] = 1
	globalKeysNeeded['mbr-0-3'] = 1
	globalKeysNeeded['mbr-0-4'] = 1
	globalKeysNeeded['mbr-0-5'] = 1
	globalKeysNeeded['mbr-0-6'] = 1
	globalKeysNeeded['mbr-0-7'] = 1
	globalKeysNeeded['mbr-0-8'] = 1
	globalKeysNeeded['mbr-0-9'] = 1

	globalKeysNeeded['mbr-1-0'] = 1
	globalKeysNeeded['mbr-1-1'] = 1
	globalKeysNeeded['mbr-1-2'] = 1
	globalKeysNeeded['mbr-1-3'] = 1
	globalKeysNeeded['mbr-1-4'] = 1
	globalKeysNeeded['mbr-1-5'] = 1
	globalKeysNeeded['mbr-1-6'] = 1
	globalKeysNeeded['mbr-1-7'] = 1
	globalKeysNeeded['mbr-1-8'] = 1
	globalKeysNeeded['mbr-1-9'] = 1

	if value == None:
		def _gpm_bestRound (player):
			highs = 0

			for map in mapMap:
				key = 'mbr-' + str(mode) + '-' + str(getMapId(map))
				if key in player.medals.globalKeys: highs += player.medals.globalKeys[key]
								
			return highs
	else:
		def _gpm_bestRound (player):
			highs = 0

			for map in mapMap:
				key = 'mbr-' + str(mode) + '-' + str(getMapId(map))
				if key in player.medals.globalKeys: highs += player.medals.globalKeys[key]

			return highs >= value

	return _gpm_bestRound


			
# logical functions

def f_and (*arg_list):
	def _f_and (player):
		res = True
		for f in arg_list:
			res = res and f(player)
			if not res:
				return res
		#	print f(player)
		return res
	return _f_and

def f_or (*arg_list):
	def _f_or (player):
		res = False
		for f in arg_list:
			res = res or f(player)
			if res:
				return res
		return res
	return _f_or

def f_not (f):
	def _f_not (player):
		return not f(player)
	return _f_not

def f_plus(a, b, value=None):
	if value == None:
		def _f_plus (player):
			return a(player) + b(player)
	else:
		def _f_plus (player):
			return a(player) + b(player) >= value
	return _f_plus

def f_minus(a, b, value=None):
	if value == None:
		def _f_minus (player):
			return a(player) - b(player)
	else:
		def _f_minus (player):
			return a(player) - b(player) >= value
	return _f_minus

def f_div(a, b, value=None):
	if value == None:
		def _f_div (player):
			denominator = b(player)
			if denominator == 0: return a(player)+1
			else: return a(player) / denominator
	else:
		def _f_div (player):
			denominator = b(player)
			
			if denominator == 0: 
				return a(player)+1
			else: 
				return a(player) / denominator >= value

	return _f_div

def f_mult(a, b, value=None):
	if value == None:
		def _f_mult (player):
			return a(player) * b(player)
	else:
		def _f_mult (player):
			return a(player) * b(player) >= value
	return _f_mult


# medal definitions

medal_data = (	
		#Badges
			#Support Service Badge 

			#Basic
			('100_1', 'ssb', LIMIT_SINGLE, object_stat ('kits', 'kills', KIT_TYPE_SUPPORT, 12), 20),

			#Veteran
			('100_2', 'ssb', LIMIT_SINGLE, f_and( 	has_medal ('100_1'),
								global_stat ('ktt-3', 54000),
								object_stat ('kits', 'kills', KIT_TYPE_SUPPORT, 20)), 500),
			#Expert	
			('100_3', 'ssb', LIMIT_SINGLE, f_and( 	has_medal ('100_2'),
								global_stat ('ktt-3', 180000),
								object_stat ('kits', 'kills', KIT_TYPE_SUPPORT, 30)), 1000),

			#Recon Service Badge 
			('101_1', 'rsb', LIMIT_SINGLE, object_stat ('kits', 'kills', KIT_TYPE_RECON, 12), 20),
			
			('101_2', 'rsb', LIMIT_SINGLE, f_and( 	has_medal ('101_1'),
								global_stat ('ktt-0', 54000),
								object_stat ('kits', 'kills', KIT_TYPE_RECON, 20)), 500),
			
			('101_3', 'rsb', LIMIT_SINGLE, f_and( 	has_medal ('101_2'),
								global_stat ('ktt-0', 180000),
								object_stat ('kits', 'kills', KIT_TYPE_RECON, 30)), 1000),


			#Assault Service Badge 
			('102_1', 'asb', LIMIT_SINGLE, object_stat ('kits', 'kills', KIT_TYPE_ASSAULT, 12), 20),
			
			('102_2', 'asb', LIMIT_SINGLE, f_and( 	has_medal ('102_1'),
								global_stat ('ktt-1', 54000),
								object_stat ('kits', 'kills', KIT_TYPE_ASSAULT, 20)), 500),
			
			('102_3', 'asb', LIMIT_SINGLE, f_and( 	has_medal ('102_2'),
								global_stat ('ktt-1', 180000),
								object_stat ('kits', 'kills', KIT_TYPE_ASSAULT, 30)), 1000),


			#Anti-Vehicle Badge
			('103_1', 'avsb', LIMIT_SINGLE, object_stat ('kits', 'kills', KIT_TYPE_ANTI_VEHICLE, 12), 20),
			
			('103_2', 'avsb', LIMIT_SINGLE, f_and( 	has_medal ('103_1'),
								global_stat ('ktt-2', 54000),
								object_stat ('kits', 'kills', KIT_TYPE_ANTI_VEHICLE, 20)), 500),
			
			('103_3', 'avsb', LIMIT_SINGLE, f_and( 	has_medal ('103_2'),
								global_stat ('ktt-2', 180000),
								object_stat ('kits', 'kills', KIT_TYPE_ANTI_VEHICLE, 30)), 1000),


			#Squad Leader Badge
			('104_1', 'slsb', LIMIT_SINGLE, player_stat ('squadLeaderBeaconSpawns', 10), 20),

			('104_2', 'slsb', LIMIT_SINGLE, f_and( 	has_medal ('104_1'),
								global_stat ('slpts', 300),
								player_stat ('squadLeaderBeaconSpawns', 20)), 500), 

			('104_3', 'slsb', LIMIT_SINGLE, f_and( 	has_medal ('104_2'),
								global_stat ('slpts', 600),
								player_stat ('squadLeaderBeaconSpawns', 30)), 1000),

			#Collectors Badge
			('105_1', 'cb',	LIMIT_SINGLE, object_stat ('weapons', 'kills', WEAPON_TYPE_KNIFE, 7), 40),

			('105_2', 'cb',	LIMIT_SINGLE, f_and( 	has_medal ('105_1'),
								global_stat ('wkls-12', 50),
								object_stat ('weapons', 'kills', WEAPON_TYPE_KNIFE, 10)), 500),

			('105_3', 'cb',	LIMIT_SINGLE, f_and( 	has_medal ('105_2'),
								global_stat ('wkls-12', 150),
								object_stat ('weapons', 'kills', WEAPON_TYPE_KNIFE, 17)), 1000),

	
			#Pistol Commendation Badge
			('106_1', 'pcb', LIMIT_SINGLE, f_plus(	object_stat ('weapons', 'kills', WEAPON_TYPE_EU_PISTOL),
								object_stat ('weapons', 'kills', WEAPON_TYPE_PAC_PISTOL), 5), 20),

			('106_2', 'pcb', LIMIT_SINGLE, f_and( 	has_medal ('106_1'),
								f_plus(	global_stat ('wkls-5'),
									global_stat ('wkls-11'), 50),
								f_plus(	object_stat ('weapons', 'kills', WEAPON_TYPE_EU_PISTOL),
									object_stat ('weapons', 'kills', WEAPON_TYPE_PAC_PISTOL), 7)), 500),

			('106_3', 'pcb', LIMIT_SINGLE, f_and( 	has_medal ('106_2'),
								f_plus(	global_stat ('wkls-5'),
									global_stat ('wkls-11'), 300),
								f_plus(	object_stat ('weapons', 'kills', WEAPON_TYPE_EU_PISTOL),
									object_stat ('weapons', 'kills', WEAPON_TYPE_PAC_PISTOL), 18)), 1000),


			#Explosive Gallantry Badge
			('107_1', 'egb', LIMIT_SINGLE, f_plus(	f_plus(	object_stat ('weapons', 'kills', WEAPON_TYPE_C4),
									object_stat ('weapons', 'kills', WEAPON_TYPE_CLAYMORE)),
									object_stat ('weapons', 'kills', WEAPON_TYPE_MINE), 10), 20),

			('107_2', 'egb', LIMIT_SINGLE, f_and( 	has_medal ('107_1'),
								f_plus(	f_plus(	global_stat ('wkls-24'),
										global_stat ('wkls-23')),
										global_stat ('wkls-21'), 50),
								f_plus(	f_plus(	object_stat ('weapons', 'kills', WEAPON_TYPE_C4),
										object_stat ('weapons', 'kills', WEAPON_TYPE_CLAYMORE)),
										object_stat ('weapons', 'kills', WEAPON_TYPE_MINE), 15)), 500),

			('107_3', 'egb', LIMIT_SINGLE, f_and( 	has_medal ('107_2'),
								f_plus(	f_plus(	global_stat ('wkls-24'),
										global_stat ('wkls-23')),
										global_stat ('wkls-21'), 300),
								f_plus(	f_plus(	object_stat ('weapons', 'kills', WEAPON_TYPE_C4),
										object_stat ('weapons', 'kills', WEAPON_TYPE_CLAYMORE)),
										object_stat ('weapons', 'kills', WEAPON_TYPE_MINE), 20)), 1000),


			#Air Defense Badge
			('108_1', 'adb',LIMIT_SINGLE, f_plus(	f_plus(	object_stat ('vehicles', 'rtime', VEHICLE_TYPE_ANTI_AIR),
									object_stat ('weapons', 'rtime', WEAPON_TYPE_VEHICLE_AA)),
									object_stat ('vehicles', 'rtime', VEHICLE_TYPE_TITAN_AA), 180), 20),

			('108_2', 'adb', LIMIT_SINGLE, f_and( 	has_medal ('108_1'),
								f_plus( f_plus( global_stat ('vtp-3'),
										global_stat ('wtp-30')),
							 			global_stat ('vtp-12'), 72000),
								f_plus(	f_plus(	object_stat ('vehicles', 'kills', VEHICLE_TYPE_TITAN_AA),
										object_stat ('vehicles', 'kills', VEHICLE_TYPE_ANTI_AIR)),
										object_stat ('weapons', 'kills', WEAPON_TYPE_VEHICLE_AA), 15)), 500),

			('108_3', 'adb', LIMIT_SINGLE, f_and( 	has_medal ('108_2'),
								f_plus( f_plus( global_stat ('vtp-3'),
										global_stat ('wtp-30')),
							 			global_stat ('vtp-12'), 180000),
								f_plus(	f_plus(	object_stat ('vehicles', 'kills', VEHICLE_TYPE_TITAN_AA),
										object_stat ('vehicles', 'kills', VEHICLE_TYPE_ANTI_AIR)),
										object_stat ('weapons', 'kills', WEAPON_TYPE_VEHICLE_AA), 30)), 1000),

			#Commander Exellence Badge
			('109_1', 'ceb', LIMIT_SINGLE, f_and( 	player_score('cmdPyScore', 30),
								f_mult(	game_mode_time (0, 1), 
									player_score('cmdPyScore'), 1)), 40),

			('109_2', 'ceb', LIMIT_SINGLE, f_and( 	has_medal ('109_1'),
								global_stat ('csgpm-0', 1000),
								f_mult(	game_mode_time (0, 1), 
									player_stat('timeAsCmd'), 1200)), 500),

			('109_3', 'ceb', LIMIT_SINGLE, f_and( 	has_medal ('109_2'),
								global_stat ('csgpm-0', 4000),
								f_mult(	game_mode_time (0, 1), 
									player_stat('timeAsCmd'), 1500)), 1000),


			#Titan Commander Badge
			('110_1', 'tcb', LIMIT_SINGLE, f_and( 	player_score('cmdPyScore', 30),
								f_mult(	game_mode_time (1, 1), 
									player_score('cmdPyScore'), 1)), 40),

			('110_2', 'tcb', LIMIT_SINGLE, f_and( 	has_medal ('110_1'),
								global_stat ('csgpm-1', 1000),
								f_mult(	game_mode_time (1, 1), 
									player_stat('timeAsCmd'), 1200)), 500),

			('110_3', 'tcb', LIMIT_SINGLE, f_and( 	has_medal ('110_2'),
								global_stat ('csgpm-1', 4000),
								f_mult(	game_mode_time (1, 1), 
									player_stat('timeAsCmd'), 1500)), 1000),


			#Engineer Exellence Badge
			('111_1', 'eeb', LIMIT_SINGLE, player_score ('repairs', 8), 20),

			('111_2', 'eeb', LIMIT_SINGLE, f_and( 	has_medal ('111_1'),
								global_stat ('etpk-1', 36000),
								player_score ('repairs', 10)), 500),

			('111_3', 'eeb', LIMIT_SINGLE, f_and( 	has_medal ('111_2'),
								global_stat ('etpk-1', 216000),
								global_stat ('rps', 200),
								player_score ('repairs', 15)), 1000),

			#Medic Exellence Badge
			('112_1', 'meb', LIMIT_SINGLE, player_score ('heals', 8), 20),

			('112_2', 'meb', LIMIT_SINGLE, f_and( 	has_medal ('112_1'),
								f_or(	f_or(	global_stat ('etpk-0', 36000),
										global_stat ('etpk-2', 36000)),
										global_stat ('etpk-5', 36000)),
								player_score ('heals', 10)), 500),

			('112_3', 'meb', LIMIT_SINGLE, f_and( 	has_medal ('112_2'),
								f_or(	f_or(	global_stat ('etpk-0', 216000),
										global_stat ('etpk-2', 216000)),
										global_stat ('etpk-5', 216000)),
								global_stat ('hls', 400),
								player_score ('heals', 15)), 1000),

			#Resupply Service Badge
			('113_1', 'resb', LIMIT_SINGLE, player_score ('ammos', 8), 20),

			('113_2', 'resb', LIMIT_SINGLE, f_and( 	has_medal ('113_1'),
								global_stat ('etpk-6', 36000),
								player_score ('ammos', 10)), 500),

			('113_3', 'resb', LIMIT_SINGLE, f_and( 	has_medal ('113_2'),
								global_stat ('etpk-6', 180000),
								global_stat ('resp', 400),
								player_score ('ammos', 15)), 1000),

			#Armor Service Badge  
			('114_1', 'arsb', LIMIT_SINGLE, f_plus(	object_stat ('vehicles', 'rtime', VEHICLE_TYPE_TANK),
								object_stat ('vehicles', 'rtime', VEHICLE_TYPE_MEC), 900), 20),

			('114_2', 'arsb', LIMIT_SINGLE, f_and( 	has_medal ('114_1'),
								f_plus(	object_stat ('vehicles', 'kills', VEHICLE_TYPE_TANK),
									object_stat ('vehicles', 'kills', VEHICLE_TYPE_MEC), 15),
								f_plus(	f_plus(	global_stat ('vtp-0'), 
										global_stat ('vtp-1')),
										global_stat ('vtp-2'), 90000)), 500),


			('114_3', 'arsb', LIMIT_SINGLE, f_and( 	has_medal ('114_2'),
								f_plus(	object_stat ('vehicles', 'kills', VEHICLE_TYPE_TANK),
									object_stat ('vehicles', 'kills', VEHICLE_TYPE_MEC), 35),
								f_plus(	f_plus(	global_stat ('vtp-0'), 
										global_stat ('vtp-1')),
										global_stat ('vtp-2'), 180000)), 1000),

			#Helicopter Service Badge
			('115_1', 'hsb', LIMIT_SINGLE, f_plus(	object_stat ('vehicles', 'rtime', VEHICLE_TYPE_ATTACK_AIR),
								object_stat ('vehicles', 'rtime', VEHICLE_TYPE_TRANSP_AIR), 900), 20),

			('115_2', 'hsb', LIMIT_SINGLE, f_and( 	has_medal ('115_1'),
					 			f_plus(	object_stat ('vehicles', 'kills', VEHICLE_TYPE_ATTACK_AIR),
									object_stat ('vehicles', 'kills', VEHICLE_TYPE_TRANSP_AIR), 15),
								f_plus(	global_stat ('vtp-4'),
									global_stat ('vtp-10'), 90000)), 500),

			('115_3', 'hsb', LIMIT_SINGLE, f_and( 	has_medal ('115_2'),
								f_plus(	object_stat ('vehicles', 'kills', VEHICLE_TYPE_ATTACK_AIR),
									object_stat ('vehicles', 'kills', VEHICLE_TYPE_TRANSP_AIR), 35),
								f_plus(	global_stat ('vtp-4'),
									global_stat ('vtp-10'), 180000)), 1000),

			#Transport Service Badge
			('116_1', 'tsb', LIMIT_SINGLE, f_plus(	f_plus(	object_stat ('vehicles', 'rtime', VEHICLE_TYPE_APC),
									object_stat ('vehicles', 'rtime', VEHICLE_TYPE_FAAV)),
									object_stat ('vehicles', 'rtime', VEHICLE_TYPE_TRANSP_AIR), 600), 20),

			('116_2', 'tsb', LIMIT_SINGLE, f_and( 	has_medal ('116_1'),
								f_plus(	f_plus(	object_stat ('vehicles', 'roadKills', VEHICLE_TYPE_APC),
										object_stat ('vehicles', 'roadKills', VEHICLE_TYPE_FAAV)),
										object_stat ('vehicles', 'roadKills', VEHICLE_TYPE_TRANSP_AIR), 5),
								f_plus(	f_plus(	global_stat ('vtp-1'),
										global_stat ('vtp-6')),
										global_stat ('vtp-4'), 90000)), 500),

			('116_3', 'tsb', LIMIT_SINGLE, f_and( 	has_medal ('116_2'),
								f_plus(	f_plus(	object_stat ('vehicles', 'roadKills', VEHICLE_TYPE_APC),
										object_stat ('vehicles', 'roadKills', VEHICLE_TYPE_FAAV)),
										object_stat ('vehicles', 'roadKills', VEHICLE_TYPE_TRANSP_AIR), 12),
								f_plus(	f_plus(	global_stat ('vtp-1'),
										global_stat ('vtp-6')),
										global_stat ('vtp-4'), 144000)), 1000),

			#Titan Combat Exellence Badge
			('117_1', 'tceb', LIMIT_SINGLE, player_score ('titanAttackKills', 8), 20),

			('117_2', 'tceb', LIMIT_SINGLE, f_and( 	has_medal ('117_1'),
								player_score ('titanAttackKills', 15),
								global_stat ('tgpm-1', 108000)), 500),

			('117_3', 'tceb', LIMIT_SINGLE, f_and( 	has_medal ('117_2'),
								player_score ('titanAttackKills', 30),
								global_stat ('tgpm-1', 216000)), 1000),

			#Titan Defense Exellence Badge
			('118_1', 'tdeb', LIMIT_SINGLE, player_score ('titanDefendKills', 8), 20),

			('118_2', 'tdeb', LIMIT_SINGLE, f_and( 	has_medal ('118_1'),
								player_score ('titanDefendKills', 15),
								global_stat ('tgpm-1', 108000)), 500),

			('118_3', 'tdeb', LIMIT_SINGLE, f_and( 	has_medal ('118_2'),
								player_score ('titanDefendKills', 30),
								global_stat ('tgpm-1', 216000)), 1000),

			#Titan Destruction Achivement Badge
			('119_1', 'tdab', LIMIT_SINGLE, f_plus(	player_score ('titanPartsDestroyed'),
								player_score ('titanCoreDestroyed'), 2), 40),

			('119_2', 'tdab', LIMIT_SINGLE, f_and( 	has_medal ('119_1'),
								player_score ('titanCoreDestroyed', 1),
								f_plus(	global_stat ('tcd'),
									global_stat ('tcrd'), 10)), 500),

			('119_3', 'tdab', LIMIT_SINGLE, f_and( 	has_medal ('119_2'),
								player_score ('titanPartsDestroyed', 3),
								player_score ('titanCoreDestroyed', 1),
								f_plus(	global_stat ('tcd'),
									global_stat ('tcrd'), 40)), 1000),
		#Ribbons

			#Air Defense Ribbon
			('300',	'Adr', LIMIT_SINGLE, f_and(	f_plus( f_plus(	object_stat ('vehicles', 'rtime', VEHICLE_TYPE_ANTI_AIR),
										object_stat ('weapons', 'rtime', WEAPON_TYPE_VEHICLE_AA)),
										object_stat ('vehicles', 'rtime', VEHICLE_TYPE_TITAN_AA), 300),
								f_plus( f_plus(	object_stat ('vehicles', 'kills', VEHICLE_TYPE_ANTI_AIR),
										object_stat ('weapons', 'kills', WEAPON_TYPE_VEHICLE_AA)),
							 			object_stat ('vehicles', 'kills', VEHICLE_TYPE_TITAN_AA), 15)), 30),


			#Helicopter Service Ribbon
			('301',	'Hsr', LIMIT_SINGLE, f_and(	f_plus( object_stat ('vehicles', 'rtime', VEHICLE_TYPE_TRANSP_AIR),
									object_stat ('vehicles', 'rtime', VEHICLE_TYPE_ATTACK_AIR), 600),
								f_plus( object_stat ('vehicles', 'kills', VEHICLE_TYPE_TRANSP_AIR),
									object_stat ('vehicles', 'kills', VEHICLE_TYPE_ATTACK_AIR), 20)), 30),

			#HALO Ribbon
			('302',	'Hr',	LIMIT_SINGLE, object_stat ('vehicles', 'rtime', VEHICLE_TYPE_PARACHUTE, 10), 20),


			#Infantry Officer Ribbon
			('303',	'Ior',	LIMIT_SINGLE, f_and(	player_stat ('timeAsSql', 1200),
								global_stat ('tasl', 144000)), 500),


			#Combat Commander Ribbon
			('304',	'Ccr',	LIMIT_SINGLE, f_and(	player_stat ('timeAsCmd', 1200),
								player_score ('cmdPyScore', 40),
								global_stat ('tac', 288000)), 2000),

			#Distinguished Unit Service Ribbon
			('305',	'Dusr',	LIMIT_SINGLE, f_and(	player_score ('rplScore', 15),
								global_stat ('tasm', 36000),
								global_stat ('tasl', 36000),
								global_stat ('tac', 36000)), 500),


			#Meritorius Unit Service Ribbon
			('306',	'Musr',	LIMIT_SINGLE, f_and(	player_stat ('timeInSquad', 1080), 
								player_score ('rplScore', 40),
								global_stat ('tasm', 72000)), 500),

			#Valorous Unit Service Ribbon
			('307',	'Vusr',	LIMIT_SINGLE, f_and(	player_score ('rplScore', 55),
								global_stat ('tasm', 90000),
								global_stat ('tasl', 180000)), 2000),


			#War College Ribbon
			('308',	'Wcr', LIMIT_SINGLE, f_and(	player_score ('cmdPyScore', 45),
								global_stat ('tac', 216000),
								f_div (	global_stat ('win'), 
    									global_stat ('los'), 2)), 2000),



			#Armored Service Ribbon
			('309',	'Asr', LIMIT_SINGLE, f_and(	f_plus(	f_plus(	object_stat ('vehicles', 'rtime', VEHICLE_TYPE_TANK),			
										object_stat ('vehicles', 'rtime', VEHICLE_TYPE_MEC)),
										object_stat ('vehicles', 'rtime', VEHICLE_TYPE_APC), 1200),			
								f_plus(	f_plus(	object_stat ('vehicles', 'kills', VEHICLE_TYPE_TANK),			
										object_stat ('vehicles', 'kills', VEHICLE_TYPE_MEC)),
										object_stat ('vehicles', 'kills', VEHICLE_TYPE_APC), 20)), 30),


			#Crew Service Ribbon
			('310',	'Csr', LIMIT_SINGLE, f_and(	f_plus (f_plus(	global_stat ('vtp-0'),
										global_stat ('vtp-1')),
									f_plus(	global_stat ('vtp-2'),
										global_stat ('vtp-6')), 36000),
								f_plus (f_plus(	object_stat ('vehicles', 'roadKills', VEHICLE_TYPE_MEC),
										object_stat ('vehicles', 'roadKills', VEHICLE_TYPE_TANK)),
									f_plus(	object_stat ('vehicles', 'roadKills', VEHICLE_TYPE_APC),
										object_stat ('vehicles', 'roadKills', VEHICLE_TYPE_FAAV)), 10)), 50),

			#Pac Duty Ribbon
			('311',	'Pdr',	LIMIT_SINGLE, f_and(	 f_plus( 	army_time (1), 
								global_stat('attp-1'), 432000),
								played_all_maps(1)), 50),			


			#European Duty Ribbon
			('312',	'Edr',	LIMIT_SINGLE, f_and(	 f_plus( 	army_time (0), 
								global_stat('attp-0'), 432000),
								played_all_maps(0)), 50),		
			#Soldier Merit Ribbon
			('313',	'Smr',	LIMIT_SINGLE, f_and(	player_score('kills', 20),
								f_plus(	global_stat('bksgpm-0'), 
							     		global_stat('bksgpm-1'), 10)), 50),

			#Good Conduct Ribbon
			('314',	'Gcr',	LIMIT_SINGLE, f_and(	player_score ('kills', 10),
								f_plus( player_stat ('timePlayed'),
									global_stat ('tt'), 180000),
								f_not (	f_plus(	player_score ('TKs'),
										f_plus(	player_score ('teamDamages'), 
											player_score ('teamVehicleDamages')), 1))), 500),
		
			#Legion Of Merit Ribbon
			('315',	'Lomr',	LIMIT_SINGLE, f_and(	player_score ('kills', 10),
								f_plus( global_stat('bksgpm-0'), 
						     			global_stat('bksgpm-1'), 10),
								f_plus( player_stat ('timePlayed'),
									global_stat ('tt'), 432000)), 2000),

			#Ground Base Defense Ribbon
			('316',	'Gbdr',	LIMIT_SINGLE, f_plus(	object_stat ('vehicles', 'kills', VEHICLE_TYPE_GDEF),
								global_stat ('vkls-7'), 200), 500),

			#Aerial Service Ribbon
			('317',	'Aesr',	LIMIT_SINGLE, f_and(	player_score ('titanAirDrops', 15),
								f_plus(	global_stat ('vtp-10'),
									global_stat ('vtp-4'), 90000)), 500),

			#Titan Aerial Defense Ribbon
			('318',	'Tadr',	LIMIT_SINGLE, f_and(	object_stat ('vehicles', 'kills', VEHICLE_TYPE_TITAN_AA, 15),
								f_plus( object_stat ('vehicles', 'rtime', VEHICLE_TYPE_TITAN_AA),
									global_stat ('vtp-12'), 36000)), 50),

			#Titan Commander Ribbon
			('319',	'Tcr',	LIMIT_SINGLE, f_and(	player_score('cmdTitanScore', 10),
								global_stat('ctgpm-1', 90000)), 500),

		#Medals
			
			#Bronze Star
			#'200'


			#Silver Star
			#'201'
				

			#Gold Star
			#'202'


			#Distinguished Service Medal
			('203',	'Dsm', LIMIT_SINGLE, f_and(	player_score ('rplScore', 30),
								global_stat ('tac', 180000),
								global_stat ('tasm', 180000),
								global_stat ('tasl', 180000)), 0),
		

			#Infantry Combat Medal
			('204',	'Icm', LIMIT_SINGLE, f_and(	has_medal('401', 1),
								has_medal('105_1', 1),
								has_medal('106_1', 1),
								has_medal('102_1', 1),
								has_medal('103_1', 1),
								has_medal('101_1', 1),
								has_medal('100_1', 1),
								has_medal('107_1', 1)), 0),
								

			#Meritorius Infantry Combat Badge
			('205',	'Micb',	LIMIT_SINGLE, 	f_and(	has_medal('401', 1),
								has_medal('105_2', 1),
								has_medal('106_2', 1),
								has_medal('102_2', 1),
								has_medal('103_2', 1),
								has_medal('101_2', 1),
								has_medal('100_2', 1),
								has_medal('107_2', 1)), 0),

			#Infantry Combat of Merit Medal
			('206',	'Icmm',	LIMIT_SINGLE, 	f_and(	has_medal('401', 1),
								has_medal('105_3', 1),
								has_medal('106_3', 1),
								has_medal('102_3', 1),
								has_medal('103_3', 1),
								has_medal('101_3', 1),
								has_medal('100_3', 1),
								has_medal('107_3', 1)), 0),


			#Medal of Gallantry
			('207', 'Mog', 	LIMIT_SINGLE, 	f_and(	f_plus(	player_stat ('timePlayed'),
									global_stat ('tt'), 540000),
								f_plus(	player_score ('rplScore'),
									global_stat ('twsc'), 5000),
								f_plus(	player_score ('cpCaptures'),
									global_stat ('cpt'), 1000),
								f_plus(	player_score ('cpDefends'),
									global_stat ('dcpt'), 400)), 0),
	
			#European Honorific Cross 
			('208', 'Ehc', LIMIT_SINGLE, 	f_and(	army_time (0, 180),
								global_stat ('attp-0', 540000),
								global_stat ('awin-0', 300)), 0),
	

			
			#Distinguished Pan Asian Star
			('209', 'Dpa', LIMIT_SINGLE, 	f_and(	army_time (1, 180),
								global_stat ('attp-1', 540000),
								global_stat ('awin-1', 300)), 0),


			#Meritorius Conquest Medal
			('210', 'Mcm', LIMIT_SINGLE, 	f_and(	has_medal('410', 1),
								f_plus( game_mode_time (0), 
									global_stat ('tgpm-0'), 288000),
									global_stat('kgpm-0', 8000),
									global_stat('bksgpm-0', 25)), 0),


			#Meritorius Titan Medal
			('211',	'Mtm', LIMIT_SINGLE, f_and(	f_and(	has_medal('402', 1),
									f_plus( game_mode_time (1), 
										global_stat ('tgpm-1'), 288000)),
										global_stat('kgpm-1', 8000),
										global_stat('bksgpm-1', 25)), 0),

			#Helicopter Combat Medal
			('212',	'Hcm', LIMIT_SINGLE, f_and(	f_plus(	object_stat('vehicles', 'kills', VEHICLE_TYPE_ATTACK_AIR),
									object_stat('vehicles', 'kills', VEHICLE_TYPE_TRANSP_AIR), 30),
								f_plus(	global_stat('vtp-10'), 	
									global_stat('vtp-4'), 360000),
								f_plus(	global_stat('vkls-10'), 	
									global_stat('vkls-4'), 8000)), 0),


			#Armor Service Medal
			('213',	'Asm', LIMIT_SINGLE, f_and(	f_plus(	f_plus( object_stat('vehicles', 'kills', VEHICLE_TYPE_MEC),
										object_stat('vehicles', 'kills', VEHICLE_TYPE_TANK)),
										object_stat('vehicles', 'kills', VEHICLE_TYPE_APC), 25),
								f_plus(	f_plus( global_stat('vtp-0'),
										global_stat('vtp-2')),
										global_stat('vtp-1'), 360000),
								f_plus(	f_plus( global_stat('vkls-0'),
										global_stat('vkls-2')),
										global_stat('vkls-1'), 8000)), 0),

			#Good Conduct Medal
			('214',	'Gcm', LIMIT_SINGLE, f_and(	player_score ('kills', 27),
								f_plus(	player_stat ('timePlayed'),
									global_stat ('tt'), 648000),
								f_not (	f_plus(	player_score ('TKs'),
										f_plus(	player_score ('teamDamages'), 
											player_score ('teamVehicleDamages')), 1))), 0),

			#Honorable Service Medal
			('215', 'Hsm', LIMIT_SINGLE, f_and( 	f_plus(	player_stat ('timePlayed'),
										global_stat ('tt'), 360000),
									f_plus(	player_score ('heals'),
										global_stat ('hls'), 400),
									f_plus(	player_score ('repairs'),
										global_stat ('rps'), 400),
									f_plus(	player_score ('ammos'),
										global_stat ('resp'), 400)), 0),
	

			#Purple Heart
			('216',	'Ph',	LIMIT_MULTI, f_and(	player_score_multiple_times ('kills', 5, '216'),
								player_score ('dkRatio', 4)), 0),


			#Air Transport Transfer Medal
			('217',	'Attm',	LIMIT_SINGLE, f_and(	player_score('titanAirDrops', 10),
								global_stat('vtp-4', 90000)),  0),

			#Titan Medallion
			('218',	'Tme',	LIMIT_SINGLE, f_and(	f_plus (	game_mode_time (1),
								global_stat ('tgpm-1'), 540000),
								game_mode_kills (1, 10),
								gpm_bestRound (1, 70)), 0),

			#Ground Base Medallion
			('219',	'Gbm',	LIMIT_SINGLE, f_and(	player_score ('kills', 20),
								global_stat('cpt', 100),
								global_stat('rps', 70)),  0),

		#Pins

			#Combat efficiency pin
			('400',	'Cep',	LIMIT_MULTI, f_and (	f_not( player_stat ('currentKillStreak', 6)), 
								f_not( player_stat ('currentKillStreakMedalSecond', 6)),
						   		player_stat_set ('currentKillStreakMedal', 5, 0)), 5),

			#Distinguished Combat efficiency pin
			('401',	'Dcep',	LIMIT_MULTI, f_and (	f_not( player_stat ('currentKillStreak', 11)),  
								player_stat_set ('currentKillStreakMedalSecond', 10, 0),
								player_stat_set ('currentKillStreakMedal', 5, 0)), 10),
	
			#Problem solver Pin
			('402',	'Psp', LIMIT_MULTI, player_score_multiple_times ('titanPartsDestroyed', 4, '402'), 20),
			
			#Titan Destructor Pin
			('403',	'Tdsp', LIMIT_MULTI, player_score_multiple_times ('titanWeaponsDestroyed', 4, '403'), 20),

			#Troop Transporter Pin
			('404',	'Ttp', LIMIT_MULTI, player_score_multiple_times ('titanAirDrops', 10, '404'), 20),

			#Wings of Glory Pin  
			#('405',	'Wgp',	LIMIT_MULTI, player_stat_multiple_times ('lastKillStreak', 10, '405'), 50),


			#Titan Defender Pin
			('406',	'Tdep', LIMIT_MULTI, player_score_multiple_times ('titanDefendKills', 7, '406'), 20),

			#Infiltrator Pin   
			('407',	'Ip', LIMIT_MULTI, f_plus( 	f_plus(	object_stat_multiple_times ('weapons', 'headShots', WEAPON_TYPE_PAC_SNIPER, 5, '407', 1),
									object_stat_multiple_times ('weapons', 'headShots', WEAPON_TYPE_EU_SNIPER , 5, '407', 1)),
									object_stat_multiple_times ('weapons', 'headShots', WEAPON_TYPE_ADV_SNIPER, 5, '407', 1), 5), 10),

			#Wheels of Hazzard Pin
			('408',	'Wohp',	LIMIT_MULTI, f_plus (	f_plus(	object_stat_multiple_times ('vehicles', 'roadKills', VEHICLE_TYPE_MEC, 5, '408', 1),
									object_stat_multiple_times ('vehicles', 'roadKills', VEHICLE_TYPE_TANK, 5, '408', 1)),
								f_plus(	object_stat_multiple_times ('vehicles', 'roadKills', VEHICLE_TYPE_APC, 5, '408', 1),
									object_stat_multiple_times ('vehicles', 'roadKills', VEHICLE_TYPE_FAAV, 5, '408', 1)), 5), 5),

			#Collectors Pin
			('409',	'Cp', LIMIT_MULTI, object_stat_multiple_times ('weapons', 'kills', WEAPON_TYPE_KNIFE, 8, '409'), 20),

			#Explosive Efficiency Pin 
			('410',	'Eep', LIMIT_MULTI, f_plus(	f_plus(	object_stat_multiple_times ('weapons', 'kills', WEAPON_TYPE_C4, 8, '410', 1),
									object_stat_multiple_times ('weapons', 'kills', WEAPON_TYPE_MINE, 8, '410', 1)),
									object_stat_multiple_times ('weapons', 'kills', WEAPON_TYPE_CLAYMORE, 8, '410', 8), 8), 10),

			#Emergency Rescue Pin
			('411', 'Erp', LIMIT_MULTI, player_score_multiple_times ('revives', 8, '411'), 5),

			#Titan survival pin
			 ('412', 'Tsp',	LIMIT_MULTI, object_stat_multiple_times ('weapons', 'kills', WEAPON_TYPE_FLIPPER_MINE, 4, '412'), 10),

			#Firearm Efficiency Pin
			('413',	'Fep', LIMIT_MULTI, f_plus(	object_stat_multiple_times ('weapons', 'kills', WEAPON_TYPE_EU_PISTOL, 4, '413', 1),
								object_stat_multiple_times ('weapons', 'kills', WEAPON_TYPE_PAC_PISTOL, 4, '413', 1), 4), 5),

			#Clear skies Pin 
			('414',	'Csp', LIMIT_MULTI, f_plus( 	f_plus(	object_stat_multiple_times ('weapons', 'kills', WEAPON_TYPE_VEHICLE_AA, 10, '414', 1),
									object_stat_multiple_times ('vehicles', 'kills', VEHICLE_TYPE_ANTI_AIR, 10, '414', 1)),
									object_stat_multiple_times ('vehicles', 'kills', VEHICLE_TYPE_TITAN_AA, 10, '414', 1), 10), 10),

			#Close Combat Pin
			('415',	'Ccp', LIMIT_MULTI, object_stat_multiple_times ('weapons', 'kills', WEAPON_TYPE_AUTO_SHOTGUN, 10, '415'), 10)			
		)




def update_rank_criteria ():
	if g_debug: 
		print "medal_data.py[1025]: Updating ranks"
		print "medal_data.py[1026]: numRanks: ", host.pers_getNumRanks()

	# Register these in globalKeysNeeded (for rankup and disconnect)
	global_stat( 'gsco' )
	global_stat( 'expts' )
	global_stat( 'bnspt' )
	global_stat( 'awybt' )

	for rank in range (1, host.pers_getNumRanks()):
		rank_data[rank - 1] = (
			rank,
			'rank',
			f_and(
				has_rank(rank - 1),
				f_plus(	global_stat ('crpt'),
					f_plus(
						f_minus( player_score ('score'), player_score('diffRankScore')),
						f_plus( player_score('experienceScore'), player_score('awayBonusScore'))
					),
					host.pers_getRankExperience( rank ) 
				)
			)
		)

		if g_debug: print "medal_data.py[1045]: rank: ", rank_data[rank - 1][0], ", xp: ", host.pers_getRankExperience(rank)

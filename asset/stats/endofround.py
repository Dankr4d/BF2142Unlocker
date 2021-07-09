import host
import bf2.PlayerManager
import bf2.GameLogic
from constants import *
from bf2 import g_debug
from bf2.stats.stats import getStatsMap

IGNORED_VEHICLES = [ VEHICLE_TYPE_ANTI_AIR, VEHICLE_TYPE_GDEF, VEHICLE_TYPE_PARACHUTE, VEHICLE_TYPE_SOLDIER ]
SPECIAL_WEAPONS = { WEAPON_TYPE_EU_SNIPER : WEAPON_TYPE_PAC_SNIPER, WEAPON_TYPE_EU_AR : WEAPON_TYPE_PAC_AR, WEAPON_TYPE_EU_AV : WEAPON_TYPE_PAC_AV, WEAPON_TYPE_EU_SMG : WEAPON_TYPE_PAC_SMG, WEAPON_TYPE_EU_LMG : WEAPON_TYPE_PAC_LMG, WEAPON_TYPE_EU_PISTOL : WEAPON_TYPE_PAC_PISTOL, WEAPON_TYPE_EXPLOSIVE_ROUNDS_SHOTGUN : WEAPON_TYPE_EXPLOSIVE_ROUNDS_SHOTGUN }
#IGNORED_WEAPONS = [ WEAPON_TYPE_GROUND_CANNON, WEAPON_TYPE_TITAN_CANNON ] // Replaced with ignored weapon index
IGNORED_WEAPON_INDEX = NUM_WEAPON_TYPES
SPECIAL_VEHICLE = { VEHICLE_TYPE_TITAN_AA : VEHICLE_TYPE_TITAN, VEHICLE_TYPE_TITAN_GDEF : VEHICLE_TYPE_TITAN }

def init():
	if g_debug: print "endofround.py[15]: End of round module initialized."



def invoke():
	if g_debug: print "endofround.py[20]: Invoked end-of-round data-send"

	# collect needed stats
	e = {}
	
	statsMap = getStatsMap()
	sortedPlayers = []
	#ranked = host.ss_getParam('ranked')
	#if ranked:
	#e["r"] = ranked

	if g_debug: print "endofround.py[31]: EOR: statsMap length: " + str( len(statsMap) )

	# find top player in different categories
	for sp in statsMap.itervalues():
		if sp.score > 0:
			sortedPlayers += [((sp.score, sp.skillScore, -sp.deaths), sp)]

		player = "_" + str(sp.name)
		if g_debug: print "endofround.py[39]: EOR: Found player" + player + " (" + str(sp.score) + ", " + str(sp.skillScore) + ", " + str(sp.teamScore) + ")"

		e["tt" + player] = int(sp.timePlayed)

		awayBonus = int(sp.localScore.awayBonusScoreIAR + sp.localScore.awayBonusScore)
		if awayBonus > 0:
			e["ab" + player] = awayBonus

		if sp.localScore.squadMemberBonusScore > 0:
			e["smb" + player] = int(sp.localScore.squadMemberBonusScore)

		if sp.localScore.squadLeaderBonusScore > 0:
			e["slb" + player] = int(sp.localScore.squadLeaderBonusScore)

		if sp.localScore.commanderBonusScore > 0:
			e["cb" + player] = int(sp.localScore.commanderBonusScore)

		if sp.roundRankup > 0:
			e["rr" + player] = 1

		p = bf2.playerManager.getPlayerByIndex(sp.playerId)
		try:
			if p.getName() == sp.name:
				totalScore = (sp.score - sp.localScore.diffRankScore) + int(sp.localScore.experienceScoreIAR + sp.localScore.experienceScore) + int(awayBonus)
				#if ranked:
				if 'crpt' in p.medals.globalKeys:
					totalScore += int(p.medals.globalKeys['crpt'])
				if (sp.score - sp.localScore.diffRankScore) < 0:
					totalScore -= (sp.score - sp.localScore.diffRankScore)
				if g_debug: print "endofround.py[68]: Total player score: " + str(totalScore)
				e["gs" + player] = totalScore
			else:
				if g_debug: print "endofround.py[71]: Duplicate player id found: " + sp.name + ", found: " + p.getName() + " (" + str(sp.playerId) + ")"
		except:
			if g_debug: "No total score for player index: " + str(sp.playerId)


		for k in range(0, NUM_KIT_TYPES):
			if g_debug: print "endofround.py[77]: kit time: " + str(k) + ", " + str(sp.kits[k].timeInObject)
			kit = sp.kits[k]

			if kit.timeInObject > 0:
				e["ktw" + str(k) + player ] = int(kit.timeInObject)
				e["ks" + str(k) + player ] = kit.score


		for w in range(0, NUM_WEAPON_TYPES):
			if g_debug: print "endofround.py[86]: weapon: " + str(w) + ", " + str(sp.weapons[w].timeInObject)
			

			weapon = sp.weapons[w]

			if weapon.timeInObject > 0:
				kills = weapon.kills
				accuracy = "%.3g" % weapon.accuracy
				timeWithWeapon = int(weapon.timeInObject)

				if w in SPECIAL_WEAPONS:
					w = SPECIAL_WEAPONS[ w ]
					keyName = "wk" + str(w) + player

					if keyName in e:
						kills += int(e[ keyName ])
						accuracy = "%.3g" % ( ( float(accuracy) + float( e[ "wa" + str(w) + player ]) ) / 2.0 )
						timeWithWeapon += int( e["wtw" + str(w) + player ] )


				e["wk" + str(w) + player ] = kills
				e["wa" + str(w) + player ] = accuracy
				e["wtw" + str(w) + player ] = timeWithWeapon

		
		for v in range(0, NUM_VEHICLE_TYPES):
			if g_debug: print "endofround.py[114]: vehicle: " + str(v) + ", " + str(sp.vehicles[v].timeInObject)
			if v in IGNORED_VEHICLES:
				if g_debug: print "endofround.py[116]: Ignoring vehicle " + str(v)
				continue

			vehicle = sp.vehicles[v]

			if vehicle.timeInObject > 0:
				timeInVehicle = int(vehicle.timeInObject)
				killsWithVehicle = vehicle.kills

				if v in SPECIAL_VEHICLE:
					v = SPECIAL_VEHICLE[ v ]
					keyName = "vtw" + str(v) + player

					if keyName in e:
						timeInVehicle += int(e[ keyName ])
						killsWithVehicle += int(e["vtw" + str(v) + player ])


				e["vtw" + str(v) + player ] = timeInVehicle
				e["vk" + str(v) + player ] = killsWithVehicle

	if g_debug: print "\n-----------------\n%s\n---------------------\n" %e
	# stats for top-3 scoring players
	sortedPlayers.sort()
	sortedPlayers.reverse()

	if g_debug:
		for p in range(0, len(sortedPlayers)):
			print "endofround.py[144]: EOR: Sorted player " + str(p+1) + ": n:" + sortedPlayers[p][1].name + ", s:" + str(sortedPlayers[p][1].score)
		
	for i in range(3):
		if len(sortedPlayers) <= i:
			break

		sp = sortedPlayers[i][1]
		e["tp" + str(i)] = sp.name


	keyvals = []
	for k in e:
		keyvals.append ("\\".join((k, str(e[k]))))

	dataString = "\\" + "\\".join(keyvals)
	
	if g_debug: print "endofround.py[160]: ", dataString
	host.gl_sendEndOfRoundData(dataString)

	
		
def findTop(e, vkey, nkey, value, name):
	if not vkey in e or value > e[vkey]:
		e[vkey] = value
		e[nkey] = name

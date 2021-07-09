# medals upgrades

import host
import bf2.PlayerManager
import bf2.Timer

from bf2 import g_debug

from bf2.stats.constants import *
from bf2.stats.medal_data import *

from bf2.stats.stats import getStatsMap, getPlayerConnectionOrderIterator, setPlayerConnectionOrderIterator

# kosh 20061115
# ------------------------------------------------------------------------------
#from bf2.BF2142StatisticsConfig import http_backend_addr, http_backend_port
#from bf2.stats.miniclient import miniclient, http_get


# kosh 20061115
# ------------------------------------------------------------------------------
# mimics onPlayerAwardsResponse()
# ------------------------------------------------------------------------------
def attachPlayerAwards(player, awards):

	if not player:
		if g_debug: print "medals.py[74]: No player for awards response."
		return

	if g_debug: print "medals.py[77]: Processing AWARDS response for player %d, size %d." % (player.index, len(awards))

	for medalKey in awards:

		# distinguish between 4 types of medal-entry:
		# 1. Regular medal with key like '123456', with only one level and can only be gotten once
		# 2. Medal with simple key like '123456', can be gotten multiple times, where criteria is changed depending on previous level
		# 3. Medal with simple key like '123456', can be gotten multiple times regardless of previous level, but only once per round
		# 4. Badge with key like '123456_1', that has individual medal entries per level

		item = getMedalEntry(medalKey)
		if item:

			# some medals are not kept, and can be gotten regardless of previous level. ex: purple heart
			#keep = item[2] != 1
			#if keep:
			# case 1, 2
			player.medals.gsiMedals[medalKey] = int(awards[medalKey])
			player.medals.roundMedals[medalKey] = int(awards[medalKey])
			#else:
			#	# case 3
			#	pass

		else:
			# case 4: badge with individual per-level criterias,
			# skip placement medals
			if ( awards[medalKey] > 0 ):

				medalKey += '_' + str(awards[medalKey])

			item = getMedalEntry(medalKey)

			if item:
				player.medals.gsiMedals[medalKey] = 1
				player.medals.roundMedals[medalKey] = 1
			else:
				print "medals.py[113]: Medal", medalKey,"not found in medal data."


	#print "medals.py[116]: Player GSI medals:", player.medals.gsiMedals
	#print "medals.py[117]: Player round medals:", player.medals.roundMedals



sessionPlayerMedalMap = {}
def getMedalMap():
	global sessionPlayerMedalMap
	return sessionPlayerMedalMap

def setMedalMap(map):
	global sessionPlayerMedalMap
	sessionPlayerMedalMap = map

globalKeyString = ""
g_lastPlayerChecked = 0

def init():
	# Events
	host.registerHandler('PlayerConnect', onPlayerConnect, 1)
	host.registerHandler('PlayerDisconnect', onPlayerDisconnect, 1)
	host.registerHandler('PlayerStatsResponse', onStatsResponse, 1)
	host.registerHandler('PlayerAwardsResponse', onAwardsResponse, 1)
	host.registerGameStatusHandler(onGameStatusChanged)


	if g_debug: print "medals.py[142]: Medal awarding module initialized"

	global globalKeyString
	globalKeyString = createGlobalKeyString(globalKeysNeeded)
	if g_debug: print "medals.py[146]: Global key string: ", globalKeyString

# create the stats query string in gamespy format
def createGlobalKeyString(keymap):
	keystring = "&info=rank,"
	usedKeys = {}
	for k in keymap:
		# strip number trailing '-' in key, as gamespy doesnt allow per-vehicle/weapon/kit key-getting.
		f = k.find('-')
		if f != -1:
			k = k[:f+1]

		if not k in usedKeys:
			keystring = keystring + k + ","
			usedKeys[k] = 1
	# put vac- at the end of string, compensating for gamespy bug
	if keystring.find('vac-'):
		keystring = keystring.replace('vac-,', '') + 'vac-,'
	# remove last comma
	if len(k) > 0:
		keystring = keystring[:len(keystring)-1]

	return keystring

updateTimer = None

def onGameStatusChanged(status):
	global updateTimer
	if status == bf2.GameStatus.Playing:
		host.registerHandler('PlayerKilled', onPlayerKilled3)
		host.registerHandler('ExitVehicle', onExitVehicle)
		host.registerHandler('PlayerScore', onPlayerScore)
		if updateTimer:
			updateTimer.destroy()
		updateTimer = bf2.Timer(onUpdate, 1, 0)
		updateTimer.setRecurring(1)
		# connect already connected players if reinitializing
		for p in bf2.playerManager.getPlayers():
			onPlayerConnect(p)

		global g_lastPlayerChecked
		g_lastPlayerChecked = 0
	elif status == bf2.GameStatus.EndGame:
		givePositionalMedals(True, bf2.gameLogic.getWinner())
		# produce snapshot
		bf2.stats.snapshot.invoke()
		if updateTimer:
			updateTimer.destroy()



def onPlayerConnect(player):
	id = player.stats.connectionOrderNr
	#reconnect = id in sessionPlayerMedalMap
	#reconnect = False

	# omero, 2006-03-14
	# reverting back to original code.
	#
	# todo:
	# leaving reconnect=false has a side-effect of
	# queries in rapid succession to db at each
	# gamestatus change which could flood the backend.
	# needs to be clarified, meantime during testing
	# there has been no evidence of problems with
	# reverting back.
	#
	reconnect = id in sessionPlayerMedalMap

	if id in sessionPlayerMedalMap:
		if g_debug: print "medals.py[216]: Player id=%d found in sessionPlayerMedalMap" % int(id)

	if not reconnect:
		newMedalSet = MedalSet()
		sessionPlayerMedalMap[id] = newMedalSet
	player.medals = sessionPlayerMedalMap[id]
	player.medals.connect(reconnect)
	if not reconnect:
		#rank
		player.score.rank = 0
		if g_debug: print "medals.py[226]: Added player %d, %s (%s) IP=%s to medal/rank checking" % ( player.index, player.getName(), str(player.getProfileId()), player.getAddress())
	else:
		player.score.rank = player.stats.rank
		if g_debug: print "medals.py[229]: Readded player %d to medal/rank checking" % player.index
		# Force gamespy request (due to bug with Glodal Data Update)
		reconnect = False

	if player.getProfileId() > 0 and not reconnect:
		if g_debug: print "medals.py[230]: Getting Stats..."
		# get persistant stats from gamespy
		#print "medals.py[236]: host.ss_getParam('ranked') = ", host.ss_getParam('ranked')
		#if host.ss_getParam('ranked'):
		player.score.rank = player.stats.rank

		# STATS
		if g_debug: print "medals.py[240]: Requesting player STATS"
		success = host.pers_plrRequestStats(player.index, 1, "&mode=base", 0) 
		#print "medals.py[242]: globalKeyString2 %s" % globalKeyString
		# fetch player stats from a friendly place
		if not success:
			if g_debug: print "medals.py[245]: Retrieving player STATS via HTTP/1.1 miniclient"

		# AWARDS
		if g_debug: print "medals.py[274]: Requesting player AWARDS"
		success = host.pers_plrRequestAwards(player.index, 1, "")

		# fetch player awards from a friendly place
		if not success:
			if g_debug: print "medals.py[279]: Retrieving player AWARDS via HTTP/1.1 miniclient"


def onPlayerDisconnect(player):
	pass

class MedalSet:
	def __init__(self):
		self.gsiMedals = {}
		self.roundMedals = {}
		self.globalKeys = {}
	def connect(self, reconnect):
		if not reconnect:
			if g_debug: print "medals.py[324]: getting medals from gamespy"
			if g_debug: print "medals.py[325]: Will retrieve medals from GSI..."
			# init position medals
			self.placeMedals = [0, 0, 0]
		else:
			# already connected, just clear round-only medals
			if g_debug: print "medals.py[330]: Resetting unkept round-only medals..."
			for medal in medal_data:
				id = medal[0]
				keep = medal[2] != 1
				if not keep and id in self.roundMedals:
					del self.roundMedals[id]
		self.placeMedalThisRound = 0

		if g_debug: print "medals.py[338]: roundMedals: ", self.roundMedals
	def getSnapShot(self):
		medalKeys = {}
		prevKeys = {}
		# sum up medals with same key into one record (badges), for backend state and for current game state
		for medal in medal_data:
			id = medal[0]
			key = medal[1]
			if '_' in medal[0]:
				# do special level calculation on badges, as they are sent as one key, but received as several
				if id in self.roundMedals:
					if not key in medalKeys:
						# can only have one
						medalKeys[key] = 1
					else:
						# increase medal level
						medalKeys[key] = medalKeys[key] + 1
				if id in self.gsiMedals:
					if not key in prevKeys:
						# can only have one
						prevKeys[key] = 1
					else:
						# increase medal level
						prevKeys[key] = prevKeys[key] + 1
			else:
				# regular medals
				if id in self.roundMedals:
					medalKeys[key] = self.roundMedals[id]
				if id in self.gsiMedals:
					prevKeys[key] = self.gsiMedals[id]
		# only send medal stats when we have increased level
		removeList = []
		for key in medalKeys:
			if key in prevKeys:
				if prevKeys[key] >= medalKeys[key]:
					# already had this medal, no need to send in snapshot
					removeList += [key]
		for key in removeList:
			del medalKeys[key]
		if self.placeMedalThisRound == 1:
			medalKeys['erg'] = 1
		elif self.placeMedalThisRound == 2:
			medalKeys['ers'] = 1
		elif self.placeMedalThisRound == 3:
			medalKeys['erb'] = 1
		keyvals = []
		for k in medalKeys:
			keyvals.append ("\\".join(("medal" + k, str(medalKeys[k]))))
		return "\\".join(keyvals)

def givePositionalMedals(endOfRound, winningTeam):
	if endOfRound:
		# give medals for position
		sortedPlayers = []
		statsMap = getStatsMap()
		for sp in statsMap.itervalues():
			sortedPlayers += [((sp.score, sp.skillScore, -sp.deaths), sp.connectionOrderNr)]
		sortedPlayers.sort()
		sortedPlayers.reverse()
		global sessionPlayerMedalMap
		if len(sortedPlayers) > 0 and sortedPlayers[0][1] in sessionPlayerMedalMap:
			sessionPlayerMedalMap[sortedPlayers[0][1]].placeMedals[0] += 1
			sessionPlayerMedalMap[sortedPlayers[0][1]].placeMedalThisRound = 1
		if len(sortedPlayers) > 1 and sortedPlayers[1][1] in sessionPlayerMedalMap:
			sessionPlayerMedalMap[sortedPlayers[1][1]].placeMedals[1] += 1
			sessionPlayerMedalMap[sortedPlayers[1][1]].placeMedalThisRound = 2
		if len(sortedPlayers) > 2 and sortedPlayers[2][1] in sessionPlayerMedalMap:
			sessionPlayerMedalMap[sortedPlayers[2][1]].placeMedals[2] += 1
			sessionPlayerMedalMap[sortedPlayers[2][1]].placeMedalThisRound = 3

def onUpdate(data):
	global g_lastPlayerChecked
	# check one player
	for i in range (0, 2):
		p = bf2.playerManager.getNextPlayer(g_lastPlayerChecked)
		if not p: break
		#if p.isAlive() and not p.isAIPlayer():
		if p.isAlive():
			checkMedals(p)
		g_lastPlayerChecked = p.index

def onPlayerKilled3(victim, attacker, weapon, assists, object):
	if attacker != None:
		checkMedals(attacker)

def onExitVehicle(player, vehicle):
	checkMedals(player)

def onPlayerScore(player, difference):
	if g_debug: print "medals.py[423]: onPlayerScore : checkRank"
	if player != None and difference > 0:
		checkRank(player)

def checkMedals(player):
	if not player.isAlive():
		return
	#print "medals.py[429]: checking medals player %d" % player.index
	for medal in medal_data:
		# check that player does not already have this medal this round
		id = medal[0]
		if id in player.medals.roundMedals:
			# if medal has multiple-times criteria, criterias have been changed and level should already match. no need to exit then.
			#if g_debug: print "medals.py[435]: %s" % medal[2]
			if medal[2] == 0:
				continue
		# check if criteria was met
		checkCriteria = medal[3]
		if not checkCriteria(player):
			continue
		# strip underscore
		idStr = medal[0]
		newLevel = 1
		if '_' in medal[0]:
			newLevel = int(idStr[idStr.find('_') + 1:])
			idStr = idStr[:idStr.find('_')]
			awardMedal(player, int(idStr), newLevel, medal[4])
		else:
			if id in player.medals.roundMedals:
				newLevel = player.medals.roundMedals[id] + 1
			awardMedal(player, int(idStr), 0, medal[4])
		player.score.experienceScoreIAR += medal[4]
		if g_debug: print "medals.py[456]: New medal level", id,":",newLevel
		player.medals.roundMedals[id] = newLevel

def checkRank(player):
	oldRank = player.score.rank
	print "medals.py[456]: rank: ", player.score.rank
	rankCriteria = None
	highestRank = player.score.rank
	#print str(rank_data)
	for rankItem in range (0, (host.pers_getNumRanks() - 1)):
		#print rankItem
		rankCriteria = rank_data[rankItem][2]
		if rank_data[rankItem][0] > highestRank and rankCriteria(player):
			highestRank = rank_data[rankItem][0]
	if oldRank < highestRank:
		player.score.rank = highestRank
		awardRank(player, player.score.rank)

def awardMedal(player, id, level, plusscore):
	if g_debug: print "medals.py[473]: Player %s earned AWARD %d at level %d +%d EXP1:%d" % (player.getName(), id, level, plusscore, player.score.experienceScoreIAR)
	bf2.gameLogic.sendMedalEvent(player, id, level, plusscore, 0)

def awardRank(player, rank):
	if g_debug: print "medals.py[477]: Player %s promoted from RANK %d to %d" % (player.getName(), player.score.rank, rank)
	bf2.gameLogic.sendRankEvent(player, rank, player.score.score)

def onStatsResponse(succeeded, player, stats):
	if not succeeded:
		if player == None:
			playerIndex = "unknown"
		else:
			playerIndex = player.index
		if g_debug: print "medals.py[486]: Stats request failed for player ", playerIndex, ": ", stats
		return
	if not player:
		if g_debug: print "medals.py[489]: No player for stats response."
		return
	if g_debug: print "medals.py[491]: Stats response received for player %d, size %d." % (player.index, len(stats))

	if "<HTML>" in stats:
		print "medals.py[494]: The stats response seems wrong:"
		print "medals.py[495]: -|-|-|-|-|-|-|-|-|-|-|-|-"
		print stats
		print "medals.py[497]: -^-^-^-^-^-^-^-^-^-^-^-^-"
		return
	# add medal values
	print "medals.py[500]: -|-|-|-|-|-|-|-|-|-|-|-|-"
	print stats
	print "medals.py[502]:-^-^-^-^-^-^-^-^-^-^-^-^-"
	for key in globalKeysNeeded:
		if not key in stats:
			if g_debug: print "medals.py[506]: Key %s not found in stats response" % key
		else:
			if g_debug: print "medals.py[508]: Key %s -> %s" % (key, host.pers_getStatsKeyVal(key, player.getProfileId()))
			value = int( host.pers_getStatsKeyVal(key, player.getProfileId()) )
			player.medals.globalKeys[key] = value
	# add rank
	if not 'rnk' in stats:
		if g_debug: print "medals.py[517]: Key %s not found in stats response" % 'rnk'
	else:
		value = int( host.pers_getStatsKeyVal("rnk", player.getProfileId()) )
		if g_debug: print "medals.py[520]: Player",player.index,"Rank:", value
		player.score.rank = value
		player.stats.rank = value

def getMedalEntry(key):
	for item in medal_data:
		if medalKey == item[0]:
			return item
	return None

# create faster medal-data lookup map
medalDataKeyLookup = {}
for item in medal_data:
	medalDataKeyLookup[item[0]] = item

def getMedalEntry(key):
	if key in medalDataKeyLookup:
		return medalDataKeyLookup[key]
	return None

def onAwardsResponse(succeeded, player, awards):
	if not succeeded:
		if player == None:
			playerIndex = "unknown"
		else:
			playerIndex = player.index
		print "medals.py[554]: Medal request failed for player ", playerIndex, ": ", stats
		return
	if g_debug: print "medals.py[556]: Awards response received: ", awards
	if not player:
		if g_debug: print "medals.py[558]: No player for medal response."
		return
	for a in awards:
		medalKey = str(a[0])
		# distinguish between 4 types of medal-entry:
		# 1. Medal with simple key like '123456', can be gotten multiple times regardless of previous level, but only once per round
		# 1. Badge with key like '123456_1', that has individual medal entries per level
		# 2. Regular medal with key like '123456', with only one level and can only be gotten once
		# 3. Medal with simple key like '123456', can be gotten multiple times, where criteria is changed depending on previous level
		item = getMedalEntry(medalKey)
		if item:
			# some medals are not kept, and can be gotten regardless of previous level. ex: purple heart
			#keep = item[2] == 3
			#if keep:
			#	# case 3
			#	pass
			#else:
			#	# case 1a, 2
			player.medals.gsiMedals[medalKey] = int(a[1])
			player.medals.roundMedals[medalKey] = int(a[1])
		else:
			# case 1b: badge with individual per-level criterias
			if a[1] > 0:
				medalKey += '_' + str(a[1])
			item = getMedalEntry(medalKey)
			if item:
				player.medals.gsiMedals[medalKey] = 1
				player.medals.roundMedals[medalKey] = 1
			else:
				print "medals.py[587]: Medal", medalKey,"not found in medal data."
	print "medals.py[588]: Player medals:", player.medals.gsiMedals

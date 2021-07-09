# rank upgrades

import host
import bf2.PlayerManager
import bf2.Timer
from bf2.stats.constants import *
from bf2 import g_debug



def init():
	# Events
	#if g_debug: print "getUseGlobalRank = %s" % str(bf2.serverSettings.getUseGlobalRank())
	#if bf2.serverSettings.getUseGlobalRank():
	host.registerHandler('PlayerConnect', onPlayerConnect, 1)
	host.registerHandler('PlayerStatsResponse', onStatsResponse, 1)

	host.registerGameStatusHandler(onGameStatusChanged)
	
	# Connect already connected players if reinitializing
	for p in bf2.playerManager.getPlayers():
		onPlayerConnect(p)

	if g_debug: print "rank.py[24]: Rank module initialized"

		

def onGameStatusChanged(status):
	if status == bf2.GameStatus.Playing:
		pass
	else:
		if g_debug: print "rank.py[32]: Destroyed timer"



def onUpdate(data):
	for p in bf2.playerManager.getPlayers():
		if g_debug: print "rank.py[38]: checkRank"
		if p.isAlive():
			checkRank(p)



### Event hooks

def onPlayerConnect(player):
	#id = player.index
	if player.score.rank == -1:
		player.score.rank = 0
	
	# request rank
	#if bf2.serverSettings.getUseGlobalRank():
	if player.getProfileId() > 0:
		success = host.pers_plrRequestStats(player.index, 1, "&mode=base", 0)
	else:
		if g_debug: print "rank.py[55]: Player %d had no profile id, can't request rank" % player.index
			
	
	if g_debug: print "rank.py[58]: Added player %d to rank checking" % (player.index)
	
	
	
def onStatsResponse(succeeded, player, stats):
	if player == None:
		playerIndex = "unknown"
	else:
		playerIndex = player.index

	if not "rnk" in stats:
		if g_debug: print "rank.py[69]: rank not found, aborting"
		return

	if g_debug: print "rank.py[72]: Rank received for player ", playerIndex, ":", host.pers_getStatsKeyVal("rnk", player.getProfileId())
	if not player: return
	

	value = int( host.pers_getStatsKeyVal("rnk", player.getProfileId()) )
	if g_debug: print "rank.py[77]: Player",player.index,"Rank:", value
	player.score.rank = value
	player.stats.rank = value
		
		
		
		







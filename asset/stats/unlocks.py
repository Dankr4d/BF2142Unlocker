import host
import bf2.PlayerManager
from bf2 import g_debug



def init():
	# Events
	host.registerHandler('PlayerConnect', onPlayerConnect, 1)
	host.registerGameStatusHandler(onGameStatusChanged)
	
	# Connect already connected players if reinitializing
	for p in bf2.playerManager.getPlayers():
		onPlayerConnect(p)

	if g_debug: print "unlocks.py[16]: Unlock module initialized"



def onPlayerConnect(player):
	#if g_debug: print "unlocks.py[21]: onPlayerConnect %d try unlock checking" % (player.index)
	#if not player.isAIPlayer():
	#	if bf2.serverSettings.getUseGlobalUnlocks():
	if player.getProfileId() > 0:		
		success = host.pers_plrRequestUnlocks(player.index, 1)
		if not success:
			if g_debug: print "unlocks.py[27]: Failed requesting unlocks"
	else:
		if g_debug: print "unlocks.py[29]: Player %d had no profile id, can't request unlocks" % player.index
		
	if g_debug: print "unlocks.py[31]: Added player %d to unlock checking" % (player.index)


def onGameStatusChanged(status):
	if status == bf2.GameStatus.Playing:
		# connect already connected players if reinitializing
		for p in bf2.playerManager.getPlayers():
			onPlayerConnect(p)

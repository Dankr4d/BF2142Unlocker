"""
This python is written to "mods/bf2142/python/game/gamesmodes/fixes.py
The gpm_coop.py file is patched to call the function(s) of this module.
"""

import host
import bf2

def onGameStatusChanged(status):
  if status == bf2.GameStatus.PreGame:
    # Prevents bots from using sentry drone (detonator)
    host.rcon_invoke("ObjectTemplate.activeSafe GenericFireArm Unl_Drone_Sentry_Detonator")
    host.rcon_invoke("ObjectTemplate.aiTemplate \"\"")
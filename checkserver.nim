import net

proc isAddrReachable*(ip: string, port: Port): bool =
  var socket: Socket
  try:
    socket = newSocket()
    socket.connect(ip, port)
    socket.close()
    return true
  except OSError: # TODO: Check "Connection refused" (error msg)
    socket.close()
    return false

when isMainModule:
  import localaddrs
  for localAddr in getLocalAddrs():
    echo "Unlock server is reachable: ", isAddrReachable(localAddr, 8080)
    echo "Fesl server is reachable: ", isAddrReachable(localAddr, 18300)
    echo "Gpcm server is reachable: ", isAddrReachable(localAddr, 29900)
    echo "TODO: Check BF2142 Server port" # Optional
import net

proc isAddrReachable*(ip: string, port: Port, timeout: int): bool =
  var socket: Socket
  try:
    socket = newSocket()
    socket.connect(ip, port, timeout)
    socket.close()
    return true
  except OSError, TimeoutError: # TODO: Check "Connection refused" (error msg)
    socket.close()
    return false

when isMainModule:
  import localaddrs
  for localAddr in getLocalAddrs():
    echo "Unlock server is reachable: ", isAddrReachable(localAddr, Port(8085), 100)
    echo "Fesl server is reachable: ", isAddrReachable(localAddr, Port(18300), 100)
    echo "Gpcm server is reachable: ", isAddrReachable(localAddr, Port(29900), 100)
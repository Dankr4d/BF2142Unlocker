import psutil
import nativesockets
import strutils

proc getLocalAddrs*(): seq[string] =
  for nic, addrs in psutil.net_if_addrs():
    for localAddr in addrs:
      if localAddr.family == AF_INET.uint16:
        if not localAddr.address.startsWith("127"):
          result.add localAddr.address

when isMainModule:
  echo getLocalAddrs()
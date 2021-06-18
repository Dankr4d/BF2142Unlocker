import streams
import net
import strutils # Required for parseHexInt proc
import nativesockets # Required for getHostByName
import uri # Required for parseUri # TODO: REMOVE (see server.ini)

type
  PatchConfig* = object of RootObj
    stella_prod*: string
    stella_ms*: string
    ms*: string
    available*: string
    motd*: string
    master*: string
    gamestats*: string
    gpcm*: string
    gpsp*: string

proc writeIpReversed(fs: FileStream, pos: int, ip: IpAddress) =
  var len: int = ip.address_v4.len - 1
  fs.setPosition(pos)
  for i in 0..len:
    fs.write(ip.address_v4[len - i])

proc writeStr(fs: FileStream, pos: int, str: string, maxLen: int) =
  fs.setPosition(pos)
  fs.write(str)
  for i in 1..maxLen - str.len:
    fs.write(byte(0x0))

proc patchServer*(fs: FileStream, ip: IpAddress, port: Port) =
  let stellaProd: string = "http://" & $ip & ":" & $port & "/"
  when defined(linux):
    when defined(cpu32):
      fs.writeStr(parseHexInt("00869727"), stellaProd, 31)
    else:
      fs.writeStr(parseHexInt("00768FA0"), stellaProd, 31) # http://stella.prod.gamespy.com/
  elif defined(windows):
    fs.writeStr(parseHexInt("003CE610"), stellaProd, 31)

proc patchServer*(path: string, ip: IpAddress, port: Port) =
  var fs: FileStream = newFileStream(path, fmReadWriteExisting)
  fs.patchServer(ip, port)
  fs.close()

proc patchClient*(fs: FileStream, patchConfig: PatchConfig) =
  ## Previously preClientPatch
  fs.setPosition(parseHexInt("003293B0"))
  fs.write(byte(0x90))
  fs.write(byte(0x90))
  fs.setPosition(parseHexInt("003293B3"))
  fs.write(byte(0x35))
  fs.setPosition(parseHexInt("003293C1"))
  fs.write(byte(0x30))
  fs.write(byte(0xF2))
  fs.setPosition(parseHexInt("003293CF"))
  fs.write(byte(0x92))
  fs.setPosition(parseHexInt("003293D0"))
  fs.write(byte(0x94))
  fs.setPosition(parseHexInt("0045C97A"))
  fs.write(byte(0x88))
  fs.write(byte(0x1F))
  fs.write(byte(0xB5))
  fs.setPosition(parseHexInt("0045C981"))
  fs.write(byte(0xC7))
  fs.write(byte(0x46))
  fs.write(byte(0x04))
  fs.setPosition(parseHexInt("0045C988"))
  fs.write(byte(0xC7))
  fs.write(byte(0x06))
  fs.write(byte(0x01))
  fs.write(byte(0x00))
  fs.write(byte(0x00))
  fs.write(byte(0x00))
  fs.write(byte(0xEB))
  fs.write(byte(0x2A))
  fs.setPosition(parseHexInt("0045C9D8"))
  fs.write(byte(0x94))
  fs.write(byte(0x97))
  # SSL (certificates are not verified)
  fs.setPosition(parseHexInt("0045FE8D"))
  fs.write(byte(0xB8))
  fs.write(byte(0x15))
  fs.write(byte(0x00))
  fs.write(byte(0x00))
  fs.write(byte(0x00))
  # Large Address Aware (patching from 2GB to 4GB ram)
  fs.setPosition(parseHexInt("00000146"))
  fs.write(byte(0x2E))

  var hostend: Hostent = getHostByName(parseUri(patchConfig.stella_prod).hostname)
  fs.writeIpReversed(parseHexInt("0045C984"), parseIpAddress(hostend.addrList[0])) # stella.prod.gamespy.com (as ip)
  fs.writeStr(parseHexInt("005639A4"), patchConfig.stella_prod, 31) # http://stella.prod.gamespy.com
  fs.writeStr(parseHexInt("005639C4"), patchConfig.stella_ms, 23) # stella.prod.gamespy.com
  fs.writeStr(parseHexInt("0059F608"), patchConfig.ms, 19) # %s.ms%d.gamespy.com
  fs.writeStr(parseHexInt("0059E6E8"), patchConfig.available, 27) # %s.available.gamespy.com
  fs.writeStr(parseHexInt("0059E938"), patchConfig.motd, 39) # http://motd.gamespy.com/motd/motd.asp
  fs.writeStr(parseHexInt("0059E97C"), patchConfig.master, 23) # %s.master.gamespy.com
  fs.writeStr(parseHexInt("006067A0"), patchConfig.gamestats, 63) # gamestats.gamespy.com
  fs.writeStr(parseHexInt("00607180"), patchConfig.gpcm, 63) # gpcm.gamespy.com
  fs.writeStr(parseHexInt("006071C0"), patchConfig.gpsp, 63) # gpsp.gamespy.com

proc patchClient*(path: string, patchConfig: PatchConfig) =
  var fs: FileStream = newFileStream(path, fmReadWriteExisting)
  fs.patchClient(patchConfig)
  fs.close()


# when isMainModule:
#   import os
#   # copyFile("BF2142.exe.org", "BF2142.exe")
#   let ipStr: string = "stella.ms5.openspy.net" # "157.245.212.59"
#   # var ip: IpAddress
#   # try:
#   #   ip = parseIpAddress(ipStr)
#   # except ValueError:
#   #   echo "ERROR: '", ipStr, "' is not a valid IP-Address!"
#   #   quit(1)
#   # if ip.family == IPv6:
#   #   echo "Error: IPv6 not allowed!"
#   #   quit(1)
#   var path: string = "/home/dankrad/.wine_bf2142/drive_c/Program Files (x86)/Electronic Arts/Battlefield 2142/BF2142.exe"
#   var fs: FileStream = newFileStream(path, fmReadWriteExisting)
#   fs.patchClient(ipStr, Port(8085), "157.245.212.59".parseIpAddress(), Port(8085))
#   fs.close()
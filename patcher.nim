import streams
import net
import strutils # Required for parseHexInt proc
import options

proc writeIpReversed(fs: FileStream, pos: int, ip: IpAddress) =
  var len: int = ip.address_v4.len - 1
  fs.setPosition(pos)
  for i in 0..len:
    fs.write(ip.address_v4[len - i])

proc writeIpStr(fs: FileStream, pos: int, ip: IpAddress, port: Option[Port], writeLen: int, addSlash: bool = false) =
  var data: string = $ip
  if port.isSome() and port.get().int != 80:
    data.add(":" & $port.get())
  if addSlash:
    data.add('/')
  fs.setPosition(pos)
  fs.write(data)
  for i in 1..writeLen - data.len:
    fs.write(byte(0x0))

proc patchServer*(fs: FileStream, ip: IpAddress, port: Port) =
  when defined(linux):
    when defined(cpu32):
      fs.writeIpStr(parseHexInt("869727"), ip, some(port), 24, true)
    else:
      fs.writeIpStr(parseHexInt("768FA7"), ip, some(port), 24, true)
  elif defined(windows): # TODO: Only 32 bit implemented
    fs.writeIpStr(parseHexInt("3CE617"), ip, some(port), 24, true)

proc patchServer*(path: string, ip: IpAddress, port: Port) =
  var fs: FileStream = newFileStream(path, fmReadWriteExisting)
  fs.patchServer(ip, port)
  fs.close()

proc patchClient*(fs: FileStream, ip: IpAddress, port: Port) =
  ## Previously preClientPatch
  fs.setPosition(parseHexInt("3293B0"))
  fs.write(byte(0x90))
  fs.write(byte(0x90))
  fs.setPosition(parseHexInt("3293B3"))
  fs.write(byte(0x35))
  fs.setPosition(parseHexInt("3293C1"))
  fs.write(byte(0x30))
  fs.write(byte(0xF2))
  fs.setPosition(parseHexInt("3293CF"))
  fs.write(byte(0x92))
  fs.setPosition(parseHexInt("3293D0"))
  fs.write(byte(0x94))
  fs.setPosition(parseHexInt("45C97A"))
  fs.write(byte(0x88))
  fs.write(byte(0x1F))
  fs.write(byte(0xB5))
  fs.setPosition(parseHexInt("45C981"))
  fs.write(byte(0xC7))
  fs.write(byte(0x46))
  fs.write(byte(0x04))
  fs.setPosition(parseHexInt("45C988"))
  fs.write(byte(0xC7))
  fs.write(byte(0x06))
  fs.write(byte(0x01))
  fs.write(byte(0x00))
  fs.write(byte(0x00))
  fs.write(byte(0x00))
  fs.write(byte(0xEB))
  fs.write(byte(0x2A))
  fs.setPosition(parseHexInt("45C9D8"))
  fs.write(byte(0x94))
  fs.write(byte(0x97))
  fs.setPosition(parseHexInt("45FE8D"))
  fs.write(byte(0xB8))
  fs.write(byte(0x15))
  fs.write(byte(0x00))
  fs.write(byte(0x00))
  fs.write(byte(0x00))
  #
  # TODO: Info: The following patch length is the minimum length to patch the whole original string.
  #             Some can be longer but not more then 23 (third patch .. should also check if this patch
  #             is necessary for e.g. tcp/udp or if it's not requiered)
  fs.writeIpReversed(parseHexInt("45C984"), ip)
  fs.writeIpStr(parseHexInt("5639AB"), ip, some(port), 24, true)
  fs.writeIpStr(parseHexInt("5639C4"), ip, none(Port), 23)
  fs.writeIpStr(parseHexInt("59E93F"), ip, some(port), 30, true) # TODO: Patch length 30 (cuts of motd/motd.asp original: motd.gamespy.com/motd/motd.asp), check if it's requierd
  fs.writeIpStr(parseHexInt("59E97C"), ip, none(Port), 21) # TODO: Check if it's requierd
  fs.writeIpStr(parseHexInt("59F608"), ip, none(Port), 19) # TODO: Check if it's requierd
  fs.writeIpStr(parseHexInt("6067A0"), ip, none(Port), 21) # TODO: Check if it's requierd
  fs.writeIpStr(parseHexInt("607180"), ip, none(Port), 16) # TODO: Check if it's requierd
  fs.writeIpStr(parseHexInt("6071C0"), ip, none(Port), 16) # TODO: Check if it's requierd
  # Patching "Large Address Aware" from 2GB to 4GB
  fs.setPosition(parseHexInt("00000146"))
  fs.write(byte(0x2E))

proc patchClient*(path: string, ip: IpAddress, port: Port) =
  var fs: FileStream = newFileStream(path, fmReadWriteExisting)
  fs.patchClient(ip, port)
  fs.close()

when isMainModule:
  import os
  # copyFile("BF2142.exe.org", "BF2142.exe")
  let ipStr: string = "192.168.1.197"
  var ip: IpAddress
  try:
    ip = parseIpAddress(ipStr)
  except ValueError:
    echo "ERROR: '", ipStr, "' is not a valid IP-Address!"
    quit(1)
  if ip.family == IPv6:
    echo "Error: IPv6 not allowed!"
    quit(1)
  var path: string = "/home/dankrad/.wine_bf2142/drive_c/Program Files (x86)/Electronic Arts/Battlefield 2142/BF2142.exe"
  var fs: FileStream = newFileStream(path, fmReadWriteExisting)
  fs.patchClient(ip, Port(8085))
  fs.close()
import nativesockets
import strutils
import tables

when defined(windows):
  import winim
  import strutils
  import bitops

  iterator adapterInfos(pIpAdapterInfo: PIP_ADAPTER_INFO): PIP_ADAPTER_INFO =
    var tmpPIpAdapterInfo: PIP_ADAPTER_INFO = pIpAdapterInfo
    yield tmpPIpAdapterInfo
    while not tmpPIpAdapterInfo.Next.isNil:
      tmpPIpAdapterInfo = tmpPIpAdapterInfo.Next
      yield tmpPIpAdapterInfo

  iterator ipAddressLists(ipAddrString: IP_ADDR_STRING): IP_ADDR_STRING =
    var tmpIpAddrString: IP_ADDR_STRING = ipAddrString
    yield tmpIpAddrString
    while not tmpIpAddrString.Next.isNil:
      tmpIpAddrString = cast[IP_ADDR_STRING](tmpIpAddrString.Next)
      yield tmpIpAddrString

  ### PSUTILS
  type Address* = object of RootObj
      family*: uint16  # int # TODO
      address*: string
      netmask*: string
      broadcast*: string
      ptp*: string # TODO

  proc calcBroadcastAddr(ipAddr: string, netmask: string): string =
    var ipAddrSeq: seq[string] = ipAddr.split('.')
    var netmaskSeq: seq[string] = netmask.split('.')
    var braodcastSeq: seq[uint8]
    for idx in 0..3:
      braodcastSeq.add(parseInt(ipAddrSeq[idx]).uint8 or bitnot(parseInt(netmaskSeq[idx]).uint8))
    return braodcastSeq.join(".")

  proc net_if_addrs*(): OrderedTable[string, seq[Address]] =
    var size: ULONG = 0
    discard GetAdaptersInfo(nil, addr size) # Reads out required memory size
    var pIpAdapterInfo: PIP_ADAPTER_INFO = cast[PIP_ADAPTER_INFO](alloc(size)) # Allocate required size read out before
    discard GetAdaptersInfo(pIpAdapterInfo, addr size) # Reading adapter info into buffer

    var adapterName: string
    for adapterInfo in pIpAdapterInfo.adapterInfos:
      adapterName = $adapterInfo.Description.cstring
      result[adapterName] = @[]
      for ipAddrList in adapterInfo.IpAddressList.ipAddressLists:
        var address: Address
        address.family = Domain.AF_INET.uint16
        address.address = $ipAddrList.IpAddress.String.cstring
        address.netmask = $ipAddrList.IpMask.String.cstring
        address.broadcast = calcBroadcastAddr(address.address, address.netmask)
        result[adapterName].add(address)

    dealloc(pIpAdapterInfo)
  ##
else:
  import psutil
  export net_if_addrs
  import psutil/common
  export Address

proc pretty*(addrs: OrderedTable[string, seq[Address]] | Table[string, seq[Address]]): string =
  for adapterName, addresses in addrs.pairs():
    echo "Adapter: "
    echo "\tName: ", adapterName
    for address in addresses:
      echo "\tFamily: ", cast[Domain](address.family)
      echo "\tAddress: ", address.address
      echo "\tNetmask:", address.netmask
      echo "\tBroadcast:", address.broadcast

proc getLocalAddrs*(): seq[string] =
  for nic, addrs in net_if_addrs():
    for localAddr in addrs:
      if localAddr.family == Domain.AF_INET.uint16:
        if not localAddr.address.startsWith("127") and not localAddr.address.startsWith("0."):
          result.add localAddr.address

proc getPrivateAddrs*(): seq[string] =
  for nic, addrs in net_if_addrs():
    for localAddr in addrs:
      if localAddr.family == Domain.AF_INET.uint16:
        if localAddr.address.startsWith("10.") or
        localAddr.address.startsWith("172.") or
        localAddr.address.startsWith("192."):
          result.add localAddr.address

when isMainModule:
  echo getLocalAddrs()
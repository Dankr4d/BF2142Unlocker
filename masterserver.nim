import net
import strutils

proc gsvalfunc(reg: int): char =
  if reg < 26:
    return char(reg + int('A'))
  if reg < 52:
    return char(reg + int('G'))
  if reg < 62:
    return char(reg - 4)
  if reg == 62:
    return '+'
  if reg == 63:
    return '/'
  return char(0)

proc gsseckey(dst: var string, src: var string, key: string, enctype: int): string =
  var i, x, y, num, num2, size, keysz: int
  var enctmp: string
  enctmp.setLen(256)
  dst.setLen(43)
  var p: ptr string
  let enctype1_data: string =
    "\x01\xba\xfa\xb2\x51\x00\x54\x80\x75\x16\x8e\x8e\x02\x08\x36\xa5" &
    "\x2d\x05\x0d\x16\x52\x07\xb4\x22\x8c\xe9\x09\xd6\xb9\x26\x00\x04" &
    "\x06\x05\x00\x13\x18\xc4\x1e\x5b\x1d\x76\x74\xfc\x50\x51\x06\x16" &
    "\x00\x51\x28\x00\x04\x0a\x29\x78\x51\x00\x01\x11\x52\x16\x06\x4a" &
    "\x20\x84\x01\xa2\x1e\x16\x47\x16\x32\x51\x9a\xc4\x03\x2a\x73\xe1" &
    "\x2d\x4f\x18\x4b\x93\x4c\x0f\x39\x0a\x00\x04\xc0\x12\x0c\x9a\x5e" &
    "\x02\xb3\x18\xb8\x07\x0c\xcd\x21\x05\xc0\xa9\x41\x43\x04\x3c\x52" &
    "\x75\xec\x98\x80\x1d\x08\x02\x1d\x58\x84\x01\x4e\x3b\x6a\x53\x7a" &
    "\x55\x56\x57\x1e\x7f\xec\xb8\xad\x00\x70\x1f\x82\xd8\xfc\x97\x8b" &
    "\xf0\x83\xfe\x0e\x76\x03\xbe\x39\x29\x77\x30\xe0\x2b\xff\xb7\x9e" &
    "\x01\x04\xf8\x01\x0e\xe8\x53\xff\x94\x0c\xb2\x45\x9e\x0a\xc7\x06" &
    "\x18\x01\x64\xb0\x03\x98\x01\xeb\x02\xb0\x01\xb4\x12\x49\x07\x1f" &
    "\x5f\x5e\x5d\xa0\x4f\x5b\xa0\x5a\x59\x58\xcf\x52\x54\xd0\xb8\x34" &
    "\x02\xfc\x0e\x42\x29\xb8\xda\x00\xba\xb1\xf0\x12\xfd\x23\xae\xb6" &
    "\x45\xa9\xbb\x06\xb8\x88\x14\x24\xa9\x00\x14\xcb\x24\x12\xae\xcc" &
    "\x57\x56\xee\xfd\x08\x30\xd9\xfd\x8b\x3e\x0a\x84\x46\xfa\x77\xb8"
  echo "enctype1_data.len: ", enctype1_data.len

  # /* 1) buffer creation with incremental data */
  p = enctmp.addr
#   for(i = 0; i < 256; i++) {
#       *p++ = i;
#   }
  for i in 0..255:
    p[i] = i.char;

#   # /* 2) buffer scrambled with key */
#   keysz = strlen(key);
#   p = enctmp;
#   for(i = num = 0; i < 256; i++) {
#       num = (num + *p + key[i % keysz]) & 0xff;
#       x = enctmp[num];
#       enctmp[num] = *p;
#       *p++ = x;
#   }
  keysz = key.len
  p = enctmp.addr
  num = 0
  for i in 0..255:
    num = (num + p[i].int + key[i mod keysz].int) and 0xff;
    x = enctmp[num].int
    enctmp[num] = p[i]
    p[i] = x.char


#   # /* 3) source string scrambled with the buffer */
#   p = src;
#   num = num2 = 0;
#   while(*p) {
#       num = (num + *p + 1) & 0xff;
#       x = enctmp[num];
#       num2 = (num2 + x) & 0xff;
#       y = enctmp[num2];
#       enctmp[num2] = x;
#       enctmp[num] = y;
#       *p++ ^= enctmp[(x + y) & 0xff];
#   }
#   size = p - src;
  p = src.addr
  num = 0
  num2 = 0
  var pIdx: int = 0
  while pIdx < p[].len:
    num = (num + p[pIdx].int + 1) and 0xff
    x = enctmp[num].int
    num2 = (num2 + x) and 0xff
    y = enctmp[num2].int
    enctmp[num2] = x.char
    enctmp[num] = y.char
    p[pIdx] = (p[pIdx].int xor enctmp[(x + y) and 0xff].int).char
    pIdx.inc()
  # }
  size = (cast[int](p) + pIdx) - cast[int](src.addr)
  # block: # TODO: Remove, just for testing
  #   echo "(cast[int](p) + pIdx): ", (cast[int](p) + pIdx)
  #   echo "cast[int](src.addr): ", cast[int](src.addr)
  #   echo "size: ", size

#   # /* 4) enctype management */
#   if(enctype == 1) {
#       for(i = 0; i < size; i++) {
#           src[i] = enctype1_data[src[i]];
#       }

#   } else if(enctype == 2) {
#       for(i = 0; i < size; i++) {
#           src[i] ^= key[i % keysz];
#       }
#   }
  if enctype == 1:
    for i in 0..size - 1:
      let charIdx: int = src[i].int
      src[i] = enctype1_data[charIdx]
  elif enctype == 2:
    for i in 0..size - 1:
      src[i] = (src[i].int xor key[i mod keysz].int).char

#   # /* 5) splitting of the source string from 3 to 4 bytes */
#   p = dst;
#   size /= 3;
#   while(size--) {
#     x = *src++;
#     y = *src++;
#     *p++ = gsvalfunc(x >> 2);
#     *p++ = gsvalfunc(((x & 3) << 4) | (y >> 4));
#     x = *src++;
#     *p++ = gsvalfunc(((y & 15) << 2) | (x >> 6));
#     *p++ = gsvalfunc(x & 63);
#   }
#   *p = 0;
  p = dst.addr
  size = int(size / 3)
  var srcIdx: int
  srcIdx = 0
  pIdx = 0
  while size > 0:
    x = src[srcIdx].int
    srcIdx.inc()
    y = src[srcIdx].int
    srcIdx.inc()
    p[pIdx] = gsvalfunc(x shr 2)
    pIdx.inc()
    p[pIdx] = gsvalfunc(((x and 3) shl 4) or (y shr 4))
    pIdx.inc()
    x = src[srcIdx].int
    srcIdx.inc()
    p[pIdx] = gsvalfunc(((y and 15) shl 2) or (x shr 6))
    pIdx.inc()
    p[pIdx] = gsvalfunc(x and 63);
    pIdx.inc()
    size.dec()
  # p[pIdx] = 0.char

  return dst

proc queryGameServerListEnc1*(url: string, port: Port): seq[tuple[ip: IpAddress, port: Port]] =
  var client: Socket = newSocket()
  client.connect(url, port)
  var resp: string
  try:
    discard client.recv(resp, 512, 5000)
  except TimeoutError:
    discard
  # echo repr resp

  var secureCode: string = resp[15 .. 20]
  var validate: string
  var msggamekey: string = "FIlaPo" # "M8o1Qw" # "d4kZca"
  var enctype: int = 1

  echo "secureCode: ", secureCode

  discard gsseckey(validate, secureCode, msggamekey, enctype);

  var msgamename: string = "bf2142" #"gamespy2\\gamever\\20603020"
  var gamestr: string = "stella"
  var dataTest: string = "\\gamename\\$1\\enctype\\$2\\validate\\$3\\final\\\\list\\cmp\\gamename\\$4" % [msgamename, $enctype, validate, gamestr]

  client.send(dataTest)
  try:
    discard client.recv(resp, 512, 1000)
  except TimeoutError:
    discard
  # echo repr resp

  var respLen: cint = resp.len.cint
  # var decoded: string = $enctype1_decoder(secureCodeUnmodified.cstring, resp.cstring, respLen.unsafeAddr)
  var decoded: string = $resp.cstring
  decoded = decoded.replace("\\final\\", "")

  var idx: int = 0
  while true:
    if idx + 5 >= decoded.len:
    # if idx >= decoded.len:
      break
    result.add(
      (
        ip: parseIpAddress($decoded[idx].uint8 & "." & $decoded[idx+1].uint8 & "." & $decoded[idx+2].uint8 & "." & $decoded[idx+3].uint8),
        port: Port(256*decoded[idx+4].uint8+decoded[idx+5].uint8)
      )
    )
    idx += 6


################################################################


import net
import strutils

const BUFFER_SIZE: cint = 8192

when defined(linux):
  import posix
elif defined(windows):
  import winlean

template `+`*[T](p: ptr T, off: int): ptr T =
  cast[ptr type(p[])](cast[ByteAddress](p) +% off * sizeof(p[]))
# template `+=`*[T](p: ptr T, off: int) =
#   p = p + off
template `-`*[T](p: ptr T, off: int): ptr T =
  cast[ptr type(p[])](cast[ByteAddress](p) -% off * sizeof(p[]))
# template `-=`*[T](p: ptr T, off: int) =
#   p = p - off
template `[]`*[T](p: ptr T, off: int): T =
  (p + off)[]
# template `[]=`*[T](p: ptr T, off: int, val: T) =
#   (p + off)[] = val


type enctypex_data_t = object # {.importc, header: "masterserver.h".} = object
  encxkey: array[261, cuchar]
  offset: cint
  start: cint

type ipport_t {.packed.} = object
  ip: uint32
  port: uint16

# unsigned char *enctypex_decoder(unsigned char *key, unsigned char *validate, unsigned char *data, int *datalen, enctypex_data_t *enctypex_data)
proc enctypex_decoder(key: ptr cuchar, validate: ptr cuchar, data: ptr cuchar, datalen: ptr cint, enctypex_data: ptr enctypex_data_t): ptr cuchar {.importc, cdecl, header: "masterserver.h".}

# int enctypex_decoder_convert_to_ipport(unsigned char *data, int datalen, unsigned char *out, unsigned char *infobuff, int infobuff_size, int infobuff_offset)
proc enctypex_decoder_convert_to_ipport(data: ptr cuchar, datalen: cint, `out`: ptr cuchar, infobuff: ptr cuchar, infobuff_size: cint, infobuff_offset: cint): cint {.importc, cdecl, header: "masterserver.h".}


# int tcpxspr(int sd, u8 *gamestr, u8 *msgamestr, u8 *validate, u8 *filter, u8 *info, int type)
proc tcpxspr(sd: cint, gamestr: ptr uint8, msgamestr: ptr uint8, validate: ptr uint8, filter: ptr uint8, info: ptr uint8, `type`: cint): cint {.importc, cdecl, header: "masterserver.h".}

# int enctypex_decoder_rand_validate(unsigned char *validate)
proc enctypex_decoder_rand_validate(validate: ptr cuchar): cint {.importc, cdecl, header: "masterserver.h".}


proc queryGameServerList*(url: string, port: Port, gameName, gameKey, gameStr: string): seq[tuple[address: IpAddress, port: Port]] =
  var client: Socket = newSocket()
  client.connect(url, port)

  var msgamename: ptr uint8 = cast[ptr uint8](gameName.cstring)
  var msgamekey: ptr uint8 = cast[ptr uint8](gameKey.cstring)
  var gamestr: ptr uint8 = cast[ptr uint8](gameStr.cstring)

  var validate: ptr cuchar # Random id on russian server because there's no encryption
  validate = validate.resize(8)
  discard enctypex_decoder_rand_validate(validate)

  var filterEmpty: uint8 = 0
  var filter: ptr uint8 = cast[ptr uint8](addr(filterEmpty))
  # var filterCstr: cstring = "" # TODO: Doesn't work, why?
  # var filter: ptr uint8 = cast[ptr uint8](addr(filterCstr)) # TODO: Doesn't work, why?
  # echo repr cast[ptr cuchar](filter)

  var enctypex_queryEmpty: uint8 = 0
  var enctypex_query: ptr uint8 = cast[ptr uint8](addr(enctypex_queryEmpty))
  # var enctypex_queryCstr: cstring = "" # TODO: Doesn't work, why?
  # var enctypex_query: ptr uint8 = cast[ptr uint8](addr(enctypex_queryCstr)) # TODO: Doesn't work, why?
  # echo repr cast[ptr cuchar](enctypex_query)

  var enctypex_type: cint = 1

  # echo "Gamename: ", cast[ptr cuchar](msgamename)
  # echo "Enctype: ", enctypex_type
  # echo "Gamestr: ", cast[ptr cuchar](gamestr)
  # echo "MSgamekey: ", cast[ptr cuchar](msgamekey)
  # echo "Random id: ", validate.cstring

  # TODO: Implement functionality to communicate to port 28900 with encryption set.
  #       In gslist the encryption method is stored in myenctype and not in enctypex_type [if(myenctype < 0) {]

  discard tcpxspr(client.getFd().cint,
    gamestr,
    msgamename,
    cast[ptr uint8](validate),
    filter,
    enctypex_query,
    enctypex_type)


  var buffer: ptr cuchar
  buffer = buffer.resize(BUFFER_SIZE)

  # when defined(linux): # TODO: Add timeout
  #   var tv: Timespec
  #   tv.tv_sec = 5000.Time
  #   tv.tv_nsec = 0
  #   echo "setsockopt: ", setsockopt(client.getFd(), SOL_SOCKET, SO_RCVTIMEO, cast[pointer](addr(tv)), BUFFER_SIZE.SOCK_LEN)


  var len: cint
  try:
    # Info: lowlevel recv nim function returns 0 bytes read (len) if it runs into timeout
    len = client.getFd().recv(buffer, BUFFER_SIZE, 0).cint
  except TimeoutError:
    discard


  var ipport: ptr ipport_t
  var enctypex_data: enctypex_data_t
  ipport = cast[ptr ipport_t](enctypex_decoder(cast[ptr cuchar](msgamekey), validate, buffer, len.addr, enctypex_data.addr))

  var enctypextmp: ptr uint8
  enctypextmp = enctypextmp.resize(((len / 5) * 6).int);
  len = enctypex_decoder_convert_to_ipport(buffer + enctypex_data.start, len - enctypex_data.start, cast[ptr cuchar](enctypextmp), nil, 0, 0)

  ipport = cast[ptr ipport_t](enctypextmp)

  # echo "Server amount: ", (len/6).int
  var inAddr: InAddr
  for idx in 0..(len/6).int - 1:
    inAddr.s_addr = ipport[idx].ip
    # echo inetNtoa(inAddr), ":", ntohs(ipport[idx].port)
    result.add(
      (
        address: parseIpAddress($inetNtoa(inAddr)),
        port: Port(ntohs(ipport[idx].port))
      )
    )

when isMainModule:
  var gameServerList: seq[tuple[address: IpAddress, port: Port]]
  # gameServerList = queryGameServerList("2142.novgames.ru", Port(28910), "stella", "M8o1Qw", "stella")
  # echo "gameServerList (NOVGAMES): ", gameServerList

  # gameServerList = queryGameServerList("stella.ms5.openspy.net", Port(28910), "gslive", "Xn221z", "stella")
  # echo "gameServerList (OPENSPY): ", gameServerList

  gameServerList = queryGameServerList("92.51.181.102", Port(28911), "battlefield2", "hW6m9a", "battlefield2")
  echo "gameServerList (BF2HUB): ", gameServerList

  # gameServerList = queryGameServerListEnc1("stella.ms5.openspy.net", Port(28900))
  # echo "gameServerList ENC1 (OPENSPY): ", gameServerList
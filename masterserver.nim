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
  block: # TODO: Remove, just for testing
    echo "(cast[int](p) + pIdx): ", (cast[int](p) + pIdx)
    echo "cast[int](src.addr): ", cast[int](src.addr)
    echo "size: ", size

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

################################################################

proc queryGameServerList*(url: string, port: Port): seq[tuple[ip: IpAddress, port: Port]] =
  var client: Socket = newSocket()
  client.connect(url, port)
  var resp: string
  try:
    discard client.recv(resp, 512, 5000)
  except TimeoutError:
    discard
  echo repr resp

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
  echo repr resp

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

when isMainModule:
  var gameServerList: seq[tuple[ip: IpAddress, port: Port]] = queryGameServerList("stella.ms5.openspy.net", Port(28900))
  # var gameServerList: seq[tuple[ip: IpAddress, port: Port]] = queryGameServerList("2142.novgames.ru", Port(28910))
  echo "gameServerList: ", gameServerList
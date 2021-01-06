import math
import strutils
import base64

const LOGINS_XOR_X: string = "x"
const LOGINS_XOR_STR {.strdefine.}: string = """%Zx;x@g[Ne`tPP!F1yaC5g\IE24oCeK,:G<,v;-bS`MRV#^G9\MAv+8f`xp.=4P'jUX*~T?tkyYF;``8L}R?V+?9'S\z3RTAQWG''oTG@NiPLFL'H|uaP{5;6L4#"R&2"""


proc `xor`(str1, str2: string): string =
  if str1.len != str2.len:
    raise newException(ValueError, "str1.len != str2.len")
  for idx in 0..str1.high:
    result.add(char(uint8(str1[idx]) xor uint8(str2[idx])))

let LOGINS_XOR: string = LOGINS_XOR_STR xor LOGINS_XOR_X.repeat(LOGINS_XOR_STR.len)

proc strXor(password: string, xorKey: string = LOGINS_XOR): string =
  let xorAmount: int = int(ceil(password.len / xorKey.len))
  let xorKey: string = xorKey.repeat(xorAmount)
  let passwordPadded: string = password.alignLeft(xorKey.len, '\0')
  return passwordPadded xor xorKey

proc hideStr*(password: string, xorKey: string = LOGINS_XOR): string =
  return base64.encode(strXor(password, xorKey))

proc showStr*(password: string, xorKey: string = LOGINS_XOR): string =
  return $strXor(base64.decode(password), xorKey).cstring


when isMainModule:
  let password: string = "MyRealRealHighSperDuperSecurePassword123123"#.repeat(250)
  let passwordXOr1: string = password.hideStr()
  let passwordXOr2: string = passwordXOr1.showStr()
  let passwordXOr2Wrong: string = passwordXOr1.showStr("""&7MJd#3yn{4_kWow}6>;%y;=fM'r)f$(L['%qq0Pvbg^f83K}nd[$g+nE+|&nfpYfHEhIvD9@&LF3Zyc!ixqV*'Og}Zh.DbrTn7R(GlPD<aBPrk%+Rk/u~Mxf2-G"#5B""")

  echo "PasswordXOr1: ", passwordXOr1
  echo "Password.len: ", password.len
  echo "PasswordXOr2.len: ", passwordXOr2.len
  echo "Password: ", password
  echo "PasswordXOr2: ", passwordXOr2

  assert password == passwordXOr2
  assert password != passwordXOr2Wrong


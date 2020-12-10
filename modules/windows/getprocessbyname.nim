import winim
import winim/winstr

proc getPidByName*(name: string): int =
  result = 0
  var entry: PROCESSENTRY32 # TODO: Replace With PROCESSENTRY32A to avoid widespace strings
  entry.dwSize = sizeof(PROCESSENTRY32).DWORD

  var snapshot: HANDLE = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)

  if Process32First(snapshot, addr(entry)) == TRUE:
    while Process32Next(snapshot, addr(entry)) == TRUE:
      var exeFileName: string = winstr.`$`(entry.szExeFile)
      exeFileName = $exeFileName.cstring # Necessary for the winstr.`$` proc or the string is not null terminated and > 200 len
      if exeFileName == name:
        result = entry.th32ProcessID
        break
  CloseHandle(snapshot)
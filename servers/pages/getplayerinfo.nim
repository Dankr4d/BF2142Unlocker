import asynchttpserver, asyncdispatch
from times import epochTime
from strutils import multiReplace
import tables # Query params
from strutils import split # Query params

proc handleGetPlayerInfo*(req: Request, params: Table[string, string]) {.async.} =
  var isServer: bool = false # TODO: Fix this
  var body: string
  body = "O\n"
  body &= "H\tasof\tcb\n"
  body &= "D\t" & $epochTime().toInt & "\t"
  body &= (if isServer: "server" else: "client") & '\n'

  body &= "H\t"
  body &= "p.pid\tsubaccount\ttid\tgsco\trnk\ttac\tcs\ttt\tcrpt\tklstrk\tbnspt\tdstrk\trps\tresp\ttasl\ttasm\tawybt\thls\tsasl\t"
  body &= "tds\twin\tlos\tunlc\texpts\tcpt\tdcpt\ttwsc\ttcd\tslpts\ttcrd\tmd\tent\tent-1\tent-2\tent-3\tbp-1\twtp-30\thtp\thkl\t"
  body &= "atp\takl\tvtp-0\tvtp-1\tvtp-2\tvtp-3\tvtp-4\tvtp-5\tvtp-6\tvtp-7\tvtp-8\tvtp-9\tvtp-10\tvtp-11\tvtp-12\tvtp-13\tvtp-14\t"
  body &= "vtp-15\tvkls-0\tvkls-1\tvkls-2\tvkls-3\tvkls-4\tvkls-5\tvkls-6\tvkls-7\tvkls-8\tvkls-9\tvkls-10\tvkls-11\tvkls-12\tvkls-13\t"
  body &= "vkls-14\tvkls-15\tvdstry-0\tvdstry-1\tvdstry-2\tvdstry-3\tvdstry-4\tvdstry-5\tvdstry-6\tvdstry-7\tvdstry-8\tvdstry-9\t"
  body &= "vdstry-10\tvdstry-11\tvdstry-12\tvdstry-13\tvdstry-14\tvdstry-15\tvdths-0\tvdths-1\tvdths-2\tvdths-3\tvdths-4\tvdths-5\t"
  body &= "vdths-6\tvdths-7\tvdths-8\tvdths-9\tvdths-10\tvdths-11\tvdths-12\tvdths-13\tvdths-14\tvdths-15\tktt-0\tktt-1\tktt-2\tktt-3\t"
  body &= "wkls-0\twkls-1\twkls-2\twkls-3\twkls-4\twkls-5\twkls-6\twkls-7\twkls-8\twkls-9\twkls-10\twkls-11\twkls-12\twkls-13\twkls-14\t"
  body &= "wkls-15\twkls-16\twkls-17\twkls-18\twkls-19\twkls-20\twkls-21\twkls-22\twkls-23\twkls-24\twkls-25\twkls-26\twkls-27\twkls-28\t"
  body &= "wkls-29\twkls-30\twkls-31\tklsk\tklse\tetp-0\tetp-1\tetp-2\tetp-3\tetp-4\tetp-5\tetp-6\tetp-7\tetp-8\tetp-9\tetp-10\tetp-11\t"
  body &= "etp-12\tetp-13\tetp-14\tetp-15\tetp-16\tetpk-0\tetpk-1\tetpk-2\tetpk-3\tetpk-4\tetpk-5\tetpk-6\tetpk-7\tetpk-8\tetpk-9\t"
  body &= "etpk-10\tetpk-11\tetpk-12\tetpk-13\tetpk-14\tetpk-15\tetpk-16\tattp-0\tattp-1\tawin-0\tawin-1\ttgpm-0\ttgpm-1\ttgpm-2\tkgpm-0\t"
  body &= "kgpm-1\tkgpm-2\tbksgpm-0\tbksgpm-1\tbksgpm-2\tctgpm-0\tctgpm-1\tctgpm-2\tcsgpm-0\tcsgpm-1\tcsgpm-2\ttrpm-0\ttrpm-1\ttrpm-2\t"
  body &= "klls\tattp-0\tattp-1\tawin-0\tawin-1\tpdt\tmtt-0-0\tmtt-0-1\tmtt-0-3\tmtt-0-4\tmtt-0-5\tmtt-0-6\tmtt-0-7\tmtt-0-8\tmtt-0-9\t"
  body &= "mwin-0-0\tmwin-0-1\tmwin-0-3\tmwin-0-4\tmwin-0-5\tmwin-0-6\tmwin-0-7\tmwin-0-8\tmwin-0-9\tmbr-0-0\tmbr-0-1\tmbr-0-3\tmbr-0-4\t"
  body &= "mbr-0-5\tmbr-0-6\tmbr-0-7\tmbr-0-8\tmbr-0-9\tmkls-0-0\tmkls-0-1\tmkls-0-3\tmkls-0-4\tmkls-0-5\tmkls-0-6\tmkls-0-7\tmkls-0-8\t"
  body &= "mkls-0-9\tmtt-1-0\tmtt-1-1\tmtt-1-2\tmtt-1-3\tmtt-1-5\tmwin-1-0\tmwin-1-1\tmwin-1-2\tmwin-1-3\tmwin-1-5\tmlos-1-0\tmlos-1-1\t"
  body &= "mlos-1-2\tmlos-1-3\tmlos-1-5\tmbr-1-0\tmbr-1-1\tmbr-1-2\tmbr-1-3\tmbr-1-5\tmsc-1-0\tmsc-1-1\tmsc-1-2\tmsc-1-3\tmsc-1-5\t"
  body &= "mkls-1-0\tmkls-1-1\tmkls-1-2\tmkls-1-3\tmkls-1-5\tid\tprofileid\tsubaccount\tpid\tacdt\tlgdt\tnick\trnk\trnkcg\tgsco\t"
  body &= "crpt\tawaybonus\tbrs\tcpt\tcapa\tcts\tcs\tban\tovaccu\tpdt\tpdtc\tcsgpm-0\tcsgpm-1\tcsgpm-2\tdass\tdcpt\tkpm\tdpm\tspm\t"
  body &= "kdr\tdstrk\tdths\tkkls-0\tkkls-1\tkkls-2\tkkls-3\tktt-0\tktt-1\tktt-2\tktt-3\tklla\tklls\tklstrk\tkluav\tfe\tfgm\tfk\tfm\t"
  body &= "fv\tfw\tcotime\tsltime\tsmtime\tlwtime\tcaptures\tassist\tdefend\twaccu\tate\twins\tlos\ttwsc\thls\trps\trvs\tresp\tsasl\t"
  body &= "slbcn\tslbspn\tslpts\tsluav\tsuic\ttac\ttalw\ttas\ttasl\ttasm\ttcd\ttcrd\ttdmg\ttdrps\ttds\ttgd\ttgr\ttid\ttkls\ttoth\ttots\t"
  body &= "trp\ttt\ttvdmg\tunavl\tunlc\tkick\tncpt\tkdths-0\tkdths-1\tkdths-2\tkdths-3\tvet\tetp-0\tetp-1\tetp-2\tetp-3\tetp-4\tetp-5\t"
  body &= "etp-6\tetp-7\tetp-8\tetp-9\tetp-10\tetp-11\tetpk-0\tetpk-1\tetpk-2\tetpk-3\tetpk-4\tetpk-5\tetpk-6\tetpk-7\tetpk-8\tetpk-9\t"
  body &= "etpk-10\tetpk-11\tgm\tmapid\tmbr\tmwin\tmlos\tmsc\tmtt\tvdstry-0\tvdstry-1\tvdstry-2\tvdstry-3\tvdstry-4\tvdstry-5\tvdstry-6\t"
  body &= "vdstry-7\tvdstry-8\tvdstry-9\tvdstry-10\tvdstry-11\tvdstry-12\tvdstry-13\tvdths-0\tvdths-1\tvdths-2\tvdths-3\tvdths-4\tvdths-5\t"
  body &= "vdths-6\tvdths-7\tvdths-8\tvdths-9\tvdths-10\tvdths-11\tvdths-12\tvdths-13\tvkdr-0\tvkdr-1\tvkdr-2\tvkdr-3\tvkdr-4\tvkdr-5\t"
  body &= "vkdr-6\tvkdr-7\tvkdr-8\tvkdr-9\tvkdr-10\tvkdr-11\tvkdr-12\tvkdr-13\tvkls-0\tvkls-1\tvkls-2\tvkls-3\tvkls-4\tvkls-5\tvkls-6\t"
  body &= "vkls-7\tvkls-8\tvkls-9\tvkls-10\tvkls-11\tvkls-12\tvkls-13\tvrkls-0\tvrkls-1\tvrkls-2\tvrkls-3\tvrkls-4\tvrkls-5\tvrkls-6\t"
  body &= "vrkls-7\tvrkls-8\tvrkls-9\tvrkls-10\tvrkls-11\tvrkls-12\tvrkls-13\tvtp-0\tvtp-1\tvtp-2\tvtp-3\tvtp-4\tvtp-5\tvtp-6\tvtp-7\t"
  body &= "vtp-8\tvtp-9\tvtp-10\tvtp-11\tvtp-12\tvtp-13\tvbf-0\tvbf-1\tvbf-2\tvbf-3\tvbf-4\tvbf-5\tvbf-6\tvbf-7\tvbf-8\tvbf-9\tvbf-10\t"
  body &= "vbf-11\tvbf-12\tvbf-13\tvbh-0\tvbh-1\tvbh-2\tvbh-3\tvbh-4\tvbh-5\tvbh-6\tvbh-7\tvbh-8\tvbh-9\tvbh-10\tvbh-11\tvbh-12\tvbh-13\t"
  body &= "vaccu-0\tvaccu-1\tvaccu-2\tvaccu-3\tvaccu-4\tvaccu-5\tvaccu-6\tvaccu-7\tvaccu-8\tvaccu-9\tvaccu-10\tvaccu-11\tvaccu-12\t"
  body &= "vaccu-13\twaccu-0\twaccu-1\twaccu-2\twaccu-3\twaccu-4\twaccu-5\twaccu-6\twaccu-7\twaccu-8\twaccu-9\twaccu-10\twaccu-11\t"
  body &= "waccu-12\twaccu-13\twaccu-14\twaccu-15\twaccu-16\twaccu-17\twaccu-18\twaccu-19\twaccu-20\twaccu-21\twaccu-22\twaccu-23\t"
  body &= "waccu-24\twaccu-25\twaccu-26\twaccu-27\twaccu-28\twaccu-29\twaccu-30\twaccu-31\twaccu-32\twaccu-33\twaccu-34\twaccu-35\t"
  body &= "waccu-36\twaccu-37\twaccu-38\twaccu-39\twaccu-40\twaccu-41\twaccu-42\twdths-0\twdths-1\twdths-2\twdths-3\twdths-4\twdths-5\t"
  body &= "wdths-6\twdths-7\twdths-8\twdths-9\twdths-10\twdths-11\twdths-12\twdths-13\twdths-14\twdths-15\twdths-16\twdths-17\twdths-18\t"
  body &= "wdths-19\twdths-20\twdths-21\twdths-22\twdths-23\twdths-24\twdths-25\twdths-26\twdths-27\twdths-28\twdths-29\twdths-30\t"
  body &= "wdths-31\twdths-32\twdths-33\twdths-34\twdths-35\twdths-36\twdths-37\twdths-38\twdths-39\twdths-40\twdths-41\twdths-42\t"
  body &= "whts-0\twhts-1\twhts-2\twhts-3\twhts-4\twhts-5\twhts-6\twhts-7\twhts-8\twhts-9\twhts-10\twhts-11\twhts-12\twhts-13\twhts-14\t"
  body &= "whts-15\twhts-16\twhts-17\twhts-18\twhts-19\twhts-20\twhts-21\twhts-22\twhts-23\twhts-24\twhts-25\twhts-26\twhts-27\twhts-28\t"
  body &= "whts-29\twhts-30\twhts-31\twhts-32\twhts-33\twhts-34\twhts-35\twhts-36\twhts-37\twhts-38\twhts-39\twhts-40\twhts-41\twhts-42\t"
  body &= "wkdr-0\twkdr-1\twkdr-2\twkdr-3\twkdr-4\twkdr-5\twkdr-6\twkdr-7\twkdr-8\twkdr-9\twkdr-10\twkdr-11\twkdr-12\twkdr-13\twkdr-14\t"
  body &= "wkdr-15\twkdr-16\twkdr-17\twkdr-18\twkdr-19\twkdr-20\twkdr-21\twkdr-22\twkdr-23\twkdr-24\twkdr-25\twkdr-26\twkdr-27\twkdr-28\t"
  body &= "wkdr-29\twkdr-30\twkdr-31\twkdr-32\twkdr-33\twkdr-34\twkdr-35\twkdr-36\twkdr-37\twkdr-38\twkdr-39\twkdr-40\twkdr-41\twkdr-42\t"
  body &= "wkls-0\twkls-1\twkls-2\twkls-3\twkls-4\twkls-5\twkls-6\twkls-7\twkls-8\twkls-9\twkls-10\twkls-11\twkls-12\twkls-13\twkls-14\t"
  body &= "wkls-15\twkls-16\twkls-17\twkls-18\twkls-19\twkls-20\twkls-21\twkls-22\twkls-23\twkls-24\twkls-25\twkls-26\twkls-27\twkls-28\t"
  body &= "wkls-29\twkls-30\twkls-31\twkls-32\twkls-33\twkls-34\twkls-35\twkls-36\twkls-37\twkls-38\twkls-39\twkls-40\twkls-41\twkls-42\t"
  body &= "wshts-0\twshts-1\twshts-2\twshts-3\twshts-4\twshts-5\twshts-6\twshts-7\twshts-8\twshts-9\twshts-10\twshts-11\twshts-12\t"
  body &= "wshts-13\twshts-14\twshts-15\twshts-16\twshts-17\twshts-18\twshts-19\twshts-20\twshts-21\twshts-22\twshts-23\twshts-24\t"
  body &= "wshts-25\twshts-26\twshts-27\twshts-28\twshts-29\twshts-30\twshts-31\twshts-32\twshts-33\twshts-34\twshts-35\twshts-36\t"
  body &= "wshts-37\twshts-38\twshts-39\twshts-40\twshts-41\twshts-42\twtp-0\twtp-1\twtp-2\twtp-3\twtp-4\twtp-5\twtp-6\twtp-7\twtp-8\t"
  body &= "wtp-9\twtp-10\twtp-11\twtp-12\twtp-13\twtp-14\twtp-15\twtp-16\twtp-17\twtp-18\twtp-19\twtp-20\twtp-21\twtp-22\twtp-23\t"
  body &= "wtp-24\twtp-25\twtp-26\twtp-27\twtp-28\twtp-29\twtp-30\twtp-31\twtp-32\twtp-33\twtp-34\twtp-35\twtp-36\twtp-37\twtp-38\t"
  body &= "wtp-39\twtp-40\twtp-41\twtp-42\twtpk-0\twtpk-1\twtpk-2\twtpk-3\twtpk-4\twtpk-5\twtpk-6\twtpk-7\twtpk-8\twtpk-9\twtpk-10\t"
  body &= "wtpk-11\twtpk-12\twtpk-13\twtpk-14\twtpk-15\twtpk-16\twtpk-17\twtpk-18\twtpk-19\twtpk-20\twtpk-21\twtpk-22\twtpk-23\twtpk-24\t"
  body &= "wtpk-25\twtpk-26\twtpk-27\twtpk-28\twtpk-29\twtpk-30\twtpk-31\twtpk-32\twtpk-33\twtpk-34\twtpk-35\twtpk-36\twtpk-37\twtpk-38\t"
  body &= "wtpk-39\twtpk-40\twtpk-41\twtpk-42\twbf-0\twbf-1\twbf-2\twbf-3\twbf-4\twbf-5\twbf-6\twbf-7\twbf-8\twbf-9\twbf-10\twbf-11\t"
  body &= "wbf-12\twbf-13\twbf-14\twbf-15\twbf-16\twbf-17\twbf-18\twbf-19\twbf-20\twbf-21\twbf-22\twbf-23\twbf-24\twbf-25\twbf-26\twbf-27\t"
  body &= "wbf-28\twbf-29\twbf-30\twbf-31\twbf-32\twbf-33\twbf-34\twbf-35\twbf-36\twbf-37\twbf-38\twbf-39\twbf-40\twbf-41\twbf-42\twbh-0\t"
  body &= "wbh-1\twbh-2\twbh-3\twbh-4\twbh-5\twbh-6\twbh-7\twbh-8\twbh-9\twbh-10\twbh-11\twbh-12\twbh-13\twbh-14\twbh-15\twbh-16\twbh-17\t"
  body &= "wbh-18\twbh-19\twbh-20\twbh-21\twbh-22\twbh-23\twbh-24\twbh-25\twbh-26\twbh-27\twbh-28\twbh-29\twbh-30\twbh-31\twbh-32\twbh-33\t"
  body &= "wbh-34\twbh-35\twbh-36\twbh-37\twbh-38\twbh-39\twbh-40\twbh-41\twbh-42\tadpr\twlr\tvaccu-14\tvaccu-15\tbp-1"

  body &= "D\t"
  body &= "0\t"
  body &= "GGGG\t" # Account name or subaccount name?!?
  body &= "0\t0\t40\t0\t0\t0\t57700\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t"
  body &= "1\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t"
  body &= "0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t"
  body &= "0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t"
  body &= "0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t"
  body &= "0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t"
  body &= "0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t\t"
  body &= "10000011\t" # Account id
  body &= "GGGG\t" # Account Name
  body &= "10000032\t" # Subaccount id
  body &= "1558095418\t0\t" # Account creation timestamp
  body &= "GGGG\t" # Subaccount name
  body &= "40\t" #Rank
  body &= "1\t0\t" # first value (1) could be "Ranked up?"
  body &= "57700\t" # Experience
  body &= "0\t0\t0\t0\t0\t0\t"
  body &= "0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t\t\t\t\t\t\t\t\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t"
  body &= "0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t\t\t\t\t0\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"
  body &= "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"
  body &= "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t0\t0\t0\t0\t"
  body &= "0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"
  body &= "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"
  body &= "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"
  body &= "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"
  body &= "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"
  body &= "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"
  body &= "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t0\t0\t0\t0\t1"

  body &= '\n'
  body &= "H\tUnlockID\n"
  # Unlocks for every kit and at least special unlocks for all kits
  body &= "D\t115\n" # 1 = Kit, 1 = Unlock row, 5 = Unlocked to item 5 (last item)
  body &= "D\t125\n"
  body &= "D\t215\n"
  body &= "D\t225\n"
  body &= "D\t315\n"
  body &= "D\t325\n"
  body &= "D\t415\n"
  body &= "D\t425\n"
  body &= "D\t516\n"
  body &= "D\t524"

  var countOut: int = body.multiReplace([("\t", ""), ("\n", "")]).len
  body &= "\n$\t" & $countOut & "\t$\n"

  await req.respond(Http200, body)

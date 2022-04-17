import asynchttpserver, asyncdispatch
from asyncnet import getPeerAddr # Required for getPeerAddr
from times import epochTime
from strutils import multiReplace, split
import tables # Query params

proc handleGetBackendInfo*(req: Request, params: Table[string, string]) {.async.} =
  var isServer: bool = false # TODO: Fix this
  var version = "1.7.94.0"
  var body: string

  # if(hexdec($code[26].$code[27].$code[24].$code[25]) == 1) {
  #   $clType = 'server';
  #   $isServer = true;
  # } else {
  #   $clType = 'client';
  #   $isServer = false;
  # }

  body = "O\n"
  body &= "H\tasof\ttid\tserverip\tcb\n"
  body &= "D\t" & $epochTime().toInt & "\t0\t"
  body &= req.client.getPeerAddr()[0] & '\t'
  body &= (if isServer: "server" else: "client") & '\n'
  body &= "H\tconfig\n"
  body &= "D\t"

  if not isServer:
    body &= "swiffHost.setLatestGameVersion " & version & '\n'

  body &= """rankSettings.setRank 0 0
rankSettings.setRank 1 40
rankSettings.setRank 2 80
rankSettings.setRank 3 120
rankSettings.setRank 4 200
rankSettings.setRank 5 330
rankSettings.setRank 6 520
rankSettings.setRank 7 750
rankSettings.setRank 8 1050
rankSettings.setRank 9 1400
rankSettings.setRank 10 1800
rankSettings.setRank 11 2250
rankSettings.setRank 12 2850
rankSettings.setRank 13 3550
rankSettings.setRank 14 4400
rankSettings.setRank 15 5300
rankSettings.setRank 16 6250
rankSettings.setRank 17 7250
rankSettings.setRank 18 8250
rankSettings.setRank 19 9300
rankSettings.setRank 20 10400
rankSettings.setRank 21 11550
rankSettings.setRank 22 12700
rankSettings.setRank 23 14000
rankSettings.setRank 24 15300
rankSettings.setRank 25 16700
rankSettings.setRank 26 18300
rankSettings.setRank 27 20100
rankSettings.setRank 28 22100
rankSettings.setRank 29 24200
rankSettings.setRank 30 26400
rankSettings.setRank 31 28800
rankSettings.setRank 32 31500
rankSettings.setRank 33 34200
rankSettings.setRank 34 37100
rankSettings.setRank 35 40200
rankSettings.setRank 36 43300
rankSettings.setRank 37 46900
rankSettings.setRank 38 50500
rankSettings.setRank 39 54100
rankSettings.setRank 40 57700
rankSettings.setRank 41 0
rankSettings.setRank 42 0
rankSettings.setRank 43 0
rankSettings.save"""

  if not isServer:
    body &= """
awards.setData 100_1 "6,1, ,12"
awards.setData 100_2 "6,1, ,20" "9,23,ktt-3,54000"
awards.setData 100_3 "6,1, ,30" "9,23,ktt-3,180000"
awards.setData 101_1 "6,2, ,12"
awards.setData 101_2 "6,2, ,20" "9,20,ktt-0,54000"
awards.setData 101_3 "6,2, ,30" "9,20,ktt-0,180000"
awards.setData 102_1 "6,3, ,12"
awards.setData 102_2 "6,3, ,20" "9,21,ktt-1,54000"
awards.setData 102_3 "6,3, ,30" "9,21,ktt-1,180000"
awards.setData 103_1 "6,4, ,12"
awards.setData 103_2 "6,4, ,20" "9,22,ktt-2,54000"
awards.setData 103_3 "6,4, ,30" "9,22,ktt-2,180000"
awards.setData 104_1 "6,50, ,10"
awards.setData 104_2 "6,50, ,20" "1,113,slpts,300"
awards.setData 104_3 "6,50, ,30" "1,113,slpts,600"
awards.setData 105_1 "6,5, ,7"
awards.setData 105_2 "6,5, ,10" "1,5,wkls-12,50"
awards.setData 105_3 "6,5, ,17" "1,5,wkls-12,150"
awards.setData 106_1 "6,7, ,5"
awards.setData 106_2 "6,7, ,7" "1,7,wkls-5;wkls-11,50"
awards.setData 106_3 "6,7, ,18" "1,7,wkls-5;wkls-11,300"
awards.setData 107_1 "6,8, ,10"
awards.setData 107_2 "6,8, ,15" "1,8,klse,50"
awards.setData 107_3 "6,8, ,20" "1,8,klse,300"
awards.setData 108_1 "10,18, ,180"
awards.setData 108_2 "6,9, ,15" "9,148,vtp-12;vtp-3;wtp-30,72000"
awards.setData 108_3 "6,9, ,30" "9,148,vtp-12;vtp-3;wtp-30,180000"
awards.setData 109_1 "6,40, ,30"
awards.setData 109_2 "10,150, ,1200" "1,40,csgpm-0,1000"
awards.setData 109_3 "10,150, ,1500" "1,40,csgpm-0,4000"
awards.setData 110_1 "6,39, ,30"
awards.setData 110_2 "10,149, ,1200" "1,39,csgpm-1,1000"
awards.setData 110_3 "10,149, ,1500" "1,39,csgpm-1,4000"
awards.setData 111_1 "6,42, ,8"
awards.setData 111_2 "6,42, ,10" "9,128,etpk-1,36000"
awards.setData 111_3 "6,42, ,15" "9,128,etpk-1,216000" "1,42,rps,200"
awards.setData 112_1 "6,43, ,8"
awards.setData 112_2 "6,43, ,10" "9,129,etpk-5,36000"
awards.setData 112_3 "6,43, ,15" "9,129,etpk-5,216000" "1,43,hls,400"
awards.setData 113_1 "6,45, ,8"
awards.setData 113_2 "6,45, ,10" "9,130,etpk-6,36000"
awards.setData 113_3 "6,45, ,15" "9,130,etpk-6,180000" "1,45,resp,400"
awards.setData 114_1 "10,141, ,900"
awards.setData 114_2 "6,11, ,15" "9,114,atp,90000"
awards.setData 114_3 "6,11, ,35" "9,114,atp,180000"
awards.setData 115_1 "10,142, ,900"
awards.setData 115_2 "6,12, ,15" "9,25,vtp-10;vtp-4,90000"
awards.setData 115_3 "6,12, ,35" "9,25,vtp-10;vtp-4,180000"
awards.setData 116_1 "10,151, ,600"
awards.setData 116_2 "6,116, ,5" "9,115,vtp-1;vtp-4;vtp-6,90000"
awards.setData 116_3 "6,116, ,12" "9,115,vtp-1;vtp-4;vtp-6,144000"
awards.setData 117_1 "6,46, ,8"
awards.setData 117_2 "6,46, ,15" "9,27,tgpm-1,108000"
awards.setData 117_3 "6,46, ,30" "9,27,tgpm-1,216000"
awards.setData 118_1 "6,47, ,8"
awards.setData 118_2 "6,47, ,15" "9,27,tgpm-1,108000"
awards.setData 118_3 "6,47, ,30" "9,27,tgpm-1,216000"
awards.setData 119_1 "6,48, ,2"
awards.setData 119_2 "6,49, ,1" "1,48,tcd,10"
awards.setData 119_3 "6,48, ,3" "6,49, ,1" "1,48,tcd,40"
awards.setData 200 "6,127, ,"
awards.setData 201 "6,126, ,"
awards.setData 202 "6,125, ,"
awards.setData 203 "6,41, ,30" "9,19,tac,180000" "9,28,tasl,180000" "9,29,tasm,180000"
awards.setData 204 "6,59, ,1" "5,62,100_1,1" "5,63,101_1,1" "5,64,102_1,1" "5,65,103_1,1" "5,66,105_1,1" "5,67,106_1,1" "5,68,107_1,1"
awards.setData 205 "6,59, ,1" "5,69,100_2,1" "5,70,101_2,1" "5,71,102_2,1" "5,72,103_2,1" "5,73,105_2,1" "5,74,106_2,1" "5,75,107_2,1"
awards.setData 206 "6,59, ,1" "5,76,100_3,1" "5,77,101_3,1" "5,78,102_3,1" "5,79,103_3,1" "5,80,105_3,1" "5,81,106_3,1" "5,82,107_3,1"
awards.setData 207 "11,30,tt,540000" "3,51,cpt,1000" "3,52,dcpt,400" "3,41,twsc,5000"
awards.setData 208 "10,145, ,180" "11,31,attp-0,540000" "1,54,awin-0,300"
awards.setData 209 "10,146, ,180" "11,32,attp-1,540000" "1,55,awin-1,300"
awards.setData 210 "6,60, ,1" "11,26,tgpm-0,288000" "1,13,kgpm-0,8000" "1,15,bksgpm-0,25"
awards.setData 211 "6,61, ,1" "11,27,tgpm-1,288000" "1,14,kgpm-1,8000" "1,16,bksgpm-1,25"
awards.setData 212 "6,12, ,30" "9,25,vtp-10;vtp-4,360000" "1,12,vkls-10;vkls-4,8000"
awards.setData 213 "6,11, ,25" "9,24,vtp-0;vtp-1;vtp-2,360000" "1,11,vkls-0;vkls-1;vkls-2,8000"
awards.setData 214 "6,17, ,27" "6,83, ,0" "9,30,tt,648000"
awards.setData 215 "11,30,tt,360000" "3,43,hls,400" "3,42,rps,400" "3,45,resp,400"
awards.setData 216 "6,85, ,0.25"
awards.setData 217 "6,86, ,10" "9,33,vtp-4,90000"
awards.setData 218 "6,14, ,10" "11,27,tgpm-1,540000" "1,133,mbr-1-0;mbr-1-1;mbr-1-2;mbr-1-3;mbr-1-5;mbr-1-10;mbr-1-12,70"
awards.setData 219 "6,17, ,20" "1,51,cpt,100" "1,42,rps,70"
awards.setData 300 "10,18, ,300" "6,9, ,15"
awards.setData 301 "10,142, ,600" "6,12, ,20"
awards.setData 302 "6,120, ,10"
awards.setData 303 "10,143, ,1200" "9,28,tasl,144000"
awards.setData 304 "10,38, ,1200" "6,34, ,40" "9,19,tac,288000"
awards.setData 305 "6,41, ,15" "9,29,tasm,36000" "9,28,tasl,36000" "9,19,tac,36000"
awards.setData 306 "10,144, ,1080" "6,41, ,40" "9,29,tasm,72000"
awards.setData 307 "6,41, ,55" "9,29,tasm,90000" "9,28,tasl,180000"
awards.setData 308 "6,34, ,45" "9,19,tac,216000" "5,87,wlr,2"
awards.setData 309 "10,141, ,1200" "6,11, ,20"
awards.setData 310 "6,110, ,10" "9,121,vtp-0;vtp-1;vtp-2;vtp-6,36000"
awards.setData 311 "9,99,mtt-0-0;mtt-1-0,0" "9,101,mtt-0-2;mtt-1-2,0" "9,103,mtt-0-4,0" "9,104,mtt-0-5;mtt-1-5,0" "9,108,mtt-0-9,0" "9,32,attp-1,432000"
awards.setData 312 "9,100,mtt-0-1;mtt-1-1,0" "9,102,mtt-0-3;mtt-1-3,0" "9,105,mtt-0-6,0" "9,106,mtt-0-7,0" "9,107,mtt-0-8,0" "9,31,attp-0,432000"
awards.setData 313 "6,17, ,20" "1,88,bksgpm-0;bksgpm-1,10"
awards.setData 314 "6,17, ,10" "6,83, ," "11,30,tt,180000"
awards.setData 315 "6,17, ,10" "11,30,tt,432000" "1,88,bksgpm-0;bksgpm-1,10"
awards.setData 316 "3,10,vkls-7,200"
awards.setData 317 "6,86, ,15" "9,33,vtp-4,90000"
awards.setData 318 "6,138, ,15" "9,137,vtp-12,36000"
awards.setData 319 "6,39, ,10" "11,36,ctgpm-1,90000"
awards.setData 400 "6,89, ,5"
awards.setData 401 "6,89, ,10"
awards.setData 402 "6,48, ,4"
awards.setData 403 "6,109, ,4"
awards.setData 404 "6,86, ,10"
awards.setData 406 "6,47, ,7"
awards.setData 407 "6,139, ,5"
awards.setData 408 "6,110, ,5"
awards.setData 409 "6,93, ,8"
awards.setData 410 "6,8, ,8"
awards.setData 411 "6,44, ,8"
awards.setData 412 "6,124, ,"
awards.setData 413 "6,7, ,4"
awards.setData 414 "6,9, ,10"
awards.setData 415 "6,6, ,10"
awards.setData 120_1 "6,152, ,6"
awards.setData 120_2 "6,152, ,10" "9,153,mtt-1-10;mtt-2-10;mtt-2-11;mtt-1-12;mtt-2-12,7200"
awards.setData 120_3 "6,152, ,14" "9,153,mtt-1-10;mtt-2-10;mtt-2-11;mtt-1-12;mtt-2-12,18000"
awards.setData 121_1 "10,154, ,300"
awards.setData 121_2 "6,156, ,8" "9,155,vtp-14;vtp-15,3600"
awards.setData 121_3 "6,156, ,12" "9,155,vtp-14;vtp-15,14400"
awards.setData 320 "6,157, ,5" "5,158,vkls-15,40"
awards.setData 321 "6,152, ,15" "5,159,mwin-1-12;mwin-2-12,2" "5,160,mwin-1-10;mwin-2-10,2" "5,161,mwin-2-11,2"
awards.setData 322 "6,162, ,9" "9,163,vtp-14,7200"
awards.setData 323 "7,164,vdstry-15,4" "7,165,vdstry-14,2" "7,166,vdths-15,5" "7,167,vdths-14,5"
awards.setData 416 "6,168, ,"
"""
  var countOut: int = body.multiReplace([("\t", ""), ("\n", "")]).len
  body &= "\n$\t" & $countOut & "\t$\n"

  # function errorcode($errorcode=104) {
  #   $Out = "E\t".$errorcode;
  #   $countOut = preg_replace('/[\t\n]/','',$Out);
  #   print $Out."\n$\t".strlen($countOut)."\t$\n";
  # }
  await req.respond(Http200, body)
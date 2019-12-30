#!/bin/bash
containerId=`docker ps -l | awk '$2 == "nimbf2142unlocker_bf2142unlocker" {print $1}'`
rm build/* -fr
docker cp $containerId:/opt/nimBF2142Unlocker/build/ .
#!/bin/bash
containerId=`docker ps -l | awk '$2 == "bf2142unlocker_bf2142unlocker" {print $1}'`
rm build/* -fr
docker cp $containerId:/opt/BF2142Unlocker/build/ .
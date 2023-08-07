CID=`docker ps -a| grep kazutoiris/connectal  | awk '{print $1}'`
# echo $CID

rm -rf ./bluesim/
docker exec $CID rm -rf /root/6.375_Lab4/
docker cp ../../../6.375_Lab4 $CID:/root/6.375_Lab4/
docker exec --workdir /root/6.375_Lab4/audio/connectal $CID make -j20 simulation
docker cp $CID:/root/6.375_Lab4/audio/connectal/bluesim ./bluesim/
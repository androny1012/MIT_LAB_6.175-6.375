CID=`docker ps -a| grep kazutoiris/connectal  | awk '{print $1}'`
# echo $CID

docker exec $CID rm -rf /root/6.175_Lab6/
docker cp ../6.175_Lab6 $CID:/root/6.175_Lab6/
docker exec --workdir /root/6.175_Lab6 $CID make build.bluesim VPROC=SIXSTAGERAS
rm -rf ./bluesim/
docker cp $CID:/root/6.175_Lab6/bluesim ./bluesim/
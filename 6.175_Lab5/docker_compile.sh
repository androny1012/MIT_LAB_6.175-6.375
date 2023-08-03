CID=`docker ps -a| grep kazutoiris/connectal  | awk '{print $1}'`
# echo $CID

docker exec $CID rm -rf /root/6.175_Lab5/
docker cp ../6.175_Lab5 $CID:/root/6.175_Lab5/
docker exec --workdir /root/6.175_Lab5 $CID make build.bluesim VPROC=ONECYCLE
rm -rf ./bluesim/
docker cp $CID:/root/6.175_Lab5/bluesim ./bluesim/
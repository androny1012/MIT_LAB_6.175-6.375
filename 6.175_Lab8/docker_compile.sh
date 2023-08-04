CID=`docker ps -a| grep kazutoiris/connectal  | awk '{print $1}'`
# echo $CID

rm -rf ./logs/
rm -rf ./bluesim/
docker exec $CID rm -rf /root/6.175_Lab8/
docker cp ../6.175_Lab8 $CID:/root/6.175_Lab8/
docker exec --workdir /root/6.175_Lab8 $CID make build.bluesim VPROC=EXCEP
docker cp $CID:/root/6.175_Lab8/bluesim ./bluesim/
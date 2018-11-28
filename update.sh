mkdir -p cache/nar/gzip

echo "#### FINISHED JOBS"
bash get_build_hashes.sh > current_hashes.txt; 
for n in `cat current_hashes.txt`; do 
    narinfo="$n.narinfo"
    if [ ! -f "./cache/$narinfo" ]; then 
        echo get: "$narinfo";
        wget https://berlin.guixsd.org/"$n".narinfo -P ./cache/
        sleep 1
    fi 
done

echo "#### GETTING NARINFOS"
for n in cache/*.narinfo; do 
    cat "$n" | grep ^URL | cut -d / -f 3 > current_nars.txt
done


echo "#### GETTING NARS"
for n in `cat current_nars.txt`; do
    if [ ! -f "./cache/nar/gzip/$n" ]; then
        echo get: "$n"
        wget https://berlin.guixsd.org/nar/gzip/"$n" -P ./cache/nar/gzip/
    fi
done

echo "#### UPDATING IPFS"
ipfs add -r cache > ipfs_log.txt

echo "#### UPDATING IPNS"
cache_cid=`tail -n 1 ipfs_log.txt | cut -d ' ' -f 2`
ipfs name publish "$cache_cid"

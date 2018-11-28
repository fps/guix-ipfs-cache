curl https://berlin.guixsd.org/api/latestbuilds?nr=30 | jq .[].buildoutputs.out.path | cut -d / -f 4 | cut -d "-" -f 1

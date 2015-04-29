#!/bin/sh
echo "1..8"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/jp-regions.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.["三重県"].areas["伊勢市"].id == 339'
test 2 '.["北海道"].areas["函館市"].subpref_name | not | not'
test 3 '.["東京都"].subprefs["小笠原支庁"].id == 2364'
test 4 '.["長崎県"].subprefs | not'
test 5 '.["三重県"].latin == "Mie-ken"'
test 6 '.["京都府"].latin == "Kyoto-fu"'
test 7 '.["奈良県"].areas["宇陀市"].latin == "Uda-shi"'
test 8 '.["愛知県"].areas["名古屋市"].areas["中区"].latin == "Naka-ku"'

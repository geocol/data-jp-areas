#!/bin/sh
echo "1..7"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/jp-regions-full.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.["三重県"].areas["伊勢市"].id == 339'
test 2 '.["北海道"].areas["函館市"].subpref_name | not | not'
test 3 '.["東京都"].subprefs["小笠原支庁"].id == 2364'
test 4 '.["長崎県"].subprefs | not'
test 5 '.["北海道"].areas["色丹村"].id == 240'
test 6 '.["北海道"].areas["色丹村"].wref == "色丹村"'
test 7 '.["北海道"].areas["色丹村"].latin == "Shikotan-mura"'

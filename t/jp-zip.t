#!/bin/sh
echo "1..2"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/jp-zip.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.["0010000"][0].town_fallback | not | not'
test 2 '.["1440041"][0].town_kana == "ハネダクウコウ"'

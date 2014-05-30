# -*- Makefile -*-

all: deps all-jpregions all-jpzip

clean: clean-jpregions clean-jpzip

GIT = git

updatenightly: clean deps all
	$(GIT) add data/*

## ------ Setup ------

WGET = wget
GIT = git
PERL = ./perl

deps: git-submodules pmbp-install

git-submodules:
	$(GIT) submodule update --init

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(WGET) -O $@ https://raw.github.com/wakaba/perl-setupenv/master/bin/pmbp.pl
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update-pmbp-pl
pmbp-update: git-submodules pmbp-upgrade
	perl local/bin/pmbp.pl --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl --install



## ------ Wikipedia dumps ------

wikipedia-dumps: local/cache/xml/jawiki-latest-pages-meta-current.xml

%.xml: %.xml.bz2
	bzcat $< > $@

local/cache/xml/jawiki-latest-pages-meta-current.xml.bz2:
	mkdir -p local/cache/xml
	$(WGET) -O $@ http://download.wikimedia.org/jawiki/latest/jawiki-latest-pages-meta-current.xml.bz2

wp-autoupdate: deps wp-clean wp-data

wp-clean:
	rm -fr local/intermediate-wikipedia

wp-deps:
	$(PERL) bin/prepare-wikipedia-cache.pl

wp-data: wp-deps intermediate/wikipedia-regions.json
	$(GIT) add intermediate

intermediate/wikipedia-regions.json: local/jp-regions.json \
    bin/wikipedia-prefs.pl bin/wikipedia-regions.pl \
    bin/wikipedia-cities.pl local/intermediate-wikipedia #wikipedia-dump
	mkdir -p intermediate
	$(PERL) bin/wikipedia-prefs.pl
	$(PERL) bin/wikipedia-cities.pl

local/intermediate-wikipedia:
	mkdir -p local
	touch $@

## ------ Data ------

all-jpregions: data/jp-regions.json data/jp-regions-full.json \
    data/jp-regions-suffix-mixed-names.json
clean-jpregions: clean-jpzip
	rm -fr local/soumu-jp-regions.csv

local/soumu-jp-regions.csv:
	$(WGET) -O $@ http://www.stat.go.jp/index/seido/csv/9-5.csv

local/soumu-jp-regions.json: local/soumu-jp-regions.csv \
    bin/soumu-jp-regions.pl
	$(PERL) bin/soumu-jp-regions.pl > $@

local/japanpost-jp-regions.json: local/ken_all.csv local/ken_all_rome.csv \
    bin/japanpost-jp-regions.pl
	$(PERL) bin/japanpost-jp-regions.pl > $@

local/jp-regions.json: local/japanpost-jp-regions.json bin/jp-regions.pl \
    local/soumu-jp-regions.json
	$(PERL) bin/jp-regions.pl > $@

data/jp-regions.json: local/jp-regions.json local/hokkaidou-subprefs.json \
    bin/jp-regions-2.pl
	$(PERL) bin/jp-regions-2.pl > $@

data/jp-regions-full.json: data/jp-regions.json bin/jp-regions-full.pl \
    intermediate/wikipedia-regions.json
	$(PERL) bin/jp-regions-full.pl > $@

all-jpzip: data/jp-zip.json data/jp-zip.json.gz
clean-jpzip:
	rm -fr local/ken_all.lzh local/ken_all_rome.lzh

data/jp-zip.json: local/ken_all.csv bin/jp-zip.pl
	$(PERL) bin/jp-zip.pl > $@

data/jp-zip.json.gz: data/jp-zip.json
	cat $< | gzip > $@

local/ken_all.csv: local/ken_all.lzh local/bin/lhasa
	cd local && bin/lhasa xf ken_all.lzh
	touch $@
local/ken_all_rome.csv: local/ken_all_rome.lzh local/bin/lhasa
	cd local && bin/lhasa xf ken_all_rome.lzh
	touch $@

local/ken_all.lzh:
	mkdir -p local
	$(WGET) -O $@ http://www.post.japanpost.jp/zipcode/dl/kogaki/lzh/ken_all.lzh
local/ken_all_rome.lzh:
	mkdir -p local
	$(WGET) -O $@ http://www.post.japanpost.jp/zipcode/dl/roman/ken_all_rome.lzh

local/bin/lhasa: local/lhasa-0.2.0.tar.gz
	mkdir -p local/bin
	cd local && tar zxf lhasa-0.2.0.tar.gz
	cd local/lhasa-0.2.0 && ./configure && make
	cp local/lhasa-0.2.0/src/lha local/bin/lhasa

local/lhasa-0.2.0.tar.gz:
	mkdir -p local
	$(WGET) -O $@ https://soulsphere.org/projects/lhasa/lhasa-0.2.0.tar.gz

intermediate/lg-offices.json: bin/extract-offices.pl
	$(PERL) bin/extract-offices.pl > $@

local/geonlp-pref.zip:
	# <https://geonlp.ex.nii.ac.jp/dictionary/geonlp/japan_pref>
	$(WGET) -O $@ https://geonlp.ex.nii.ac.jp/dictionary/geonlp/japan_pref/geonlp_japan_pref_20140115_u.zip

local/geonlp_japan_pref/geonlp_japan_pref_20140115_u.csv: local/geonlp-pref.zip
	cd local && unzip -o geonlp-pref.zip

intermediate/geonlp-pref.json: \
    local/geonlp_japan_pref/geonlp_japan_pref_20140115_u.csv \
    bin/geonlp-pref.pl
	$(PERL) bin/geonlp-pref.pl > $@

local/bin/jq:
	$(WGET) -O $@ http://stedolan.github.io/jq/download/linux64/jq
	chmod u+x local/bin/jq

local/all-area-names.json: local/bin/jq data/jp-regions.json
	cat data/jp-regions.json | local/bin/jq '[recurse(.[].areas, .[].districts) | to_entries | map([.key, .value.code]) | .[]]' > $@

data/jp-regions-suffix-mixed-names.json: bin/suffix-mixed-names.pl \
    local/all-area-names.json
	$(PERL) bin/suffix-mixed-names.pl > $@

local/hokkaidou-subprefs.json: intermediate/wikipedia-regions.json local/bin/jq
	cat intermediate/wikipedia-regions.json | local/bin/jq 'to_entries | map(select(.value.subpref)) | map([.key, .value.subpref])' > $@

## ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps

test-main:
	$(PROVE) t/*.t
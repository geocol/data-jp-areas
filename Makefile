# -*- Makefile -*-

all: deps all-jpzip

clean: clean-jpzip

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

## ------ Data ------

all-jpzip: data/jp-zip.json
clean-jpzip:
	rm -fr local/ken_all.lzh local/lhasa-0.2.0.tar.gz

data/jp-zip.json: local/ken_all.csv bin/jp-zip.pl
	$(PERL) bin/jp-zip.pl > $@

local/ken_all.csv: local/ken_all.lzh local/bin/lhasa
	cd local && bin/lhasa xf ken_all.lzh

local/ken_all.lzh:
	mkdir -p local
	$(WGET) -O $@ http://www.post.japanpost.jp/zipcode/dl/kogaki/lzh/ken_all.lzh

local/bin/lhasa: local/lhasa-0.2.0.tar.gz
	mkdir -p local/bin
	cd local && tar zxf lhasa-0.2.0.tar.gz
	cd local/lhasa-0.2.0 && ./configure && make
	cp local/lhasa-0.2.0/src/lha local/bin/lhasa

local/lhasa-0.2.0.tar.gz:
	mkdir -p local
	$(WGET) -O $@ https://soulsphere.org/projects/lhasa/lhasa-0.2.0.tar.gz

## ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps

test-main:
	$(PROVE) t/*.t
all: wp-deps wp-data

PERL = ../perl
WGET = wget

## requires Wikipedia database
wp-deps: ../bin/prepare-wikipedia-cache.pl
	$(PERL) ../bin/prepare-wikipedia-cache.pl

wp-clean:

wp-data: wikipedia-regions.json

## requires Wikipedia database
wikipedia-regions.json: ../local/jp-regions-for-wp.json \
    ../bin/wikipedia-prefs.pl ../bin/wikipedia-regions.pl \
    ../bin/wikipedia-cities.pl
	$(PERL) ../bin/wikipedia-prefs.pl
	$(PERL) ../bin/wikipedia-cities.pl

../local/jp-regions-for-wp.json:
	mkdir -p ../local
	$(WGET) -O $@ http://geocol.github.io/data/geocol/data-jp-areas/jp-regions.json

all: wp-deps wp-data

PERL = ./perl

wp-deps: ../local/cache/xml/jawiki-latest-pages-meta-current.xml \
    ../bin/prepare-wikipedia-cache.pl
	$(PERL) ../bin/prepare-wikipedia-cache.pl

wp-clean:

wp-data: wikipedia-regions.json

wikipedia-regions.json: ../local/jp-regions.json \
    ../bin/wikipedia-prefs.pl ../bin/wikipedia-regions.pl \
    ../bin/wikipedia-cities.pl #wikipedia-dump
	$(PERL) bin/wikipedia-prefs.pl
	$(PERL) bin/wikipedia-cities.pl

../local/jp-regions.json:
	cd .. && $(MAKE) local/jp-regions.json

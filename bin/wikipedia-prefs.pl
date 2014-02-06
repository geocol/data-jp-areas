use strict;
use warnings;
use utf8;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use Encode;
use JSON::Functions::XS qw(perl2json_bytes_for_record file2perl);

my $root_d = file (__FILE__)->dir->parent;

my $regions = do {
  my $f = $root_d->file ('local', 'jp-regions.json');
  [keys %{file2perl $f}];
};

(system $root_d->file ('perl'), $root_d->file ('bin', 'wikipedia-regions.pl'), map { encode 'utf-8', $_ } @$regions) == 0
    or die $?;

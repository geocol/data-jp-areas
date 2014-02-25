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
  file2perl $f;
};

my @pref = @ARGV ? map { decode 'utf-8', $_ } @ARGV : keys %$regions;

for my $pref (@pref) {
  my @region;
  for my $city (keys %{$regions->{$pref}->{areas}},
                keys %{$regions->{$pref}->{districts} or {}}) {
    push @region, join ',', $pref, $city;
    for my $town (keys %{$regions->{$pref}->{areas}->{$city}->{areas} or {}}) {
      push @region, join ',', $pref, $city, $town;
    }
  }

  (system $root_d->file ('perl'), $root_d->file ('bin', 'wikipedia-regions.pl'), map { encode 'utf-8', $_ } @region) == 0
      or die $?;
}

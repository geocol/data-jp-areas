use strict;
use warnings;
use utf8;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use Encode;
use JSON::Functions::XS qw(perl2json_bytes_for_record file2perl);

my $root_d = file (__FILE__)->dir->parent;
our $Data = file2perl $root_d->file ('data', 'jp-regions.json');

sub copy ($$) {
  my ($f, $t) = @_;
  for my $key (qw(url wref area_symbols neighbor_region_names
                  wikipedia_location_image_wref)) {
    $t->{$key} = $f->{$key} if defined $f->{$key};
  }
  $t->{wikipedia_image} = {
    wref => $f->{wikipedia_image_wref},
    desc => $f->{wikipedia_image_desc},
  } if defined $f->{wikipedia_image_wref};
} # copy

for my $f (
  file (__FILE__)->dir->parent->file ('intermediate', 'wikipedia-regions.json'),
  file (__FILE__)->dir->parent->file ('src', 'additional-wp-regions.json'),
) {
  my $json = file2perl $f;
  for my $pref (keys %$Data) {
    copy $json->{$pref} => $Data->{$pref};
    for my $city (keys %{$Data->{$pref}->{areas} or {}}) {
      copy $json->{"$pref,$city"} => $Data->{$pref}->{areas}->{$city};
      for my $town (keys %{$Data->{$pref}->{areas}->{$city}->{areas} or {}}) {
        copy $json->{"$pref,$city,$town"} => $Data->{$pref}->{areas}->{$city}->{areas}->{$town};
      }
    }
    for my $city (keys %{$Data->{$pref}->{districts} or {}}) {
      copy $json->{"$pref,$city"} => $Data->{$pref}->{districts}->{$city};
    }
  }
}

print perl2json_bytes_for_record $Data;

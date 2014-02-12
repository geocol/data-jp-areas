use strict;
use warnings;
use utf8;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use Encode;
use JSON::Functions::XS qw(perl2json_bytes_for_record file2perl);

my $root_d = file (__FILE__)->dir->parent;
our $Data = file2perl $root_d->file ('data', 'jp-regions.json');

{
  my $f = file (__FILE__)->dir->parent->file ('intermediate', 'wikipedia-regions.json');
  my $json = file2perl $f;
  for my $pref (keys %$json) {
    $Data->{$pref}->{url} = $json->{$pref}->{url};
    $Data->{$pref}->{wref} = $json->{$pref}->{wref}
        if defined $json->{$pref}->{wref};
    $Data->{$pref}->{symbols} = $json->{$pref}->{symbols} || [];
    $Data->{$pref}->{wikipedia_image} = {
        wref => $json->{$pref}->{wikipedia_image_wref},
        desc => $json->{$pref}->{wikipedia_image_desc},
    };
  }
}

print perl2json_bytes_for_record $Data;

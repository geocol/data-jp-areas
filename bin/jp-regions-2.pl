use strict;
use warnings;
use utf8;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use Encode;
use JSON::Functions::XS qw(perl2json_bytes_for_record file2perl);
use Char::Normalize::FullwidthHalfwidth qw(normalize_width combine_voiced_sound_marks);
use Char::Transliterate::Kana qw(hiragana_to_katakana katakana_to_hiragana);

my $Data = file2perl file (__FILE__)->dir->parent->file ('local', 'jp-regions.json');
my $map = file2perl file (__FILE__)->dir->parent->file ('local', 'hokkaidou-subprefs.json');

for (@$map) {
    my $region = [split /,/, $_->[0]];
    next unless @$region == 2;
    my $subpref = $_->[1] or next;
    $Data->{$region->[0]}->{areas}->{$region->[1]}->{subpref_name} = $subpref
        if $region->[0] eq '北海道';
    $Data->{$region->[0]}->{subprefs}->{$subpref}->{area_names}->{$region->[1]} = 1;
}

print perl2json_bytes_for_record $Data;

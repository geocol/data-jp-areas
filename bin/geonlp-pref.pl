use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use Encode;
use JSON::Functions::XS qw(perl2json_bytes_for_record);
use Char::Normalize::FullwidthHalfwidth qw(normalize_width combine_voiced_sound_marks);

my $Data = [];

{
    my $f = file (__FILE__)->dir->parent->file ('local', 'geonlp_japan_pref', 'geonlp_japan_pref_20140115_u.csv');
    my @line = map { [map { s/^\s*"//; s/"\s*$//; normalize_width \$_; combine_voiced_sound_marks \$_; tr/\x{FF5E}\x{2212}/\x{301C}-/; $_ } split /,/, $_] } split /\x0D?\x0A/, decode 'utf-8', scalar $f->slurp;
    my $header = shift @line;
    for my $data (@line) {
        push @$Data, {map { $header->[$_] => $data->[$_] } 0..$#$data};
    }
}

print perl2json_bytes_for_record $Data;

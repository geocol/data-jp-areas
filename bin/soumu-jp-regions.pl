use strict;
use warnings;
use utf8;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use Encode;
use JSON::Functions::XS qw(perl2json_bytes_for_record file2perl);

our $Data = {};

my $csv_f = file (__FILE__)->dir->parent->file ('local', 'soumu-jp-regions.csv');
for (split /\x0D?\x0A/, decode 'shift_jis', scalar $csv_f->slurp) {
    my @in = split /,/, $_;
    # 0 ken-code
    # 1 sityouson-code
    # 2 tiiki-code
    # 3 ken-name
    # 4 sityouson-name1
    # 5 sityouson-name2
    # 6 sityouson-name3
    # 7 yomigana
    next unless $in[0] =~ /^\d+$/;
    next if $in[2] == 13100;
    my $out = $Data->{$in[3]} ||= {};
    for my $i (4..6) {
        if (length $in[$i]) {
            $out = $out->{areas}->{$in[$i]} ||= {};
        }
    }
    $out->{code} = $in[1] == 0 ? sprintf '%02d', $in[0]
                               : sprintf '%05d', $in[2];
    $out->{hiragana} = $in[7];
    if ($in[4] =~ /市$/ and not length $in[6]) {
        $out->{designated} = 1;
    }
}

print perl2json_bytes_for_record $Data;

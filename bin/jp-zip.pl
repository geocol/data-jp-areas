use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use Encode;
use JSON::Functions::XS qw(perl2json_bytes_for_record);
use Char::Normalize::FullwidthHalfwidth qw(normalize_width combine_voiced_sound_marks);

our $Data = {};

{
    my $f = file (__FILE__)->dir->parent->file ('local', 'ken_all.csv');
    my $prev;
    for (split /\x0D?\x0A/, decode 'shift_jis', $f->slurp) {
        my $data = [map { my $c = $_; $c =~ s/^\"//; $c =~ s/"$//; $c } split /\s*,\s*/, $_];
        if (defined $prev and
            $prev->[2] eq $data->[2] and
            ((length ($prev->[5])) >= 76 or
             (length ($prev->[8])) >= 38 or
             $prev->[5] eq $data->[5] or
             $prev->[8] eq $data->[8] or
             ($Data->{$prev->[2]}->[-1]->[8] =~ /（/ and
              not $Data->{$prev->[2]}->[-1]->[8] =~ /）/) or
             ($Data->{$prev->[2]}->[-1]->[5] =~ /\(/ and
              not $Data->{$prev->[2]}->[-1]->[5] =~ /\)/))) {
            $Data->{$data->[2]}->[-1]->[5] .= $data->[5] unless $data->[5] eq $prev->[5];
            $Data->{$data->[2]}->[-1]->[8] .= $data->[8] unless $data->[8] eq $prev->[8];
        } else {
            push @{$Data->{$data->[2]} ||= []}, $data;
        }
        $prev = $data;
    }
}

for (keys %$Data) {
    my $new = [];
    for (@{$Data->{$_}}) {
        my $data = {};
        $data->{zip_old} = $_->[1];
        $data->{zip_old} =~ s/\s+$//;
        #$data->{zip} = $_->[2];
        $data->{town_kana} = $_->[5];
        $data->{pref} = $_->[6];
        $data->{city} = $_->[7];
        $data->{town} = $_->[8];
        $data->{multiple_codes_per_town} = 1 if $_->[9];
        $data->{koaza_addressed_town} = 1 if $_->[10];
        $data->{has_choume} = 1 if $_->[11];
        normalize_width \$_, combine_voiced_sound_marks \$_
            for $data->{town_kana}, $data->{pref}, $data->{city}, $data->{town};
        push @$new, $data;
    }
    $Data->{$_} = $new;
}

print perl2json_bytes_for_record $Data;

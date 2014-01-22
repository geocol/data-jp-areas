use strict;
use warnings;
use utf8;
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
        $data->{area} = $_->[0];
        $data->{zip_old} = $_->[1];
        $data->{zip_old} =~ s/\s+$//;
        #$data->{zip} = $_->[2];
        $data->{town_kana} = $_->[5];
        #$data->{pref} = $_->[6];
        #$data->{city} = $_->[7];
        $data->{town} = $_->[8];
        $data->{multiple_codes_per_town} = 1 if $_->[9];
        $data->{koaza_addressed_town} = 1 if $_->[10];
        $data->{has_choume} = 1 if $_->[11];
        normalize_width \$_, combine_voiced_sound_marks \$_, tr/\x{FF5E}\x{2212}/\x{301C}-/
            for $data->{town_kana}, $data->{town};

        if ($data->{town} eq '以下に掲載がない場合') {
            $data->{town_fallback} = 1;
            delete $data->{town};
            delete $data->{town_kana};
        } elsif ($data->{town} =~ /の次に番地がくる場合$/) {
            $data->{no_choume} = 1;
            delete $data->{town};
            delete $data->{town_kana};
        } elsif ($data->{town} =~ /[町村]一円$/) {
            delete $data->{town};
            delete $data->{town_kana};
        }

        my @koaza;
        if (defined $data->{town} and
            $data->{town} =~ s/\s*\(([^()]+)\)\s*$//) {
            $data->{koaza} = $1;
            if ($data->{town_kana} =~ s/\s*\(([^()]+)\)\s*$//) {
                $data->{koaza_kana} = $1;
            }

            if ($data->{koaza} eq 'その他') {
                $data->{koaza_fallback} = 1;
                delete $data->{koaza};
                delete $data->{koaza_kana};
            } elsif ($data->{koaza} eq '次のビルを除く') {
                $data->{has_building_codes_in_town} = 1;
                delete $data->{koaza};
                delete $data->{koaza_kana};
            } elsif ($data->{koaza} =~ /^([0-9]+階)$/) {
                $data->{building_level} = $1;
                delete $data->{koaza};
                delete $data->{koaza_kana};
            } elsif ($data->{koaza} eq '地階・階層不明') {
                $data->{building_level} = 'fallback';
                delete $data->{koaza};
                delete $data->{koaza_kana};
            } elsif ($data->{koaza} =~ /^[\w\x{301C}]+(?:、[\w\x{301C}]+)+$/) {
                my @k = split /、/, $data->{koaza};
                my @y = split /、/, $data->{koaza_kana} // '';
                push @koaza, map { [$k[$_], $y[$_]] } 0..$#k;
            }
        }

        if (@koaza) {
            push @$new, {%$data, koaza => $_->[0], koaza_kana => $_->[1]}
                for @koaza;
        } else {
            push @$new, $data;
        }
    }

    for my $data (@$new) {
        if (defined $data->{koaza}) {
            if ($data->{koaza} =~ /^[0-9、\x{301C}-]+丁目$/) {
                $data->{choume} = $data->{koaza};
                delete $data->{koaza};
                delete $data->{koaza_kana};
            } elsif ($data->{koaza} =~ /^[0-9、\x{301C}の-]+(?:番地?)?$/) {
                $data->{banchi} = $data->{koaza};
                delete $data->{koaza};
                delete $data->{koaza_kana};
            } elsif ($data->{koaza} =~ /(?:(?:上る|下る|西入|東入)([1-4][丁筋]目)?西?|三条大橋東入?4丁目|三条通白川橋東4丁目)$/) {
                $data->{street_addr} = $data->{koaza};
                $data->{street_addr_kana} = $data->{koaza_kana}
                    if defined $data->{koaza_kana};
                delete $data->{koaza};
                delete $data->{koaza_kana};
            } elsif ($data->{multiple_codes_per_town} and
                     $data->{has_choume} and
                     $data->{koaza} eq '丁目') {
                delete $data->{koaza};
                delete $data->{koaza_kana};
            } elsif ($data->{multiple_codes_per_town} and
                     not $data->{has_choume} and
                     $data->{koaza} eq '番地') {
                $data->{no_choume} = 1;
                delete $data->{koaza};
                delete $data->{koaza_kana};
            }
        }
    }

    $Data->{$_} = $new;
}

print perl2json_bytes_for_record $Data;

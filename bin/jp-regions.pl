use strict;
use warnings;
use utf8;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use Encode;
use JSON::Functions::XS qw(perl2json_bytes_for_record file2perl);
use Char::Normalize::FullwidthHalfwidth qw(normalize_width combine_voiced_sound_marks);

our $Data = {};

my $Areas = {};

{
    my $f = file (__FILE__)->dir->parent->file ('local', 'ken_all.csv');
    my $prev;
    for (split /\x0D?\x0A/, decode 'shift_jis', $f->slurp) {
        my $data = [map { my $c = $_; $c =~ s/^\"//; $c =~ s/"$//; $c } split /\s*,\s*/, $_];
        $Areas->{prefs}->{substr $data->[0], 0, 2} = {
            name => $data->[6],
            kana => $data->[3],
        };
        $Areas->{cities}->{$data->[0]} = {
            name => $data->[7],
            kana => $data->[4],
        };
    }
}

{
    my $f = file (__FILE__)->dir->parent->file ('local', 'ken_all_rome.csv');
    my $prev;
    for (split /\x0D?\x0A/, decode 'shift_jis', $f->slurp) {
        my $data = [map { my $c = $_; $c =~ s/^\"//; $c =~ s/"$//; $c } split /\s*,\s*/, $_];
        $Areas->{prefs}->{substr $data->[0], 0, 2}->{latin} = ucfirst lc $data->[4];
        $Areas->{cities}->{$data->[0]}->{latin} = ucfirst lc $data->[3];
    }
}
delete $Areas->{cities}->{'03305'};

for my $data (values %{$Areas->{cities}}, values %{$Areas->{prefs}}) {
    normalize_width \$_, combine_voiced_sound_marks \$_, tr/\x{FF5E}\x{2212}/\x{301C}-/
        for $data->{name}, $data->{kana};

    if ($data->{name} =~ /^(.+市)(.+区)$/) {
        $data->{city} = $1;
        $data->{name} = $2;
        $data->{kana} =~ /^(キョウトシ|シズオカシ|.+シ)(.+ク)$/;
        $data->{city_kana} = $1;
        $data->{kana} = $2;
        $data->{latin} =~ /^(.+-ku) (.+-shi)$/;
        $data->{city_latin} = ucfirst $2;
        $data->{latin} = $1;
    } elsif ($data->{name} =~ /^(.+郡)(.+[町村])$/) {
        $data->{district} = $1;
        $data->{name} = $2;
        $data->{kana} =~ /^(.+グン)(.+)$/;
        $data->{district_kana} = $1;
        $data->{kana} = $2;
        $data->{latin} =~ /^(.+) (.+-gun)$/;
        $data->{district_latin} = ucfirst $2;
        $data->{latin} = $1;
    } elsif ($data->{name} =~ /^(?:三宅島|八丈島)(.+)$/) {
        $data->{name} = $1;
        $data->{kana} =~ s{^(ミヤケジマ|ハチジョウジマ)}{}g;
        $data->{latin} =~ s/ (miyakejima|hachijojima)//;
    }
}

for my $code (keys %{$Areas->{prefs}}) {
    my $data = $Areas->{prefs}->{$code};
    $Data->{$data->{name}} = {type => 'pref',
                              kana => $data->{kana},
                              latin => $data->{latin},
                              code => $code};
}

for my $code (keys %{$Areas->{cities}}) {
    my $data = $Areas->{cities}->{$code};
    my $pref = $Areas->{prefs}->{substr $code, 0, 2}->{name};
    if (defined $data->{city}) {
        $Data->{$pref}->{areas}->{$data->{city}}->{type} = 'city';
        $Data->{$pref}->{areas}->{$data->{city}}->{kana} = $data->{city_kana};
        $Data->{$pref}->{areas}->{$data->{city}}->{latin} = $data->{city_latin};
        $Data->{$pref}->{areas}->{$data->{city}}->{designated} = 1;
        my $city_code = $code;
        $city_code = '27100' if $code =~ /^271[0-3][0-9]$/;
        $city_code = '27140' if $code =~ /^271[45][0-9]$/;
        $city_code =~ s{^(...)(.).$}{$1 . ($2 < 3 ? 0 : $2 < 5 ? 3 : $2 < 7 ? 5 : 7) . '0'}ge;
        $Data->{$pref}->{areas}->{$data->{city}}->{code} = $city_code;

        my $ward = $data->{name};
        $Data->{$pref}->{areas}->{$data->{city}}->{areas}->{$ward}->{type} = 'ward';
        $Data->{$pref}->{areas}->{$data->{city}}->{areas}->{$ward}->{kana} = $data->{kana};
        $Data->{$pref}->{areas}->{$data->{city}}->{areas}->{$ward}->{latin} = $data->{latin};
        $Data->{$pref}->{areas}->{$data->{city}}->{areas}->{$ward}->{code} = $code;
    } elsif (defined $data->{district}) {
        if ($data->{district} eq '上川郡') {
            $data->{district} = {
                鷹栖町 => '上川郡 (石狩国)',
                東神楽町 => '上川郡 (石狩国)',
                当麻町 => '上川郡 (石狩国)',
                比布町 => '上川郡 (石狩国)',
                愛別町 => '上川郡 (石狩国)',
                上川町 => '上川郡 (石狩国)',
                東川町 => '上川郡 (石狩国)',
                美瑛町 => '上川郡 (石狩国)',
                和寒町 => '上川郡 (天塩国)',
                剣淵町 => '上川郡 (天塩国)',
                下川町 => '上川郡 (天塩国)',
                新得町 => '上川郡 (十勝国)',
                清水町 => '上川郡 (十勝国)',
            }->{$data->{name}} || $data->{district};
        } elsif ($data->{district} eq '中川郡') {
            $data->{district} = {
                美深町 => '中川郡 (天塩国)',
                中川町 => '中川郡 (天塩国)',
                音威子府村 => '中川郡 (天塩国)',
                幕別町 => '中川郡 (十勝国)',
                池田町 => '中川郡 (十勝国)',
                豊頃町 => '中川郡 (十勝国)',
                本別町 => '中川郡 (十勝国)',
            }->{$data->{name}} || $data->{district};
        }

        $Data->{$pref}->{areas}->{$data->{district}}->{type} = 'district';
        $Data->{$pref}->{areas}->{$data->{district}}->{kana} = $data->{district_kana};
        $Data->{$pref}->{areas}->{$data->{district}}->{latin} = $data->{district_latin};

        my $town = $data->{name};
        $Data->{$pref}->{areas}->{$data->{district}}->{areas}->{$town}->{type} = $town =~ /町$/ ? 'town' : 'village';
        $Data->{$pref}->{areas}->{$data->{district}}->{areas}->{$town}->{kana} = $data->{kana};
        $Data->{$pref}->{areas}->{$data->{district}}->{areas}->{$town}->{latin} = $data->{latin};
        $Data->{$pref}->{areas}->{$data->{district}}->{areas}->{$town}->{code} = $code;
    } else {
        my $type = $data->{name} =~ /市$/ ? 'city' :
                   $data->{name} =~ /町$/ ? 'town' :
                   $data->{name} =~ /村$/ ? 'village' : 'ward';
        $Data->{$pref}->{areas}->{$data->{name}} = {type => $type,
                                                    kana => $data->{kana},
                                                    latin => $data->{latin},
                                                    code => $code};
    }
}

$Data->{北海道}->{areas}->{色丹郡}
    = {type => 'district',
       kana => 'しこたんぐん', latin => 'Shikotan-gun'};
$Data->{北海道}->{areas}->{色丹郡}->{areas}->{色丹村}
    = {type => 'village', code => '01695',
       kana => 'しこたんむら', latin => 'Shikotan-mura'};
$Data->{北海道}->{areas}->{国後郡}
    = {type => 'district',
       kana => 'くなしりぐん', latin => 'Kunashiri-gun'};
$Data->{北海道}->{areas}->{国後郡}->{areas}->{泊村}
    = {type => 'village', code => '01696',
       kana => 'とまりむら', latin => 'Tomari-mura'};
$Data->{北海道}->{areas}->{国後郡}->{areas}->{留夜別村}
    = {type => 'village', code => '01697',
       kana => 'るよべつむら', latin => 'Ruyobetsu-mura'};
$Data->{北海道}->{areas}->{択捉郡}
    = {type => 'district',
       kana => 'えとろふぐん', latin => 'Etorofu-gun'};
$Data->{北海道}->{areas}->{択捉郡}->{areas}->{留別村}
    = {type => 'village', code => '01698',
       kana => 'るべつむら', latin => 'Rubetsu-mura'};
$Data->{北海道}->{areas}->{紗那郡}
    = {type => 'district',
       kana => 'しゃなぐん', latin => 'Shana-gun'};
$Data->{北海道}->{areas}->{紗那郡}->{areas}->{紗那村}
    = {type => 'village', code => '01699',
       kana => 'しゃなむら', latin => 'Shana-mura'};
$Data->{北海道}->{areas}->{蘂取郡}
    = {type => 'district',
       kana => 'しべとろぐん', latin => 'Shibetoro-gun'};
$Data->{北海道}->{areas}->{蘂取郡}->{areas}->{蘂取村}
    = {type => 'village', code => '01700',
       kana => 'しべとろむら', latin => 'Shibetoro-mura'};

{
    my $f = file (__FILE__)->dir->parent->file ('intermediate', 'lg-offices.json');
    my $json = file2perl $f;
    for my $pref (keys %$Data) {
        my $pref_code = $Data->{$pref}->{code};
        for my $area_name (keys %{$Data->{$pref}->{areas}}) {
            my $data = $json->{$pref_code}->{$area_name . '役所'} ||
                $json->{$pref_code}->{$area_name . '役場'};
            # $ cat data/jp-regions.json | ./jq '[recurse(.[].areas) | to_entries | .[] | select(.value.type != "pref" and .value.type != "district" and (.value.office | not))]'
            $data ||= $json->{$pref_code}->{{
                京丹後市 => '京丹後市役所峰山庁舎',
                文京区 => '文京区役所、文京シビックセンター',
                港区 => '港区役所、芝地区総合支所',
                千曲市 => '千曲市役所更埴庁舎',
                南砺市 => '南砺市役所福野庁舎、福野行政センター',
                射水市 => '射水市役所小杉庁舎',
                米原市 => '米原市役所米原庁舎',
                魚沼市 => '魚沼市役所小出庁舎',
            }->{$area_name} || ''};
            if (defined $data) {
                $Data->{$pref}->{areas}->{$area_name}->{office} = $data;
            }

            for my $subarea_name (keys %{$Data->{$pref}->{areas}->{$area_name}->{areas} or {}}) {
                my $data = $json->{$pref_code}->{$subarea_name . '役所'} ||
                    $json->{$pref_code}->{$subarea_name . '役場'} ||
                    $json->{$pref_code}->{$area_name . $subarea_name . '役所'} ||
                    $json->{$pref_code}->{$area_name . $subarea_name . '役場'};
                $data ||= $json->{$pref_code}->{{
                    南伊勢町 => '南伊勢町役場南勢庁舎',
                    佐久穂町 => '佐久穂町役場佐久庁舎',
                    南部町 => '南部町役場法勝寺庁舎',
                    南阿蘇村 => '南阿蘇村役場、久木野庁舎',
                }->{$subarea_name} || ''};
                if (defined $data) {
                    $Data->{$pref}->{areas}->{$area_name}->{areas}->{$subarea_name}->{office} = $data;
                }
            }
        }
    }
}

{
    my $f = file (__FILE__)->dir->parent->file ('intermediate', 'geonlp-pref.json');
    my $json = file2perl $f;
    for my $data (@$json) {
        $Data->{$data->{fullname}}->{office} ||= {
            address => $data->{address},
            position => [$data->{latitude}, $data->{longitude}],
        };
    }
}

print perl2json_bytes_for_record $Data;

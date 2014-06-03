use strict;
use warnings;
use utf8;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use Encode;
use JSON::Functions::XS qw(perl2json_bytes_for_record file2perl);
use Char::Normalize::FullwidthHalfwidth qw(normalize_width combine_voiced_sound_marks);
use Char::Transliterate::Kana qw(hiragana_to_katakana katakana_to_hiragana);

our $Data;
{
    my $soumu_f = file (__FILE__)->dir->parent->file ('local', 'soumu-jp-regions.json');
    $Data = file2perl $soumu_f;

    for my $name (keys %{$Data->{北海道}->{areas}}) {
        next unless $name =~ /局$/;
        my $def = delete $Data->{北海道}->{areas}->{$name};
        for (keys %{$def->{areas}}) {
            $def->{areas}->{$_}->{subpref_name} = $name;
            $Data->{北海道}->{areas}->{$_} = $def->{areas}->{$_};
            $def->{area_names}->{$_} = 1;
        }
        $Data->{北海道}->{subprefs}->{$name} = $def;
        $def->{kana} = delete $def->{hiragana};
        $def->{type} = 'subpref';
        delete $def->{areas};
    }
    for my $name (keys %{$Data->{東京都}->{areas}}) {
        next unless $name =~ /支庁$/;
        my $def = delete $Data->{東京都}->{areas}->{$name};
        for (keys %{$def->{areas}}) {
            $def->{areas}->{$_}->{subpref_name} = $name;
            $Data->{東京都}->{areas}->{$_} = $def->{areas}->{$_};
            $def->{area_names}->{$_} = 1;
        }
        $Data->{東京都}->{subprefs}->{$name} = $def;
        for (keys %{$Data->{東京都}->{subprefs} or {}}) {
            $Data->{東京都}->{subprefs}->{$_}->{kana}
                = delete $Data->{東京都}->{subprefs}->{$_}->{hiragana};
        }
        $def->{type} = 'subpref';
        delete $def->{areas};
    }
}

{
    my $jp_f = file (__FILE__)->dir->parent->file ('local', 'japanpost-jp-regions.json');
    my $jp_data = file2perl $jp_f;

$jp_data->{北海道}->{areas}->{色丹郡}
    = {type => 'district',
       kana => 'しこたんぐん', latin => 'Shikotan-gun'};
$jp_data->{北海道}->{areas}->{色丹郡}->{areas}->{色丹村}
    = {type => 'village', code => '01695',
       kana => 'しこたんむら', latin => 'Shikotan-mura'};
$jp_data->{北海道}->{areas}->{国後郡}
    = {type => 'district',
       kana => 'くなしりぐん', latin => 'Kunashiri-gun'};
$jp_data->{北海道}->{areas}->{国後郡}->{areas}->{泊村}
    = {type => 'village', code => '01696',
       kana => 'とまりむら', latin => 'Tomari-mura'};
$jp_data->{北海道}->{areas}->{国後郡}->{areas}->{留夜別村}
    = {type => 'village', code => '01697',
       kana => 'るよべつむら', latin => 'Ruyobetsu-mura'};
$jp_data->{北海道}->{areas}->{択捉郡}
    = {type => 'district',
       kana => 'えとろふぐん', latin => 'Etorofu-gun'};
$jp_data->{北海道}->{areas}->{択捉郡}->{areas}->{留別村}
    = {type => 'village', code => '01698',
       kana => 'るべつむら', latin => 'Rubetsu-mura'};
$jp_data->{北海道}->{areas}->{紗那郡}
    = {type => 'district',
       kana => 'しゃなぐん', latin => 'Shana-gun'};
$jp_data->{北海道}->{areas}->{紗那郡}->{areas}->{紗那村}
    = {type => 'village', code => '01699',
       kana => 'しゃなむら', latin => 'Shana-mura'};
$jp_data->{北海道}->{areas}->{蘂取郡}
    = {type => 'district',
       kana => 'しべとろぐん', latin => 'Shibetoro-gun'};
$jp_data->{北海道}->{areas}->{蘂取郡}->{areas}->{蘂取村}
    = {type => 'village', code => '01700',
       kana => 'しべとろむら', latin => 'Shibetoro-mura'};

    for my $name (keys %{$jp_data->{北海道}->{areas}}) {
        next unless $name =~ /郡(?:$| )/;
        my $def = delete $jp_data->{北海道}->{areas}->{$name};
        for (keys %{$def->{areas}}) {
            $def->{areas}->{$_}->{district_name} = $name;
            $jp_data->{北海道}->{areas}->{$_} = $def->{areas}->{$_};
            $def->{area_names}->{$_} = 1;
        }
        $jp_data->{北海道}->{districts}->{$name} = $def;
        $def->{type} = 'district';
        delete $def->{areas};
    }

    for my $pref (keys %$Data) {
        $Data->{$pref}->{latin} = $jp_data->{$pref}->{latin};
        for my $city (keys %{$Data->{$pref}->{areas} or {}}) {
            $Data->{$pref}->{areas}->{$city}->{latin} = $jp_data->{$pref}->{areas}->{$city}->{latin};
            $Data->{$pref}->{areas}->{$city}->{district_name} = $jp_data->{$pref}->{areas}->{$city}->{district_name}
                    if defined $jp_data->{$pref}->{areas}->{$city}->{district_name};
            for my $town (keys %{$Data->{$pref}->{areas}->{$city}->{areas} or {}}) {
                $Data->{$pref}->{areas}->{$city}->{areas}->{$town}->{latin} = $jp_data->{$pref}->{areas}->{$city}->{areas}->{$town}->{latin};
            }
        }
        $Data->{$pref}->{districts} = $jp_data->{$pref}->{districts}
            if defined $jp_data->{$pref}->{districts};
    }
}

sub type_by_suffix ($) {
    my $name = shift;
    $name =~ s/\s*\([^()]+\)$//;
    $name = substr $name, -1;
    return {
      市 => 'city',
      区 => 'ward',
      郡 => 'district',
      町 => 'town',
      村 => 'village',
    }->{$name};
}

for my $pref (keys %$Data) {
    $Data->{$pref}->{type} = 'pref';
    $Data->{$pref}->{kana} = delete $Data->{$pref}->{hiragana};
    katakana_to_hiragana $Data->{$pref}->{kana};
    for my $city (keys %{$Data->{$pref}->{areas} or {}}) {
        $Data->{$pref}->{areas}->{$city}->{type} = type_by_suffix $city;
        $Data->{$pref}->{areas}->{$city}->{kana} = delete $Data->{$pref}->{areas}->{$city}->{hiragana};
        katakana_to_hiragana $Data->{$pref}->{areas}->{$city}->{kana};
        for my $town (keys %{$Data->{$pref}->{areas}->{$city}->{areas} or {}}) {
            $Data->{$pref}->{areas}->{$city}->{areas}->{$town}->{type} = type_by_suffix $town;
            $Data->{$pref}->{areas}->{$city}->{areas}->{$town}->{kana} = delete $Data->{$pref}->{areas}->{$city}->{areas}->{$town}->{hiragana};
            katakana_to_hiragana $Data->{$pref}->{areas}->{$city}->{areas}->{$town}->{kana};
        }
    }
}

$Data->{福岡県}->{areas}->{糟屋郡}->{areas}->{須恵町}->{latin} = 'Sue-machi';

## <http://www.town.aomori-nanbu.lg.jp/>
$Data->{青森県}->{areas}->{三戸郡}->{areas}->{南部町}->{kana} = 'なんぶちょう';

## <http://www.town.takko.aomori.jp/>
$Data->{青森県}->{areas}->{三戸郡}->{areas}->{田子町}->{kana} = 'たっこまち';

## <http://www.town.arita.lg.jp/index2.php?q=296&p=10988&cm=03&cy=2006>
$Data->{佐賀県}->{areas}->{西松浦郡}->{areas}->{有田町}->{kana} = 'ありたちょう';

$Data->{岩手県}->{areas}->{滝沢市}->{latin} ||= 'Takizawa-shi';

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

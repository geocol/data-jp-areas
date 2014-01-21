use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use Encode;
use JSON::Functions::XS qw(perl2json_bytes_for_record);
use Char::Normalize::FullwidthHalfwidth qw(normalize_width combine_voiced_sound_marks);
use Web::DOM::Document;
use Web::XML::Parser;

my $Data = {};

sub _s ($) {
    my $s = $_[0];
    normalize_width \$s;
    combine_voiced_sound_marks \$s;
    $s =~ tr/\x{FF5E}\x{2212}/\x{301C}-/;
    return $s;
}

die "Download ZIP files from <http://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-P05.html> and extract into local/offices before running this script"
    unless -f file (__FILE__)->dir->parent->subdir ('local', 'offices')->file (sprintf 'P05-10_%02d-g.xml', 45);


for (1..47) {
    my $pref = sprintf '%02d', $_;
    my $f = file (__FILE__)->dir->parent->subdir ('local', 'offices')->file (sprintf 'P05-10_%02d-g.xml', $pref);
    my $doc = new Web::DOM::Document;
    my $parser = Web::XML::Parser->new;
    $parser->parse_char_string ((decode 'utf-8', scalar $f->slurp) => $doc);

    my $points = {};
    for my $el (@{$doc->document_element->children}) {
        if ($el->local_name eq 'Point') {
            my $pos = $el->query_selector ('pos');
            if (defined $pos and $pos->text_content =~ /^([0-9.]+)\s+([0-9.]+)$/) {
                $points->{'#'.$el->get_attribute_ns ('http://www.opengis.net/gml/3.2', 'id')} = [$1, $2];
            }
        } else {
            my $class = $el->query_selector ('publicOfficeClassification');
            if ($class and $class->text_content == 1) {
                my $pos = $el->query_selector ('position');
                if ($pos) {
                    my $href = $pos->get_attribute_ns ('http://www.w3.org/1999/xlink', 'href');
                    if ($points->{$href}) {
                        my $name = $el->query_selector ('publicOfficeName');
                        if ($name) {
                            my $addr = $el->query_selector ('address');
                            my $data = {position => $points->{$href}};
                            $data->{address} = _s $addr->text_content if $addr;
                            $Data->{$pref}->{$name->text_content} = $data;
                        }
                    }
                }
            }
        }
    }
}

print perl2json_bytes_for_record $Data;

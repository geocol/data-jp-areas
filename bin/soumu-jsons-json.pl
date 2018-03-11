use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use JSON::PS;
use Spreadsheet::Read;

#use Spreadsheet::ParseExcel::FmtJapan;
#*Spreadsheet::XLSX::FmtJapan::CnvNengo = \&Spreadsheet::ParseExcel::FmtJapan::CnvNengo;

my $root_path = path (__FILE__)->parent->parent;
my $xls_path = $root_path->child ('local/soumu-xlses');
my $json_path = $root_path->child ('local/soumu-jsons');
$json_path->mkpath;

for my $xls_path ($xls_path->children (qr/\.xlsx?$/)) {
  $xls_path =~ m{([^/]+)\.xls(x?)$};
  my $xlsx = $2;
  my $path = $json_path->child ("$1.json");
  #my $temp_path = $json_path->child ('temp');
  my $data = ReadData ($xls_path->stringify);
  if ($xlsx) {
    die "Not supported";
    #my $v = perl2json_chars $data;
    #$v =~ s/\\u(00[89][0-9A-F])/pack 'C', hex $1/ge;
    #$temp_path->spew ($v);
  } else {
    #$temp_path->spew (perl2json_bytes $data);
  }
  #$data = json_bytes2perl $temp_path->slurp;
  my $table = [];
  for my $cell (keys %{$data->[1]}) {
    if ($cell =~ /^([A-Z])([0-9]+)$/) {
      $table->[$2 - 1]->[-0x41 + ord $1] = $data->[1]->{$cell};
    }
  }
  $path->spew (perl2json_bytes $table);
} # $xls_path

## License: Public Domain.

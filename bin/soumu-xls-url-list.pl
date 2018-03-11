use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use Web::DOM::Document;
use Web::HTML::Parser;

my $root_path = path (__FILE__)->parent->parent;

my $input_path = $root_path->child ('local/soumu-code.html');
my $doc = new Web::DOM::Document;
my $parser = new Web::HTML::Parser;
$parser->onerror (sub { });
$parser->parse_byte_string (undef, $input_path->slurp, $doc);
$doc->manakai_set_url ("http://www.soumu.go.jp/denshijiti/code.html");

my $output_path = $root_path->child ('local/soumu-xlses');
$output_path->mkpath;
my $i = 0;
for (@{$doc->query_selector_all ('a[href$=".xls"]')}) {
  printf "wget -O %s %s && \\\n",
      $output_path->child ("$i.xls"),
      $_->href;
  $i++;
}
#for (@{$doc->query_selector_all ('a[href$=".xlsx"]')}) {
#  printf "wget -O %s %s && \\\n",
#      $output_path->child ("$i.xlsx"),
#      $_->href;
#  $i++;
#}
print "true\n";

## License: Public Domain.

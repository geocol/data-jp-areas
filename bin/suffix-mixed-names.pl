use strict;
use warnings;
use utf8;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use JSON::Functions::XS qw(perl2json_bytes_for_record file2perl);

my $f = file (__FILE__)->dir->parent->file ('local', 'all-area-names.json');
my $json = file2perl $f;

my @result;
my %by_suffix;

for my $area (@$json) {
  my $v = $area->[0];
  $v =~ s/\s*\([^()]+\)$//;
  $v =~ s/(.)$//;
  my $suffix = $1;
  if ($v =~ /[国都道府県市郡区町村]/) {
    push @result, $area;
    push @{$by_suffix{$suffix} ||= []}, $area->[0];
  }
}

@result = sort { $a->[0] cmp $b->[0] || $a->[1] <=> $b->[1] } @result;
print perl2json_bytes_for_record {
  areas => \@result,
  patterns => {map { $_ => join '|', map { quotemeta } sort @{$by_suffix{$_}} } keys %by_suffix},
};

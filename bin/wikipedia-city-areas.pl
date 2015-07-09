use strict;
use warnings;
use Path::Tiny;
use JSON::PS;
use AnyEvent;
use Promise;
use Promised::Command;

my $root_path = path (__FILE__)->parent->parent;
my $mwx_path = $root_path->child ('local/mwx');

sub extract ($) {
  my $name = $_[0];
  my $cmd = Promised::Command->new
      ([$mwx_path->child ('perl'),
        $mwx_path->child ('bin/extract-from-pages.pl'),
        '--rules-file-name' => $root_path->child ('src/nav-regions-rules.txt'),
        $name]);
  $cmd->stdout (\my $stdout);
  $cmd->run->then (sub { return $cmd->wait })->then (sub {
    die $_[0] unless $_[0]->exit_code == 0;
    return json_bytes2perl $stdout;
  });
} # extract

my $src_path = $root_path->child ('local/wp-city-areas.json');
my $src_data = json_bytes2perl $src_path->slurp;

my $Data = {};

my $p = Promise->resolve;
for (keys %$src_data) {
  for my $name (@{$src_data->{$_}}) {
    $p = $p->then (sub {
      return extract ($name)->then (sub {
        $Data->{$name} = $_[0];
      });
    });
  }
}

my $cv = AE::cv;
$p->then (sub {
  print perl2json_bytes_for_record $Data;
  $cv->send;
}, sub {
  $cv->croak ($_[0]);
});
$cv->recv;

## License: Public Domain.

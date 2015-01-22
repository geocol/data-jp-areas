use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use JSON::PS;
use IDs;

$IDs::RootDirPath = path (__FILE__)->parent->parent;
my $Data = json_bytes2perl path (__FILE__)->parent->parent->child ('local/jp-regions-2.json')->slurp;

sub assign_ids ($$);
sub assign_ids ($$) {
  my ($path, $items) = @_;
  for my $key (keys %$items) {
    my $data = $items->{$key};
    my $id;
    if (defined $data->{code}) {
      $id = IDs::get_id_by_string 'regions', $data->{code};
    } else {
      $id = IDs::get_id_by_string 'regions', $path . $key;
    }
    $data->{id} = $id;
    assign_ids $path . $key, $data->{areas} if defined $data->{areas};
    assign_ids $path . $key, $data->{districts} if defined $data->{districts};
    assign_ids $path . $key, $data->{subprefs} if defined $data->{subprefs};
  }
} # assign_ids

assign_ids '', $Data;

IDs::save_id_set 'regions';

print perl2json_bytes_for_record $Data;

## License: Public Domain.

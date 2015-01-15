use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use JSON::PS;

my $Input = json_bytes2perl path (__FILE__)->parent->parent->child ('data/jp-regions-full.json')->slurp;

my $Data = {};

my $subpref_name_to_id = {};
my $hokkaidou_district_name_to_id = {};

sub set_descendant_data ($$) {
  my ($data, $ancestor_id) = @_;
  for (
    [subpref => 'descendant_subpref_ids'],
    [city => 'descendant_city_ids'],
    [district => 'descendant_district_ids'],
    [ward => 'descendant_ward_ids'],
    [town => 'descendant_town_ids'],
    [village => 'descendant_village_ids'],
  ) {
    if ($data->{type} eq $_->[0]) {
      $Data->{regions}->{$ancestor_id}->{$_->[1]}->{$data->{id}} = 1;
    }
  }
} # set_descendant_data

sub copy_data ($$;%);
sub copy_data ($$;%) {
  my ($path, $input, %args) = @_;
  for my $key (keys %$input) {
    my $in = $input->{$key};
    my $data = {%$in};
    $Data->{regions}->{$in->{id}} = $data;
    $data->{qualified_name} = $path . $key;
    $data->{name} = $key;
    if ($in->{type} eq 'subpref') {
      $subpref_name_to_id->{$key} = $in->{id};
    }
    if ($in->{type} eq 'district' and $args{parent_region_id} == 2) {
      $hokkaidou_district_name_to_id->{$key} = $in->{id};
    }
    for my $k (qw(parent_region_id pref_id subpref_id city_id district_id)) {
      next unless defined $args{$k};
      $data->{$k} = $args{$k};
      set_descendant_data $data => $args{$k};
    }
    delete $data->{areas};
    delete $data->{subprefs};
    delete $data->{districts};
    delete $data->{area_names};
    my %a = %args;
    $a{parent_region_id} = $data->{id};
    $a{pref_id} = $data->{id} if $data->{type} eq 'pref';
    $a{city_id} = $data->{id} if $data->{type} eq 'city';
    $a{district_id} = $data->{id} if $data->{type} eq 'district';
    for (qw(areas subprefs districts)) {
      copy_data $path . $key, $in->{$_}, %a
          if defined $in->{$_};
    }
  }
} # copy_data
copy_data '', $Input;

for my $data (values %{$Data->{regions}}) {
  if (defined $data->{subpref_name}) {
    $data->{subpref_id} = $subpref_name_to_id->{$data->{subpref_name}} // die $data->{name};
    set_descendant_data $data => $data->{subpref_id};
    delete $data->{subpref_name};
  }
  if (defined $data->{district_name}) {
    $data->{district_id} = $hokkaidou_district_name_to_id->{$data->{district_name}} // die $data->{name};
    set_descendant_data $data => $data->{district_id};
    delete $data->{district_name};
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.

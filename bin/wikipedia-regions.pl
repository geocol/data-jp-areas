use strict;
use warnings;
use utf8;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use Encode;
use JSON::Functions::XS qw(perl2json_bytes_for_record file2perl);
use Char::Normalize::FullwidthHalfwidth qw(get_fwhw_normalized);
use AnyEvent;
use AnyEvent::MediaWiki::Source;
use Web::DOM::Document;
use Text::MediaWiki::Parser;

select STDERR;
$| = 1;
select STDOUT;

my $root_d = file (__FILE__)->dir->parent;
my $data_f = $root_d->file ('intermediate', 'wikipedia-regions.json');

our $Data = file2perl $data_f;

my $mw = AnyEvent::MediaWiki::Source->new_from_dump_f_and_cache_d
    ($root_d->file ('local', 'cache', 'xml', 'jawiki-latest-pages-meta-current.xml'),
     $root_d->subdir ('local', 'cache'));

sub _n ($) {
  my $s = shift;
  $s =~ s/\A\s+//;
  $s =~ s/\s+\z//;
  $s =~ s/\s+/ /;
  return get_fwhw_normalized $s;
} # _n

sub _tc ($);
sub _tc ($) {
  my $el = $_[0];
  return $el->data unless $el->node_type == $el->ELEMENT_NODE;
  my $text = '';
  for (@{$el->child_nodes}) {
    if ($_->node_type == $_->ELEMENT_NODE) {
      my $ln = $_->local_name;
      if ($ln eq 'comment' or $ln eq 'ref') {
        #
      } elsif ($ln eq 'noinclude') {
        #
      } elsif ($ln eq 'span') {
        my $v = _tc $_;
        $text .= $text unless $text eq "\x{25A0}";
      } elsif ($ln eq 'br') {
        $text .= "\x0A";
      } else {
        $text .= _tc $_;
      }
    } elsif ($_->node_type == $_->TEXT_NODE) {
      $text .= $_->data;
    }
  }
  return $text;
} # _tc

my $Defs = {
  画像 => {
    name => 'wikipedia_image_wref',
    type => 'file',
  },
  画像の説明 => {
    name => 'wikipedia_image_desc',
    type => 'text',
  },
  都道府県旗 => {
    name => 'flag_wref',
    type => 'file',
  },
  都道府県旗の説明 => {
    name => 'flag_label',
    type => 'text',
  },
  都道府県章 => {
    name => 'symbol_wref',
    type => 'file',
  },
  都道府県章の説明 => {
    name => 'symbol_label',
    type => 'text',
  },
  市章 => {
    name => 'symbol_wref',
    type => 'file',
  },
  市章の説明 => {
    name => 'symbol_label',
    type => 'text',
  },
  区章 => {
    name => 'symbol_wref',
    type => 'file',
  },
  区章の説明 => {
    name => 'symbol_label',
    type => 'text',
  },
  紋章 => {
    name => 'symbol_wref',
    type => 'file',
  },
  紋章の説明 => {
    name => 'symbol_label',
    type => 'text',
  },
};

my @target = map { [split /,/, decode 'utf-8', $_ ] } @ARGV;

sub extract_from_data ($$$$) {
  my ($target, $target_wref, $data, $cv) = @_;
  my $doc = new Web::DOM::Document;
  my $parser = Text::MediaWiki::Parser->new;
  $parser->parse_char_string ($data->{data} => $doc);
  my $el = $doc->query_selector ('include[wref="基礎情報 都道府県"], include[wref="日本の市"], include[wref="日本の町村"], include[wref="東京都の特別区"], include[wref="日本の行政区"]');
  if (not defined $el) {
    if ($target_wref =~ /郡(?: \([^()]+\))?$/) {
      $Data->{$target}->{wref} = $target_wref;
      $Data->{$target}->{timestamp} = $data->{timestamp};
    }
    $cv->end;
    return;
  }
  delete $Data->{$target};
  my @ip = grep { $_->local_name eq 'iparam' } @{$el->children};
  my $symbols_label;
  my $symbols_value;
  my $cv1 = AE::cv;
  $cv1->begin;
  for my $ip (@ip) {
    my $name = $ip->get_attribute ('name') || '';
    my $def = $Defs->{$name};
    if ($def) {
      my $value;
      if ($def->{type} eq 'file') {
        my $fc = $ip->first_element_child;
        if ($fc and $fc->local_name eq 'l' and $fc->has_attribute ('embed')) {
          $value = $fc->get_attribute ('wref') || _tc $fc;
        } elsif ($fc and $fc->local_name eq 'include' and
                 (lc $fc->get_attribute ('wref')) eq 'flagicon') {
              $cv1->begin;
              $mw->get_source_text_by_name_as_cv ("Template:Country flag alias $target_wref")->cb (sub {
                my $data = $_[0]->recv;
                if (defined $data) {
                  my $doc = new Web::DOM::Document;
                  my $parser = Text::MediaWiki::Parser->new;
                  $parser->parse_char_string ($data => $doc);
                  my $n = _tc $doc->body;
                  $n =~ s/\A\s+//;
                  $n =~ s/\s+\z//;
                  $Data->{$target}->{$def->{name}} = "ファイル:$n" if length $n;
                }
                $cv1->end;
              });
            } else {
              $value = _n _tc $ip;
            }
          } else {
            $value = _n _tc $ip;
          }
          $Data->{$target}->{$def->{name}} = $value
              if defined $value and length $value;
        } elsif ($name eq 'シンボル名') {
          $symbols_label = [split /\x0A/, _tc $ip];
        } elsif ($name eq '歌など' or $name eq '鳥など') {
          my $value = _tc $ip;
          $value =~ s{\x0A\s*([(（])}{ $1}g;
          $symbols_value = [split /\x0A/, $value];
        } elsif ($name eq '外部リンク') {
          my $fc = $ip->first_element_child;
          if ($fc and $fc->local_name eq 'xl') {
            $Data->{$target}->{url} = $fc->get_attribute ('href');
          } elsif ($fc and $fc->local_name eq 'include' and
                   $fc->get_attribute ('wref') eq 'official') {
            $Data->{$target}->{url} = 'http://' . _tc $fc;
          }
        } elsif ($name eq '木' or $name eq '花' or $name eq '鳥') {
          my $value = _tc $ip;
          $value =~ s{\x0A\s*([(（])}{ $1}g;
          for (split /[、\x0A]/, $value) {
            push @{$Data->{$target}->{symbols} ||= []},
                {type => {木 => 'tree', 花 => 'flower',
                          鳥 => 'bird'}->{$name}, name => _n $_};
          }
        }
      }
      $cv1->end;
      $cv1->cb (sub {
      if (defined $Data->{$target}->{symbol_wref}) {
        my $d = {type => 'mark', wref => delete $Data->{$target}->{symbol_wref}};
        $d->{name} = delete $Data->{$target}->{symbol_label}
            if defined $Data->{$target}->{symbol_label};
        unshift @{$Data->{$target}->{symbols} ||= []}, $d;
      }
      if (defined $Data->{$target}->{flag_wref}) {
        my $d = {type => 'flag', wref => delete $Data->{$target}->{flag_wref}};
        $d->{name} = delete $Data->{$target}->{flag_label}
            if defined $Data->{$target}->{flag_label};
        unshift @{$Data->{$target}->{symbols} ||= []}, $d;
      }
      if (defined $symbols_value) {
        for my $i (0..$#$symbols_value) {
          my $value = _n $symbols_value->[$i];
          my $label = _n ($symbols_label->[$i] || $symbols_label->[-1] || '');
          my @v;
          if ($value =~ /^([^:]+):(.+)$/) {
            my ($n, $v) = ($1, $2);
            push @v, {label => _n $n, name => _n $_} for split /、/, $v;
        } elsif ($value =~ /^(.+) - (.+)$/) {
            my ($n, $v) = ($1, $2);
            push @v, {label => _n $n, name => _n $_} for split /、/, $v;
          } else {
            push @v, {label => $label, name => $value};
          }
          for (@v) {
            $_->{type} = 'song' if $_->{label} =~ /歌/;
            $_->{type} = 'fish' if $_->{label} =~ /魚/;
            $_->{type} = 'animal' if $_->{label} =~ /獣/;
            $_->{type} = 'day' if $_->{label} =~ /日/;
            $_->{type} = 'bird' if $_->{label} =~ /鳥/;
            if (defined $_->{name} and
                $_->{name} =~ /^(\d+)月(\d+)日$/) {
              $_->{date_value} = sprintf '%02d-%02d', $1, $2;
              delete $_->{name};
            }
            if (defined $_->{name} and
                $_->{name} =~ s/^(#[0-9A-Fa-f]{3,})\x{25A0}\s*//) {
              $_->{color_value} = uc $1;
            }
            delete $_->{label} if $_->{label} eq '' or $_->{label} =~ /^[都道府県]の歌$/;
          }
          push @{$Data->{$target}->{symbols} ||= []}, @v;
        }
      }
      @{$Data->{$target}->{symbols} or []} = grep {
        not (defined $_->{name} and ($_->{name} eq '未制定' or $_->{name} eq '-'));
      } @{$Data->{$target}->{symbols} or []};
      for (@{$Data->{$target}->{symbols} or []}) {
        if (defined $_->{name} and $_->{name} =~ s/\s*\(?(\d+)年(?:\s*\([^()]+\)\s*)?(\d+)月(\d+)日[^()]+\)?\s*$//) {
          $_->{date} = sprintf '%04d-%02d-%02d', $1, $2, $3;
        } elsif (defined $_->{name} and $_->{name} =~ s/\s*\(?(\d+)年(?:\s*\([^()]+\)\s*)?(\d+)月[^()]+\)?\s*$//) {
          $_->{date} = sprintf '%04d-%02d', $1, $2;
        } elsif (defined $_->{name} and $_->{name} =~ s/\s*\(?(\d+)年(?:\s*\([^()]+\)\s*)?[^()]+\)?\s*$//) {
          $_->{date} = sprintf '%04d', $1;
        }
      if (defined $_->{name} and $_->{name} =~ s/\s*\(作曲:([^()]+)\)\s*$//) {
        $_->{song_by} = $1;
      }
      delete $_->{name} if defined $_->{name} and not length $_->{name};
    }
    $Data->{$target}->{wref} = $target_wref;
    $Data->{$target}->{timestamp} = $data->{timestamp};
    print STDERR ".";
    $cv->end;
  });
} # extract_from_data

sub _get ($$$$$);
sub _get ($$$$$) {
  my ($target, $target_wref, $wrefs, $ims, $cv) = @_;
  $mw->get_source_text_by_name_as_cv ($target_wref, ims => $ims || 0)->cb (sub {
    my $data = $_[0]->recv;
    if (defined $data and defined $data->{data}) {
      extract_from_data $target, $target_wref, $data, $cv;
    } elsif (defined $data and $data->{not_modified}) {
      $cv->end;
    } else {
      if (@$wrefs) {
        my $wref = shift @$wrefs;
        _get $target, $wref, $wrefs, $ims, $cv;
      } else {
        $cv->end;
      }
    }
  });
} # _get

my $cv = AE::cv;
$cv->begin;
for my $target (@target) {
  $cv->begin;
  my $target_key = join ',', @$target;
  my @wref;
  push @wref, '泊村 (北海道根室支庁)' if @$target >= 3 and $target->[-1] eq '泊村' and $target->[-2] eq '国後郡';
  push @wref, sprintf '%s (%s)', $target->[-1], $target->[-2] if @$target >= 2;
  push @wref, sprintf '%s (%s)', $target->[-1], $target->[-3] if @$target >= 3;
  push @wref, $target->[-1];
  my $target_wref = shift @wref;
  my $ims = $Data->{$target_key}->{timestamp}; # or undef
  _get $target_key, $target_wref, \@wref, $ims, $cv;
}
$cv->end;

$cv->cb (sub {
  print { $data_f->openw } perl2json_bytes_for_record $Data;
});

$cv->recv;

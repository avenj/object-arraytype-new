package Object::ArrayType::New;
use strict; use warnings;

use Carp;
use B ();
use Scalar::Util 'blessed', 'reftype';

sub import {
  my ($class, $params) = @_;
  $params = [] unless defined $params;
  croak "Expected an ARRAY or HASH but got $params"
    unless ref $params 
    and reftype $params eq 'ARRAY'
    or  reftype $params eq 'HASH';

  my $target = caller;
  $class->_validate_and_install($target => $params)
}

sub _inject_code {
  my ($class, $target, $code) = @_;
  confess "Expected a target package and string to inject"
    unless defined $target and defined $code;

  my $run = "package $target; $code; 1;";
  warn "(eval ->) $run\n" if $ENV{OBJECT_ARRAYTYPE_DEBUG};
  local $@; eval $run; die $@ if $@;

  1
}

sub _inject_constant {
  my ($class, $target, $name, $val) = @_;

  my $code = ref $val ? "sub $name () { \$val }"
    : "sub $name () { ${\ B::perlstring($val) } }";

  $class->_inject_code($target => $code)
}

sub _install_constants {
  my ($class, $target, $items) = @_;
  my $idx = 0;
  for my $item (@$items) {
    my $constant = $item->{constant};
    $class->_inject_constant($target => $constant => $idx);
    $idx++
  }
  1
}

sub _validate_and_install {
  my ($class, $target, $params) = @_;

  my @items = reftype $params eq 'HASH' ? %$params : @$params;

  my @install;
  PARAM: while (my ($initarg, $def) = splice @items, 0, 2) {
    my $store = $def ? $def : uc($initarg);
    push @install, +{
      name     => $initarg,
      constant => $store,
    };
  }

  $class->_install_constants($target => \@install);
  $class->_install_constructor($target => \@install);

  1
}

sub _generate_storage {
  my ($class, $target, $items) = @_;
  my $idx = 0;
  my $code = qq[  bless \$self, \$class;\n  my \@def;\n];
  for my $item (@$items) {
    my $attr = $item->{name};
    $code .= qq[  \$self->[$idx] = defined \$args->{$attr} ?\n];
    $code .= qq[    \$args->{$attr} : undef;\n];
    $idx++
  }

  $code
}

sub _install_constructor {
  my ($class, $target, $items) = @_;

  my $code = <<'_EOC';
sub new {
  my $class = shift; my $args;
  if (@_ == 1) {
    Carp::confess "Expected single param to be a HASH but got $_[0]"
      unless ref $_[0] and Scalar::Util::reftype $_[0] eq 'HASH';
    $args = +{ %{ $_[0] } }
  } elsif (@_ % 2) {
    Carp::confess "Expected either a HASH or a list of key/value pairs"
  } else {
    $args = +{ @_ }
  }

  my $self = [];

_EOC
  
  $code .= $class->_generate_storage($target => $items);
  $code .= "  \$self\n}\n";

  $class->_inject_code($target => $code)  
}


1;

# vim: ts=2 sw=2 et sts=2 ft=perl

package Object::ArrayType::New;
use strict; use warnings;

use Carp;
use B ();
use Scalar::Util 'reftype';

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
    # FIXME allow empty-string init args, always set undef in _generate_storage
    confess "Don't know what to do with boolean false parameter"
      unless $initarg;
    my $store = $def ? $def : uc($initarg);
    push @install, +{
      name     => $initarg,
      constant => $store,
    };
  }

  $class->_install_constants($target => \@install);
  $class->_install_constructor($target => \@install);
}

sub _generate_storage {
  my (undef, undef, $items) = @_;
  my $code = "  my \$self = bless [\n";
  for my $item (@$items) {
    my $attr = $item->{name};
    $code .= qq[   (defined \$args{$attr} ? \$args{$attr} : undef),\n];
  }
  $code .= '  ], $class;';
  $code
}

sub _install_constructor {
  my ($class, $target, $items) = @_;

  my $code = <<'_EOC';
sub new {
  my $class = shift; my %args;
  if (@_ == 1) {
    Carp::confess "Expected single param to be a HASH but got $_[0]"
      unless ref $_[0] and Scalar::Util::reftype $_[0] eq 'HASH';
    %args = %{ $_[0] }
  } elsif (@_ % 2) {
    Carp::confess "Expected either a HASH or a list of key/value pairs"
  } else {
    %args = @_
  }

_EOC
  
  $code .= $class->_generate_storage($target => $items);
  $code .= "\n  \$self\n}\n";
  $class->_inject_code($target => $code)  
}

print
  q[<SpiceMan> also every time you @result = `curl blahblah`],
  qq[ LeoNerd uses passive voice\n]
unless caller;
1;

=pod

=for Pod::Coverage import

=head1 NAME

Object::ArrayType::New - Inject constants & constructors for ARRAY-type objects

=head1 SYNOPSIS

  package MyObject;
  use strict; use warnings;
  use Object::ArrayType::New
    [ foo => 'FOO', bar => 'BAR' ];
  sub foo { shift->[FOO] }
  sub bar { shift->[BAR] ||= [] }

  package main;
  my $obj = MyObject->new(foo => 'baz');
  my $foo = $obj->foo; # baz
  my $bar = $obj->bar; # []

=head1 DESCRIPTION

A common thing I find myself doing looks something like:

  package MySimpleObject;
  use strict; use warnings;

  sub TAG () { 0 }
  sub BUF () { 1 }

  sub new {
    my $class = shift;
    my %params = @_ > 1 ? @_ : %{ $_[0] };
    bless [
      $params{tag},             # TAG
      ($params{buffer} || [])   # BUF
    ], $class
  }
  sub tag     { shift->[TAG] }
  sub buffer  { shift->[BUF] }

... when I'd rather be doing something more like the L</SYNOPSIS>.

This tiny module takes a list of pairs mapping a C<new()> parameter to the name of
a constant representing the parameter's position in the backing ARRAY. If the
constant's name is boolean false, the uppercased parameter name is taken as
the name of the constant.

An appropriate constructor is generated and installed, as well as constants
that can be used within the class to index into the C<$self> object.

The generated constructor takes parameters as either a list of pairs or a
single HASH. Parameters not specified at construction time are C<undef>.

That's it; no accessors, no defaults, no type-checks, no required attributes,
nothing fancy -- L<Class::Method::Modifiers> may be convenient there. The
above example could be written something like:

  use Object::ArrayType::New [ tag => '', buffer => 'BUF' ];
  sub tag    { shift->[TAG] }
  sub buffer { shift->[BUF] }
  use Class::Method::Modifers;
  around new => sub {
    my ($orig, $class) = splice @_, 0, 2;
    my $self = $class->$orig(@_);
    $self->[BUF] = [] unless defined $self->[BUF];
    $self
  };

if C<< $ENV{OBJECT_ARRAYTYPE_DEBUG} >> is true, generated code is printed to
STDERR before being evaluated.

Constants aren't currently sanity-checked ahead of time; attempting to use
invalid identifiers will result in 'Illegal declaration ...' failures.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut

# vim: ts=2 sw=2 et sts=2 ft=perl

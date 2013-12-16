use Test::More;
use strict; use warnings;

{ package ArrayType::Basic;
  use strict; use warnings;
  use Object::ArrayType::New [ foo => 'FOO', bar => '', baz => '' ];
  sub foo { shift->[FOO] }
  sub bar { shift->[BAR] }
  sub baz { shift->[BAZ] }
}

my $obj = ArrayType::Basic->new(
  foo => 1,
  bar => 2
);

ok $obj->foo == 1, 'foo ok';
ok $obj->bar == 2, 'bar ok';
ok !defined $obj->baz, 'baz ok';

$obj = ArrayType::Basic->new(
  +{ foo => 1 }
);

ok $obj->foo == 1, 'hash passed to new ok';
ok !defined $obj->bar, 'bar undef ok';

{ package ArrayType::HashOpts;
  use strict; use warnings;
  use Object::ArrayType::New +{ foo => '_foo', bar => '_bar' };
  sub foo { shift->[_foo] }
  sub bar { shift->[_bar] }
}

$obj = ArrayType::HashOpts->new(
  foo => 123,
  bar => 456
);

ok $obj->foo == 123, 'hash-type params foo ok';
ok $obj->bar == 456, 'hash-type params bar ok';

done_testing

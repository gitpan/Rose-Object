package Rose::Class::MakeMethods::Generic;

use strict;

use Carp();

our $VERSION = '0.011';

use Rose::Object::MakeMethods;
our @ISA = qw(Rose::Object::MakeMethods);

our %Scalar;
# (
#   class_name =>
#   {
#     some_attr_name1 => ...,
#     some_attr_name2 => ...,
#     ...
#   },
#   ...
# );

sub scalar
{
  my($class, $name, $args, $options) = @_;

  my %methods;

  my $interface = $args->{'interface'} || 'get_set';

  if($interface eq 'get_set')
  {
    $methods{$name} = sub
    {
      return $Scalar{$_[0]}{$name} = $_[1]  if(@_ > 1);
      return $Scalar{$_[0]}{$name};
    };
  }
  elsif($interface eq 'get_set_init')
  {
    my $init_method = $args->{'init_method'} || "init_$name";

    $methods{$name} = sub
    {      
      return $Scalar{$_[0]}{$name} = $_[1]  if(@_ > 1);
      return defined $Scalar{$_[0]}{$name} ? 
        $Scalar{$_[0]}{$name} : ($Scalar{$_[0]}{$name} = $_[0]->$init_method())
    };
  }

  return \%methods;
}

our %Inheritable_Scalar;
# (
#   class_name =>
#   {
#     some_attr_name1 => ..., # ref to scalar
#     some_attr_name2 => ..., # ref to scalar
#     ...
#   },
#   ...
# );

sub inheritable_scalar
{
  my($class, $name, $args, $options) = @_;

  my %methods;

  my $interface = $args->{'interface'} || 'get_set';

  if($interface eq 'get_set')
  {
    $methods{$name} = sub 
    {
      my($class) = ref($_[0]) ? ref(shift) : shift;

      if(@_)
      {
        my $value = shift;
        return ${$Inheritable_Scalar{$class}{$name} = \$value};
      }

      return ${$Inheritable_Scalar{$class}{$name}}
        if(exists $Inheritable_Scalar{$class}{$name});

      my @parents = ($class);

      while(my $parent = shift(@parents))
      {
        no strict 'refs';
        foreach my $subclass (@{$parent . '::ISA'})
        {
          push(@parents, $subclass);

          if(exists $Inheritable_Scalar{$subclass}{$name})
          {
            return ${$Inheritable_Scalar{$subclass}{$name}}
          }
        }
      }

      return undef;
    };
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

1;

__END__

=head1 NAME

Rose::Class::MakeMethods::Generic - Create simple class methods.

=head1 SYNOPSIS

  package MyClass;

  use Rose::Class::MakeMethods::Generic
  (
    scalar => 
    [
      'error',
      'type' => { interface => 'get_set_init' },
    ],

    inheritable_scalar => 'name',
  );

  sub init_type { 'special' }
  ...

  package MySubClass;
  our @ISA = qw(MyClass);
  ...

  MyClass->error(123);

  print MyClass->type; # 'special'

  MyClass->name('Fred');
  print MySubClass->name; # 'Fred'

  MyClass->name('Wilma');
  print MySubClass->name; # 'Wilma'

  MySubClass->name('Bam');
  print MyClass->name;    # 'Wilma'
  print MySubClass->name; # 'Bam'

=head1 DESCRIPTION

C<Rose::Class::MakeMethods::Generic> is a method maker that inherits
from C<Rose::Object::MakeMethods>.  See the C<Rose::Object::MakeMethods>
documentation to learn about the interface.  The method types provided
by this module are described below.  All methods work only with
classes, not objects.

=head1 METHODS TYPES

=over 4

=item B<scalar>

Create get/set methods for scalar class attributes.

=over 4

=item Options

=over 4

=item C<init_method>

The name of the class method to call when initializing the value of an
undefined attribute.  This option is only applicable when using the
C<get_set_init> interface.  Defaults to the method name with the prefix
C<init_> added.

=item C<interface>

Choose one of the two possible interfaces.  Defaults to C<get_set>.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a simple get/set accessor method for a class attribute.  When
called with an argument, the value of the attribute is set.  The current
value of the attribute is returned.

=item C<get_set_init> 

Behaves like the C<get_set> interface unless the value of the attribute
is undefined.  In that case, the class method specified by the
C<init_method> option is called and the attribute is set to the return
value of that method.

=back

=back

Example:

    package MyClass;

    use Rose::Class::MakeMethods::Generic
    (
      scalar => 'power',
      'scalar --get_set_init' => 'name',
    );

    sub init_name { 'Fred' }
    ...

    MyClass->power(99);    # returns 99
    MyClass->name;         # returns "Fred"
    MyClass->name('Bill'); # returns "Bill"

=item B<inheritable_scalar>

Create get/set methods for scalar class attributes that are
inherited by subclasses until/unless their values are changed.

=over 4

=item Options

=over 4

=item C<interface>

Choose the interface.  This is kind of pointless since there is only
one interface right now.  Defaults to C<get_set>, obviously.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a get/set accessor method for a class attribute.  When called
with an argument, the value of the attribute is set and then returned.

If called with no arguments, and if the attribute was never set for this
class, then a left-most, breadth-first search of the parent classes is
initiated.  The value returned is taken from first parent class 
encountered that has ever had this attribute set.

=back

=back

Example:

    package MyClass;

    use Rose::Class::MakeMethods::Generic
    (
      inheritable_scalar => 'name',
    );
    ...

    package MySubClass;
    our @ISA = qw(MyClass);
    ...

    package MySubSubClass;
    our @ISA = qw(MySubClass);
    ...

    $x = MyClass->name;       # undef
    $y = MySubClass->name;    # undef
    $z = MySubSubClass->name; # undef

    MyClass->name('Fred');
    $x = MyClass->name;       # 'Fred'
    $y = MySubClass->name;    # 'Fred'
    $z = MySubSubClass->name; # 'Fred'

    MyClass->name('Wilma');
    $x = MyClass->name;       # 'Wilma'
    $y = MySubClass->name;    # 'Wilma'
    $z = MySubSubClass->name; # 'Wilma'

    MySubClass->name('Bam');
    $x = MyClass->name;       # 'Wilma'
    $y = MySubClass->name;    # 'Bam'
    $z = MySubSubClass->name; # 'Bam'

    MyClass->name('Koop');
    MySubClass->name(undef);
    $x = MyClass->name;       # 'Koop'
    $y = MySubClass->name;    # undef
    $z = MySubSubClass->name; # undef

    MySubSubClass->name('Sam');
    $x = MyClass->name;       # 'Koop'
    $y = MySubClass->name;    # undef
    $z = MySubSubClass->name; # 'Sam'

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2004 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

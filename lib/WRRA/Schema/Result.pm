package WRRA::Schema::Result;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components(qw/InflateColumn::DateTime Helper::Row::Crud Helper::Row::WithRelated/);

sub nameid { my $self = shift; join ':', $self->name, $self->id; }
sub _value { shift->value }

1;

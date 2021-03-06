use utf8;
package WRRA::Schema::Result::Donor;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

WRRA::Schema::Result::Donor

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<WRRA::Schema::Result>

=cut

use base 'WRRA::Schema::Result';

=head1 TABLE: C<donors>

=cut

__PACKAGE__->table("donors");

=head1 ACCESSORS

=head2 donor_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 chamberid

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 phone

  data_type: 'varchar'
  is_nullable: 0
  size: 15

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 category

  data_type: 'set'
  extra: {list => ["bank","lawyer","realty","doctor","cpa","personal","esq","seq","insurance"]}
  is_nullable: 1

=head2 contact1

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 contact2

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 address

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 city

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 state

  data_type: 'char'
  is_nullable: 1
  size: 2

=head2 zip

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 email

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 url

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 advertisement

  data_type: 'varchar'
  is_nullable: 1
  size: 1200

=head2 solicit

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

=head2 comments

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 rotarian_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "donor_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "chamberid",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "phone",
  { data_type => "varchar", is_nullable => 0, size => 15 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "category",
  {
    data_type => "set",
    extra => {
      list => [
        "bank",
        "lawyer",
        "realty",
        "doctor",
        "cpa",
        "personal",
        "esq",
        "seq",
        "insurance",
      ],
    },
    is_nullable => 1,
  },
  "contact1",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "contact2",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "address",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "city",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "state",
  { data_type => "char", is_nullable => 1, size => 2 },
  "zip",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "email",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "url",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "advertisement",
  { data_type => "varchar", is_nullable => 1, size => 1200 },
  "solicit",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
  "comments",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "rotarian_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</donor_id>

=back

=cut

__PACKAGE__->set_primary_key("donor_id");


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2013-03-13 14:11:46
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:W2ko850noJ76CAWfooHJPg

use Class::Method::Modifiers;
__PACKAGE__->belongs_to(rotarian => 'WRRA::Schema::Result::Rotarian', 'rotarian_id', {join_type=>'left'});	# A Donor belongs_to a Rotarian
__PACKAGE__->has_many(items => 'WRRA::Schema::Result::Item', 'donor_id'); # A Donor has_many Items

sub id { shift->donor_id }

around 'phone' => sub {
	my $orig = shift;
	my $self = shift;
	if ( $_[0] ) {
		$_[0] =~ s/\D//g;
		$_[0] = "($1) $2-$3" if $_[0] =~ /^(\d{3})(\d{3})(\d{4})$/;
	}
	return $self->$orig(@_);
};

sub contact {
	my $self = shift;
	return join('|', grep { $_ } $self->contact1, $self->contact2) || undef;
}

sub ly_items { shift->items->last_year->count }

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

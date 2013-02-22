package WRRA::Schema;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces(
    default_resultset_class => 'ResultSet',
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-11-16 09:09:02
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wM5zCfXKD5Qnd99BQCHs2w

# $self->result_source->schema->myconfig
our $config;
sub config {
	my $self = shift;
	$config = shift if $_[0];
	return $config;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
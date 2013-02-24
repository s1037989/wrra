package WRRA::Schema::ResultModel::Bellcount;

use base 'WRRA::Schema::Result::Bellcount';

sub TO_XLS { shift->arrayref(qw(id bellitem qty)) }
sub TO_JSON {
	my $self = shift;
	return {
		(map { $_ => $self->$_ } qw(id qty)),
		bellitem => {
			nameid => $self->eval('$self->bellitem->nameid'),
		},
	};
}

1;
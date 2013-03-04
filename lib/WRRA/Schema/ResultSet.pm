package WRRA::Schema::ResultSet;

use base qw/DBIx::Class::ResultSet::HashRef DBIx::Class::ResultSet/;

__PACKAGE__->load_components(qw(Helper::ResultSet::Me Helper::ResultSet::Jqgrid Helper::ResultSet::View));

use strict;
use warnings;

sub next_year { $_[0]->search({$_[0]->me.'year' => $_[0]->session->{year}+1}) }
sub current_year { $_[0]->search({$_[0]->me.'year' => $_[0]->session->{year}}) }
sub last_year { $_[0]->search({$_[0]->me.'year' => $_[0]->session->{year}-1}) }
sub recent_years { $_[0]->search({$_[0]->me.'year' => {-between => [$_[0]->session->{year}-$_[0]->session->{recent_years}+1, $_[0]->session->{year}]}}) }

1;

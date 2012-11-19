package Schema::ResultSet;

use base qw/DBIx::Class::ResultSet::HashRef DBIx::Class::ResultSet/;
#use base qw/DBIx::Class::ResultSet/;
__PACKAGE__->load_components(qw{Helper::ResultSet::Shortcut});

use Data::Dumper;

sub app {
	my $self = shift;
	my $app = $self->result_source->storage->_connect_info->[0]->{app};
	$app->config->{year} ||= ((localtime())[5])+1900;
	return $app;
}
sub year { shift->app->config->{year} }
# !!! Does NOT work as expected!!!!!!!!!!!!
sub warn_json { my $self = shift; warn Dumper($self->${\('hashref_'.(shift || 'first'))}); $self }

sub next_year { $_[0]->search({year => $_[0]->app->config->{year}+1}) }
sub current_year { $_[0]->search({year => $_[0]->app->config->{year}}) }
sub last_year { $_[0]->search({year => $_[0]->app->config->{year}-1}) }
sub recent_years { $_[0]->search({year => {-between => [$_[0]->app->config->{year}-2, $_[0]->app->config->{year}]}}) }
sub donor { $_[0]->search({'donor.name' => {-like => '%'.$_[0].'%'}}, {join=>'donor'}) }

# Grid can use ->all TO_JSON recursion; ->hashref_array for big trees of data
sub grid {
	my $self = shift;
	return {
                page=>$self->pager->current_page||1,
                total=>$self->pager->last_page||1,
                records=>$self->pager->total_entries||1,
                rows => [$self->all],
	};
}

1;
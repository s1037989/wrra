package WRRA::Schema::ResultView::Result::Rotarians;

use base 'WRRA::Schema::Result::Rotarian';

sub _columns { qw/id name has_submissions email phone/ }
sub _search_id { 'rotarian_id' }
sub _search_name { 'concat(lastname, firstname)' }
sub _order_by_name { \'concat(lastname, firstname)' }

1;

__END__
#__PACKAGE__->load_components(qw{Helper::Result::Jqgrid});
# See Cookbook : Wrapping/overloading_a_column_accessor
# This might be for when updating a column that doesn't exist
#__PACKAGE__->add_columns(name => { accessor => '_name' });
#__PACKAGE__->add_columns(number => { accessor => '_number' });
#sub _prefetch { ['donor','stockitem'] }
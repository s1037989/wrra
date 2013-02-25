package WRRA::Schema::ResultModel::Bidders;

use base 'WRRA::Schema::Result::Bidder';

sub resolver {
	search => {
		#name => \'concat(lastname, ", ", firstname)',
		#highbidder => 'bidder.name',
		#highbid => 'highbid.bid',
		#soldday => \'dayname(sold)',
	},
	order_by => {
		#name => ['lastname', 'firstname'],
		#soldday => [\'cast(sold as date)', 'number'],
	},
	update_or_create => {
		#'id' => sub { rotarian_id=>shift },
		#'name' => sub {
		#	my ($last, $first) = (shift =~ /^([^,]+), ([^,]+)$/);
		#	return lastname=>$last,firstname=>$first;
		#},
	},
	create_defaults => {
		year => sub { shift->year },
	},
	validate => {
		#name => qr/^([^,]+), ([^,]+)$/,
	},
}

sub TO_XLS { shift->arrayref(qw(id name email phone address city state zip)) }
sub TO_JSON { shift->hashref(qw(id name email phone address city state zip)) }

1;

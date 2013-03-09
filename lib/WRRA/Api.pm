package WRRA::Api;
use Mojo::Base 'Mojolicious::Controller';

use 5.010;

sub api_dbconfig {
	my $self = shift;
	$self->session->{$self->param('config')} = $self->param($self->param('config')) if $self->param($self->param('config'));
	$self->respond_to(
		json => {json => {$self->param('config') => $self->db->session->{$self->param('config')}}},
	);
}

sub auto_complete {
	my $self = shift;
	my $rs = $self->ac($self->db->resultset($self->param('results')));
	$self->respond_to(
		json => {json => [$rs->all]},
	);
}

sub build_select {
	my $self = shift;
	$self->render(rs => [$self->bs($self->db->resultset($self->param('results')))->all]);
}

sub header {
	my $self = shift;
	$self->respond_to(
		json => {json => {
			header => {
				about => {
					name => 'Washington Rotary Radio Auction',
					year => $self->db->session->{year},
					night => $self->db->session->{auctions}->{$self->db->session->{year}}->[0],
					live => 0,
					date_next => 'Tomorrow',
				},
				play => $self->config('play'),
				alert => {
					msg => eval { $self->db->resultset('Alert')->search({alert=>'public'})->first->msg } || '',
				},
			},
			ads => {
				ad => _display_ad($self),
			},
		}},
	);
}

sub alert {
        my $self = shift;
	given ( $self->req->method ) {
		when ( 'DELETE' ) {
                        my $alert = $self->param('alert') || 'public';
                        my $msg = $self->param('msg');
                        my $r = $self->db->resultset('Alert')->search({alert=>$alert})->delete_all;
                        $self->respond_to(
                                json => {json => {clearalert => $r}},
                        );
		}
		when ('POST' ) {
                        my $alert = $self->param('alert') || 'public';
                        my $msg = $self->param('msg');
                        my $r = $self->db->resultset('Alert')->update_or_create({alert=>$alert, msg=>$msg}) if $alert && defined $msg;
                        $self->respond_to(
                                json => {json => {alert=>$r->alert, msg=>$r->msg}},
                        );
		}
		default {
		        my $alert = $self->param('alert') || 'public';
			my $rs = $self->db->resultset('Alert')->search({alert=>$alert})->first;
			$self->respond_to(
				json => {json => {msg => $rs?$rs->msg:undef}},
			);
		}
	}
}

sub ad {
        my $self = shift;
	my $ad = $self->db->resultset('Ads')->find($self->param('id')) or return $self->render_not_found;
	my $r;
	if ( $r = $self->db->resultset('Adcount')->find($self->param('id'), \'=cast(now() as date)') ) {
		$r->update({click=>$r->click+1});
	} elsif ( $r = $self->db->resultset('Adcount')->new({ad_id=>$self->param('id'), processed=>\'now()', click=>1}) ) {
		$r->insert;
	}
	warn $r->click;
	warn $ad->url||'http://www.washingtonrotary.com';
	$self->redirect_to($ad->url||'http://www.washingtonrotary.com');
}

sub _display_ad {
	my $self = shift;
        my $adsdir = join '/', $self->app->home, 'public', ($self->config('ads') || 'ads');
        my $adsurl = join '/', ($self->config('ads') || 'ads');
        return $self->session->{ad} if $self->session->{ad_ctime} && time-$self->session->{ad_ctime}<=10;
        $self->session->{ad_ctime} = time;

	my $ad;
	foreach my $_ad ( $self->db->resultset('Ads')->today->random->all ) {
		$ad = {map { $_ => $_ad->$_ } qw/url year advertiser_id ad_id/};
		my $r;
		if ( $r = $self->db->resultset('Adcount')->find($ad->{ad_id}, \'=cast(now() as date)') ) {
			$r->update({rotate=>$r->rotate+1});
		} elsif ( $r = $self->db->resultset('Adcount')->new({ad_id=>$ad->{ad_id}, processed=>\'now()', rotate=>1}) ) {
			$r->insert;
		}
		$ad->{img} = (glob("$adsdir/$ad->{year}/$ad->{advertiser_id}-$ad->{ad_id}.*"))[0] || (glob("$adsdir/$ad->{year}/$ad->{advertiser_id}.*"))[0] if $ad->{advertiser_id} && $ad->{ad_id};
		$ad->{img} && -e $ad->{img} && -f _ && -r _ && do {
                        $ad->{img} =~ s/^$adsdir\/?// or $ad->{img} = undef;
			$ad->{img} = join '/', '', $adsurl, $ad->{img} if $ad->{img};
                        $ad->{refresh} = 1;
			$r->update({display=>$r->display+1});
                        last;
                }
	}
	return $ad;
}

1;

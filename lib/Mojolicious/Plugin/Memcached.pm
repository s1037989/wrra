package Mojolicious::Plugin::Memcached;
use Mojo::Base 'Mojolicious::Plugin';

use Cache::Memcached;

my $memd;
my $actions;

sub register {
	my ($self, $app, $conf) = @_;

	if ( defined $conf->{actions} ) {
		$actions = { map { $_ => 1 } @{$conf->{actions}} };
	}

	unless ( $memd ) {
		$memd = new Cache::Memcached $conf->{conf} || $app->config->{memcached} || {servers => [qw/127.0.0.1:11211/]};
		$memd->flush_all;
	}

	$app->hook(after_static => sub { # Move to Mojolicious::Plugin::CacheControl
		my $c = shift;
		$c->res->headers->cache_control('max-age=21600, must-revalidate');
	});
	$app->hook(after_dispatch => sub {
		my $c = shift;
		if ( $c->req->method ne 'GET' ) {
			$c->app->log->debug("automatically flushing cache");
			$memd->flush_all;
		}
		$memd->disconnect_all;
	});
	$app->helper(memcached => sub { $memd });
	$app->helper(memd => sub {
		my ($c, $name, $object) = @_;
		unless ( defined wantarray ) {
			$c->app->log->debug("explicitly flushing cache");
			$memd->flush_all;
			return;
		}
		if ( ref $name ) {
			$object = $name;
			$name = undef;
		}
		my $username = ref $conf->{username} eq 'CODE' ? $conf->{username}->($c) : '';
		$name = join '#', ($username||''), ($c->stash('controller')||''), ($c->stash('action')||''), ($name||'');
		if ( $object ) {
			$c->app->log->debug("storing in cache for $name");
			local $_ = $memd->set($name => $object => $conf->{expires} || $c->config->{cache}->{expires} || 30);
			return $object;
		} else {
			if ( $object = $memd->get($name) ) {
				$c->app->log->debug("serving from cache for $name");
				$c->stash('memd.cached' => 1);
				return $object;
			}
		}
		return undef;
	});
}

1;

=head1 NAME

Mojolicious::Plugin::MergedParams - Access request as MergedParams

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('MergedParams');

  # Mojolicious::Lite
  plugin 'MergedParams';

=head1 DESCRIPTION

L<Mojolicious::Plugin::MergedParams> accesses request as MergedParams for L<Mojolicious>.

=head1 HELPERS

L<Mojolicious::Plugin::MergedParams> implements the following helpers.

=head2 json

  %= json 'foo'

=head1 METHODS

L<Mojolicious::Plugin::MergedParams> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register helpers in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut

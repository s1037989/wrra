package Mojolicious::Plugin::Profiler;
use Mojo::Base 'Mojolicious::Plugin';

use DateTime::HiRes;

sub register {
	my ($self, $app, $conf) = @_;

	$app->helper(profiler => sub {
		my $c = shift;
		$self->{profiler} = DateTime::HiRes->now unless $self->{profiler};
		my $p = delete $self->{profiler};
		$p = DateTime::HiRes->now->hires_epoch - $p->hires_epoch;
		$app->log->info("Profiler: $p");
	});
	$app->helper(profiler_start => sub {
		my $c = shift;
		if ( my $name = shift ) {
			$self->{profiler_named}->{$name} = DateTime::HiRes->now;
		} else {
			push @{$self->{profiler_stack}}, DateTime::HiRes->now;
		}
	});
	$app->helper(profiler_stop => sub {
		my $c = shift;
		my $name = shift;
		my $p;
		if ( $name ) {
			$p = delete $self->{profiler_named}->{$name};
		} else {
			$name = @{$self->{profiler_stack}} or return;
			$p = pop @{$self->{profiler_stack}};
		}
		$p = DateTime::HiRes->now->hires_epoch - $p->hires_epoch;
		$app->log->info("Profiler $name: $p");
	});
}

1;

=head1 NAME

Mojolicious::Plugin::Profiler - Access request as MyStash

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('MyStash');

  # Mojolicious::Lite
  plugin 'MyStash';

=head1 DESCRIPTION

L<Mojolicious::Plugin::MyStash> accesses request as MyStash for L<Mojolicious>.

=head1 HELPERS

L<Mojolicious::Plugin::MyStash> implements the following helpers.

=head2 json

  %= json 'foo'

=head1 METHODS

L<Mojolicious::Plugin::MyStash> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register helpers in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut

package ProxyManager::Example;
use Mojo::Base 'Mojolicious::Controller';
use MongoDB;
use MongoDB::OID;
use Locale::Country;

# This action will render a template
sub welcome {
	my $self = shift;

	# Get required country & default to UK
	my $reqcc = $self->param('cc') || 'gb';

	my $db  = $self->db;
	my $pxl = $db->proxy_list;

	# Fetch by country code, ordered by most recently checked
	my $prox = $pxl->find({ 'ccode' => $reqcc, '$or' => [{ status => 'new' }, { status => 'live' }] })->sort({ 'last_checked' => -1 });
	
	# AoH
	my @prox_list;

	while (my $doc  = $prox->next) {
		# form last checked object (may not exist)
		my $last_checked;
		if ($doc->{'last_checked'}) {
			my $lc = DateTime->from_epoch( epoch => $doc->{'last_checked'} );
			$last_checked = $lc->ymd . " " . $lc->hms;
		} else {
			$last_checked = 'N/A';
		}

		push(@prox_list, { 
			country => $doc->{'country'},
			ccode   => $doc->{'ccode'},
			status  => $doc->{'status'},
			ip		=> $doc->{'ip'},
			port 	=> $doc->{'port'},
			added   => DateTime->from_epoch( epoch => $doc->{'added'} ),
			last_checked   => $last_checked,
		});
	}

	# Render template "example/welcome.html.ep" with message
	$self->render(
		proxies => \@prox_list,
		reqcc   => $reqcc,
	);
}

sub add {
	my $self = shift;

	my $ip 		= $self->param('ip');
	my $port 	= $self->param('port');
	my $cc 		= $self->param('country');
	my $db 		= $self->db;
	my $pxl		= $db->proxy_list;

	$pxl->update({ ip => $ip, port => $port }, {
				'$set' => {
					ccode => $cc,
					country => code2country($cc),
					ip => $ip,
					port => $port,
					status => 'new',
					added => time(),
				}},
				{ upsert => 1 });

	$self->render( template => 'example#welcome' );
}

1;

#!/usr/bin/env perl

# Proxy Checker
# -------------
# This script is intended to be run hourly(ish) via crontab
# It will check all of the proxies listed for countries specified in
# the @country_codes array

use Modern::Perl;
use WWW::ProxyChecker;
use MongoDB;
use MongoDB::OID;
use Try::Tiny;

# init db
my $conn = MongoDB::Connection->new(host => 'localhost', port => 27017);
my $db   = $conn->proxies;
my $pxl  = $db->proxy_list;

# list the country codes we're going to check
my @country_codes = qw(gb us fr de it cn);

# loop through country codes
foreach my $cc (@country_codes) {
	check_proxies($cc);
}

sub check_proxies {
	my $cc = shift;
	# Select proxies ordered by longest time since last check
	my $prox = $pxl->find({ 'ccode' => $cc, '$or' => [{ status => 'new' }, { status => 'live' }] });#->sort({ 'last_checked' => 1 });

	# AoH
	my @prox_list;

	while (my $doc  = $prox->next) {
		my $proxy_ip   = $doc->{'ip'};
		my $proxy_port = $doc->{'port'};
		push(@prox_list, "http://$proxy_ip:$proxy_port");
	}

	my $checker = WWW::ProxyChecker->new( 
		debug => 1,
		timeout => 5,
		max_kids => 20,
		max_working_per_kid => 2,
		agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:18.0) Gecko/18.0 Firefox/18.0"
		);

	my $working_ref= $checker->check( \@prox_list );

	warn "No working proxies were found\n"
		if not @$working_ref;

	for my $p (@prox_list) {
		my $pr = split_ip($p);
		if ($p ~~ @$working_ref) {
			$pxl->update({ ip => @$pr[0], port => @$pr[1] }, {'$set' => {
				status => 'live',
				last_checked => time(),
				}});

		} else {
			$pxl->update({ ip => @$pr[0], port => @$pr[1] }, {'$set' => {
				status => 'fail',
				last_checked => time(),
				}});
		}
	}

}


sub split_ip {
	my $p = shift;
	my @p = $p =~ m!^https?://([0-9.]+):([0-9]+)$!;
	return \@p;
}
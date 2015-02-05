#!/usr/bin/perl -w

use lib '.';

use strict;

use Getopt::Std;
use Data::Dumper;
use YAML::XS;
use POSIX qw(strftime);
use URI::Encode qw(uri_encode uri_decode);

use Kinetic::Raise;
use Kinetic::Cloud;

use constant DEFAULT_CONFIG_FILE => './register.yml';
use constant DEFAULT_RULES_ENGINE => 'kibdev.kobj.net';
use constant REG_DOMAIN => "system";
use constant REG_TYPE => "new_ruleset_registration";
use constant DEL_TYPE => "delete_ruleset_registration";


# global options
use vars qw/ %clopt /;
my $opt_string = 'c:?hdr:u';
getopts( "$opt_string", \%clopt ) or usage();

usage() if $clopt{'h'} || $clopt{'?'};

print "No registration file specified. Using " . DEFAULT_CONFIG_FILE . "\n" unless $clopt{'c'};
my $config = read_config($clopt{'c'});
my $eci = $config->{'eci'};
my $server = $config->{'rules_engine'} || DEFAULT_RULES_ENGINE;
my $base_url = $config->{'base_url'};
my $passphrase = $config->{'passphrase'};
my $developer_eci = $config->{'developer_eci'};

my $event_domain = REG_DOMAIN;
my $event_type = $clopt{"d"} ? DEL_TYPE : REG_TYPE;

my $uri_encode = URI::Encode->new({double_encode => 0, encode_reserved => 1});

# find rulesets
my $rulesets = $config->{'rulesets'};

# just need the URL for flushing...
if ($clopt{"u"}) {
    my $flush_url = "http://$server/ruleset/flush/";
    my $flush_rids = [map { $_->{"rid"} . ".prod"   } @{ $rulesets }];
    print $flush_url . join(";", @{$flush_rids}), "\n";
    exit 
}

my $options ={'eci' =>  $eci,
	      'host' => $server,
	     };


my $event = Kinetic::Raise->new($event_domain,
				$event_type,
				$options
			       );

my $query = Kinetic::Cloud->new($config->{"query_domain"},
				"listRulesets",
				$eci,
				{"host" => $server}
			       );

my $already_registered = { map { $_ => 1 } @{$query->query({"developer_eci" => $developer_eci})} };
#print Dumper $already_registered;




foreach my $rline (@{ $rulesets }) {

    my $rid = $rline->{"rid"};

    if ( defined $clopt{"r"} 
      && $clopt{"r"} ne $rid
       ) {
	print "Skipping $rid cause it's not the specified RID\n";
	next
    }

    my $url = $rline->{"url"};
    unless ($url =~ m#^https?://#) {
	$url = $base_url . $url;
    }

    $url = $uri_encode->encode($url);
    print "$url\n";

    my $version = $rline->{"version"} || "prod";

    if ($clopt{'d'}) {
	$rid = $rid . "." . $version;
	if (! $already_registered->{$rid} ) {
	    print "Skipping $rid because it's not there \n";
	    next;
	} else {
	    print "Deleting $rid \n";
	}
    } else {
	# this is ugly cause right now Kynetx::Modules::RSM::do_create() only creates with .prod and only accepts
        # rids without any version attached. 
	my $vrid = $rid . "." . $version;
	if ($already_registered->{$vrid}) {
	    print "Skipping $rid because it's already registered \n";
	    next;
	} else {
	    print "Registering $rid at $url\n";
	}
	
    } 

    my $attrs = {"passphrase" => $passphrase,
		 "developer_eci" => $developer_eci,
		 "new_uri" => $url,
		 "new_rid" => $rid
		};

    my $eid = "REGISTRATION_".time;
    my $response = $event->raise($attrs, {"eid" => $eid, "esl" => 1});

    sleep 3;

}

1;

sub read_config {
    my ($filename) = @_;

    $filename ||= DEFAULT_CONFIG_FILE;

#    print "File ", $filename;
    my $config;
    if ( -e $filename ) {
      $config = YAML::XS::LoadFile($filename) ||
	warn "Can't open configuration file $filename: $!";
    }

    return $config;
}


#
# Message about this program and how to use it
#
sub usage {
    print STDERR << "EOF";

Ruleset registraion. 

Relies on having accompanying ruleset in the pico pointed to by ECI in configuration. 

usage: $0 [-h?] -c registratoin.yml

 -h|?      : this (help) message
 -c file   : configuration file
 -d        : delete ruleset(s) instead
 -r rid    : just this rid

example: $0 -c registration.yml 

EOF
    exit;
}

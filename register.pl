#!/usr/bin/perl -w

use lib '.';

use strict;

use Getopt::Std;
use Data::Dumper;
use YAML::XS;
use POSIX qw(strftime);
use Kinetic::Raise;
use Kinetic::Cloud;

use constant DEFAULT_CONFIG_FILE => './register.yml';
use constant DEFAULT_RULES_ENGINE => 'kibdev.kobj.net';
use constant REG_DOMAIN => "system";
use constant REG_TYPE => "new_ruleset_registration";
use constant DEL_TYPE => "delete_ruleset_registration";


# global options
use vars qw/ %clopt /;
my $opt_string = 'c:?hd';
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

# find rulesets
my $rulesets = $config->{'rulesets'};


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
				{"host" => "kibdev.kobj.net"}
			       );

my $already_registered = { map { $_ => 1 } @{$query->query({"developer_eci" => $developer_eci})} };
#print Dumper $already_registered;


foreach my $rline (@{ $rulesets }) {

    my $url = $rline->{"url"};
    unless ($url =~ m#^https?://#) {
	$url = $base_url . $url;
    }

    my $rid = $rline->{"rid"};

    my $version = $rline->{"version"} || "prod";
    $rid = $rid . "." . $version;

    if ($clopt{'d'}) {
	if (! $already_registered->{$rid} ) {
	    print "Skipping $rid because it's not there \n";
	    next;
	} else {
	    print "Deleting $rid \n";
	}
    } else {
	if ($already_registered->{$rid}) {
	    print "Skipping $rid because it's already registered \n";
	    next;
	} else {
	    print "Registering $rid at $url\n";
	}
	
    } 

    my $attrs = {"passphrase" => $passphrase,
		 "developer_eci" => $developer_eci,
		 "new_url" => $url,
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
 -d        : delete rulesets instead

example: $0 -c registration.yml 

EOF
    exit;
}

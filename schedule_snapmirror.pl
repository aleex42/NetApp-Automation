#!/usr/bin/perl

# --
# schedule_snapmirror.pl - Reschedule all snapmirror to new cron schedules 
# https://github.com/aleex42/NetApp-Automation
# Copyright (C) 2014 Alexander Krogloth, E-Mail: git <at> krogloth.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

use strict;
use warnings;
use feature qw/switch/;

# specify new crons, i.e. "daily_0:10, daily_6:10, ..."
my $new_cron = "^daily_";

unless($ARGV[0]){
    print "ERROR: no cluster specified\n";
    print "Usage: ./schedule_snapmirror.pl CLUSTER\n";
    die;
} 

my $cluster = $ARGV[0];

my @matching_crons = `ssh admin\@$cluster "cron show -fields name" | grep "$new_cron"`;
my %crons;

foreach my $cron (@matching_crons){
        $cron =~ s/\s+\z//;
        $crons{$cron} = "0";
}
my @vservers = `ssh admin\@$cluster "snapmirror show -fields schedule" | grep -vE '([0-9]* entries|^source-path|^-------)' | grep ^[a-z] | awk '{ print \$3 }'`;

foreach my $sched (@vservers){
	$sched =~ s/\s+\z//;
	if($sched =~ m/^daily_/){
		$crons{$sched}++;
	}
}

my @snap_destinations = `ssh admin\@$cluster "snapmirror show -fields destination-path" | grep -vE '([0-9]* entries|^source-path|^-------)' | grep ^[a-z] | awk '{ print \$2 }'`;

foreach my $snap (@snap_destinations){
	$snap =~ s/\s+\z//;
	my $new_cron = show_emptiest_cron();
	`ssh admin\@$cluster "snapmirror modify -destination-path $snap -schedule $new_cron"`;
	$crons{$new_cron}++;
}

sub show_emptiest_cron {
	my @cron_keys = sort { $crons{$a} <=> $crons{$b} } keys(%crons);
	return $cron_keys[0];
}

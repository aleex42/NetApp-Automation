#!/usr/bin/perl

use strict;
use warnings;

use lib "/usr/lib/netapp-manageability-sdk/lib/perl/NetApp";
use NaServer;
use NaElement;
use Data::Dumper;

my $hostname "filer1.example.com";
my $username = "admin";
my $password = "password";

my $s = new NaServer($hostname, 1 , 21);
$s->set_server_type('FILER');
$s->set_transport_type('HTTPS');
$s->set_port(443);
$s->set_style('LOGIN');
$s->set_admin_user($username, $password);

my $api = new NaElement('snapmirror-get-iter');

my $xi = new NaElement('desired-attributes');
$api->child_add($xi);

my $xi1 = new NaElement('snapmirror-info');
$xi->child_add($xi1);

$xi1->child_add_string('destination-volume','<destination-volume>');
$xi1->child_add_string('destination-vserver','<destination-vserver>');
$xi1->child_add_string('source-volume','<source-volume>');
$xi1->child_add_string('source-vserver','<source-vserver>');

my $tag_elem = NaElement->new("tag");
$api->child_add($tag_elem);

my $out = $s->invoke_elem($api);

my $next = "";

my @snapmirror;

while(defined($next)){
    unless($next eq ""){
        $tag_elem->set_content($next);
    }

    $api->child_add_string("max-records", 100);
    my $snap_output = $s->invoke_elem($api);

    my $num_records = $snap_output->child_get_string("num-records");

    if($num_records eq 0){
        last;
    }

    my @snapmirrors = $snap_output->child_get("attributes-list")->children_get();

    foreach my $snap (@snapmirrors){

        push(@snapmirror, {
            'destination-volume' => $snap->child_get_string('destination-volume'),
            'destination-vserver' => $snap->child_get_string('destination-vserver'),
            'source-vserver' => $snap->child_get_string('source-vserver'),
            'source-volume' => $snap->child_get_string('source-volume'),
        });

    }

    $next = $snap_output->child_get_string("next-tag");

}

my $count = 0;
my $schedule;

foreach my $snapmirror (@snapmirror){

    my $source_volume = $snapmirror->{'source-volume'};
    my $source_vserver = $snapmirror->{'source-vserver'};
    my $destination_volume = $snapmirror->{'destination-volume'};
    my $destination_vserver = $snapmirror->{'destination-vserver'};

    my $modulo = $count % 4;

    if($modulo == 0){
        $schedule = "hourly.0";
    } elsif($modulo == 1){
        $schedule = "hourly.15";
    } elsif($modulo == 2){
        $schedule = "hourly.30";
    } elsif($modulo == 3){
        $schedule = "hourly.45";
    }

    my $modify_api = new NaElement('snapmirror-modify');
    $modify_api->child_add_string('destination-volume',$destination_volume);
    $modify_api->child_add_string('destination-vserver',$destination_vserver);
    $modify_api->child_add_string('schedule',$schedule);
    $modify_api->child_add_string('source-volume',$source_volume);
    $modify_api->child_add_string('source-vserver',$source_vserver);

    my $modify_output = $s->invoke_elem($modify_api);

    print Dumper($modify_output);

    $count++;

}

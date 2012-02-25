#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use lib '../../Net-CLI-Interact/lib';
use lib '../lib';

use Net::Appliance::Session;
use Cwd;

my $s = Net::Appliance::Session->new({
    personality => 'ios',
    transport => 'Telnet',
    ($^O eq 'MSWin32' ?
        (app => '..\..\..\..\Desktop\plink.exe') : () ),
    host => '192.168.0.55',
    add_library => getcwd(),
});
$s->set_global_log_at('debug');

eval {
    $s->connect({ username => 'cisco', password => 'readynas01' });
    $s->begin_privileged;
    # print join "\n", $s->cmd('sh arp');
    $s->macro('run_to_flash', { params => ['foo'] });
};

$s->close;

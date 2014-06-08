#!/usr/bin/env perl

use strict;
use warnings;

local $ENV{PATH} = '/bin';

my @cmd = qw(df -BM);
open my $fs, '-|', @cmd or die "could not list filesystems\n";

while (<$fs>){
    chomp;
    #get all mount points and available space
    my ($space, $mount) = /^\/dev\/\S+\s+\S+\s+\S+\s+(\d+)M\s+\S+\s+(\S+)$/ or next;
    @cmd = (qw(/bin/dd if=/dev/zero), "of=$mount/.zero.small", qw(bs=1M count=100));
    system(@cmd);
    system('sync');
    @cmd = (qw(/bin/dd if=/dev/zero), "of=$mount/.zero.big", 'bs=1M', 'count=' . ($space - 110));
    system(@cmd);
    system('sync');
    unlink("$mount/.zero.small");
    sleep(10);
    unlink("$mount/.zero.big");
}

1;


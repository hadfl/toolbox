#!/usr/bin/env perl

use strict;
use warnings;

use JSON::PP;
use File::Basename qw(dirname);

my %cfg = (
    path       => '/home/mattermost/mattermost',
    user       => 'mattermost',
    service    => 'mattermost',
    enterprise => 0,
    systemd    => 1,
);

sub getMattermostVersion {
    chdir "$cfg{path}/bin" or die "ERROR: cannot cd to mattermost binary directory.\n";

    my @cmd = (qw(/usr/bin/sudo -u), $cfg{user}, "./platform", 'version');
    open my $matter, '-|', @cmd or die "ERROR: cannot execute mattermost.\n";

    while (<$matter>) {
        /^Build\s+Number:\s+(\d+\.\d+\.\d+)/ and return $1;
    }
    return undef;
}

sub startStopMattermost {
    my $method = shift;

    $method =~ /^(?:start|stop)$/ or die "ERROR: method '$method' is not valid.\n";

    if ($cfg{systemd}) {
        my @cmd = (qw(/usr/bin/sudo /bin/systemctl), $method, $cfg{service});
        system (@cmd) && die "ERROR: cannot $method '$cfg{service}.\n";
    }
    else {
        my @cmd = ('/usr/bin/sudo', "/etc/init.d/$cfg{service}", $method);
        system (@cmd) && die "ERROR: cannot $method '$cfg{service}.\n";
    }
}

$#ARGV == 0 or die "usage: $0 version\n";
my $version = $ARGV[0];

print "checking installed version...\n";
my $instVersion = getMattermostVersion() or die "ERROR: cannot get mattermost version.\n";
print "installed version is: $version\n";

$instVersion eq $version and die "ERROR: installed version matches requested upgrade version. exiting...\n";

print "reading mattermost config...\n";

open my $fh, '<', "$cfg{path}/config/config.json" or die "ERROR: cannot open mattermost config file: $!\n";
my $configJSON = JSON::PP->new->decode( do { local $/; <$fh>; } );
close $fh;

print "checking data directory...\n";
my $dataDir = $configJSON->{FileSettings}->{Directory};
$dataDir or die "ERROR: mattermost data directory not specified in configuration file.\n";

$dataDir =~ /^$cfg{path}/ and die 'ERROR: data dir is a subdirectory of mattermost install dir and ' . 
    "would be overwritten on upgrade. exiting...\n";

print "extracting download dir...\n";
my ($dldir) = dirname($cfg{path});

print "downloading mattermost...\n";
my $filename = 'mattermost-' . ($cfg{enterprise} ? '' : 'team-') . "$version-linux-amd64.tar.gz";
my @cmd = (qw(/usr/bin/sudo -u), $cfg{user}, qw(/usr/bin/curl -o), "$dldir/$filename", "https://releases.mattermost.com/$version/$filename");

system (@cmd) && die "ERROR: cannot download mattermost version $version.\n";

print "copying config backup to '/tmp/config.json'...\n";
@cmd = (qw(/usr/bin/sudo -u), $cfg{user}, '/bin/cp', "$cfg{path}/config/config.json", '/tmp/config.json');
system (@cmd) && die "ERROR: could not backup 'config.json'.\n";

print "shutting down mattermost...\n";
startStopMattermost('stop');

print "extracting new files...\n";
@cmd = (qw(/usr/bin/sudo -u), $cfg{user}, qw(/bin/tar xfz), "$dldir/$filename", '-C', $dldir);
system (@cmd) && die "ERROR: cannot extract new files.\n";

print "deleting upgrade archive...\n";
@cmd = (qw(/usr/bin/sudo /bin/rm), "$dldir/$filename");
system (@cmd);

print "restoring mattermost config...\n";
@cmd = (qw(/usr/bin/sudo -u), $cfg{user}, qw(/bin/cp /tmp/config.json), "$cfg{path}/config/config.json");
system (@cmd) && die "ERROR: cannot restore config.json.\n";

print "deleting backup config.json...\n";
@cmd = qw(/usr/bin/sudo /bin/rm /tmp/config.json);
system (@cmd) && die "ERROR: cannot delete '/tmp/config.json'.\n";

print "checking new version...\n";
$instVersion = getMattermostVersion() or die "ERROR: cannot get mattermost version.\n";
print "installed version is: $version\n";

print "starting mattermost...\n";
startStopMattermost('start');

1;


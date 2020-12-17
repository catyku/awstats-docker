#!/usr/bin/perl

use strict;
use warnings;

sub env_default {
    return defined $ENV{$_[0]} ? $ENV{$_[0]} : $_[1];
}

sub aw_re_ip {
    my $re = '';
    foreach my $r (@_) {
        $re = $re . "REGEX[$r] "
    }
    return "$re"
}

my $log_files = join(' ', @ARGV);
chomp($log_files);
my $log_format = env_default('LOG_FORMAT', '');
my $site_domain = env_default('SITE_DOMAIN', 'localhost');
my $skip_user_agents = env_default('SKIP_USER_AGENTS', 'Travis Hudson');
my $html_file = env_default('HTML_FILE', '/tmp/data/index.html');

my @skip_hosts_re = ();
if (defined $ENV{'SKIP_HOSTS'}) {
    unless ($ENV{'SKIP_HOSTS'} =~ /^\s*$/) {
        @skip_hosts_re = split / /, $ENV{'SKIP_HOSTS'};
    }
}
else {
    @skip_hosts_re = (
        '^127\.',

        '^192\.168\.',
        '^172\.(1[6-9]|2[0-9]|3[01])\.',
        '^10\.',

        
    );
}


if (defined $ENV{'SKIP_HOSTS_ADDITIONAL'}) {
    unless ($ENV{'SKIP_HOSTS_ADDITIONAL'} =~ /^\s*$/) {
        my @skip_hosts_re_additional = split / /, $ENV{'SKIP_HOSTS_ADDITIONAL'};
        @skip_hosts_re = (@skip_hosts_re, @skip_hosts_re_additional);
    }
}

my $filein = "/etc/awstats/awstats.model.conf";
my $fileout = "/etc/awstats/awstats.$site_domain.conf";

if (-e $fileout) {
    print "Configuration already exists: $fileout\n";
}
else {
    print "Creating configuration $fileout\n";
    open(my $IN, $filein) or die "Failed to open $filein for reading";
    open(my $OUT, '>', $fileout) or die "Failed to open $fileout for writing";;

    while (<$IN>) {
        if (/^LogFile=/) {
            print $OUT "LogFile=/dev/null\n";
        }
        elsif ($log_format && /^LogFormat=/) {
            print $OUT "LogFormat = $log_format\n";
        }
        elsif (/^SiteDomain=/) {
            print $OUT "SiteDomain=\"$site_domain\"\n";
        }
        elsif (/^AllowFullYearView=/) {
            print $OUT "AllowFullYearView=3\n";
        }
        elsif (/^BuildReportFormat=/) {
            print $OUT "BuildReportFormat=xhtml\n";
        }
        elsif (/^Expires=/) {
            print $OUT "Expires=3600\n";
        }
        elsif (/^FirstDayOfWeek=/) {
            print $OUT "FirstDayOfWeek=1\n";
        }
        elsif (/^SkipHosts=/) {
            print $OUT "SkipHosts=\"" . aw_re_ip(@skip_hosts_re) . "\"\n";
        }
        elsif (/^SkipUserAgents=/) {
            print $OUT "SkipUserAgents=\"$skip_user_agents\"\n";
        }
        # AllowToUpdateStatsFromBrowser=1
        else {
            print $OUT $_;
        }
    }

    print $OUT "LoadPlugin=\"geoip GEOIP_STANDARD /opt/GeoIP/GeoIP.dat\"\n";
    print $OUT "LoadPlugin=\"geoip_city_maxmind GEOIP_STANDARD /opt/GeoIP/GeoLiteCity.dat\"\n";
}


if ($log_files eq 'httpd') {
    print "Starting httpd awstats\n";
    exec "/usr/sbin/httpd", "-DFOREGROUND";
}
else 
if ($log_files eq 'output') {
    print "Starting output awstats html \n";
     my @args = (
        "/usr/share/awstats/wwwroot/cgi-bin/awstats.pl",
        "-config=$site_domain",
        "-update",
        "-output",
        "-staticlinks",
        ">",
        "$html_file"
        
    );
    print "@args \n";
    exec @args;
}
else {
    print "Updating log statistics\n";
    # See /usr/share/awstats/wwwroot/cgi-bin/awstats.pl --help
    my @args = (
        "/usr/share/awstats/wwwroot/cgi-bin/awstats.pl",
        "-config=$site_domain",
        "-update",
        "-showsteps",
        "-showcorrupted",
        "-showdropped",
        "-showunknownorigin"
    );
    if ($log_files) {
        # If using an external configuration file it may define LogFile
        push @args, "-LogFile=/usr/share/awstats/tools/logresolvemerge.pl $log_files |"
    }
    else {
        print "No logfiles on command line, using LogFile from $site_domain configuration file \n"
    }
    exec @args;
}

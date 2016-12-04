#!/usr/bin/perl 
use strict;
use warnings;

use XML::Feed;
use LWP::UserAgent;
use Data::Dumper;
use File::Spec;
use File::Path qw(make_path);
use DateTime;
use DateTime::Format::Strptime;
use utf8;

# You may change these values START

# URL to the Shaarli RSS Feed, optionally with searchtag, ...
my $blogurl = "https://delicious.leyrer.priv.at/?do=rss&searchtags=publish";

# Folder in which to create directories and content files
my $destfolder = "/home/leyrer/Priv-Homepage/test-gen";

# files should start with this string (followed by date string and '.txt')
my $fileprefix = "shaarli-";

# headline string for one link entry
my $headlinestring = "h4";

# Headlines start with this string
my $subjectprefix = "Links from ";

# Turn debugging on/off
my $DEBUG = 1;

# You may change these values END



# Lets have a "nice" user agent string
my $ua = LWP::UserAgent->new (
	agent => "shaarli2blog"
);
$ua->ssl_opts( 
	verify_hostname => 1
);


print "Fetching " . $blogurl . " ...\n" if($DEBUG);
my $response = $ua->get($blogurl);
die "Error at " . $blogurl . "\n" . $response->status_line . "\n Aborting." unless $response->is_success;

my $raw_content = $response->decoded_content;
my $feed = XML::Feed->parse(\$raw_content);

my $entries;

# Build hash with ready-built strings for each day
foreach my $item ($feed->entries) {
	$entries->{substr($item->issued, 0, 10)} = entry2string($item);
}


# What to generate ...

if( defined($ARGV[3]) ) {	# Generate link entries from date "from" to date "to"
	my $from = DateTime->new(
			year       => $ARGV[0],
			month      => $ARGV[1],
			day        => $ARGV[2],
			hour       => 5,
			minute     => 0,
			second     => 0,
			time_zone  => 'local',
	);
	my $current = $from->clone();
	my $to = DateTime->new(
			year       => $ARGV[3],
			month      => $ARGV[4],
			day        => $ARGV[5],
			hour       => 5,
			minute     => 0,
			second     => 0,
			time_zone  => 'local',
	);

	print "checking date range for URLs ...\n" if ($DEBUG);
	do {
		my $filedate = sprintf( "%4.4d-%2.2d-%2.2d", $current->year, $current->month, $current->day);
		if( exists $entries->{$filedate} ) {
			my $dt_touch = $current->epoch() + 60 * 60 * 24; # timestamp for next day
			print "Creating file for day: $filedate, $dt_touch\n" if($DEBUG);
			&writeFile($filedate, $entries->{$filedate}, $dt_touch);
		} else {
			print "Skipping $filedate ...\n" if($DEBUG);
		}
		$current->add( days => 1 );
	} until ( $current->epoch() == $to->epoch() );

} elsif( defined($ARGV[2]) ) {	# create link entry for specific day
	my $filedate = $ARGV[0] . "-" . $ARGV[1] . "-" . $ARGV[2];

	if( exists $entries->{$filedate} ) {
		my $dt = DateTime->new(
				year       => $ARGV[0],
				month      => $ARGV[1],
				day        => $ARGV[2],
				hour       => 5,
				minute     => 0,
				second     => 0,
				time_zone  => 'local',
		);
		my $dt_touch = $dt->epoch() + 60 * 60 * 24; # timestamp for next day
		print "Creating single file for day: $filedate, $dt_touch\n";
		&writeFile($filedate, $entries->{$filedate}, $dt_touch);
	} else {
		print "No entries for specified date $filedate ...\n" if($DEBUG);
	}
} else {	# create link entry for yesterday
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(yesterday());
	my $filedatum = sprintf("%4.4d-%2.2d-%2.2d", 1900+$year, $mon+1, $mday);

	if( exists $entries->{$filedatum} ) {
		# Set timestamp of blogentry to today, 5am
	    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		my $today = sprintf("%4.4d-%2.2d-%2.2d", 1900+$year, $mon+1, $mday);
		my $file_timestamp = fiveOclock($today);
		&writeFile($filedatum, $entries->{$filedatum}, $file_timestamp);
	} else {
		print "No entries for date $filedatum ...\n" if($DEBUG);
	}
}

exit;


exit;

sub fiveOclock {
	my ($str) = @_;

	$str .= " 05:00";
	print "STR: $str\n" if($DEBUG);
	my $parser = DateTime::Format::Strptime->new(	pattern => '%Y-%m-%d %H:%M',
					                                locale      => 'de_AT',
										            time_zone   => 'Europe/Vienna',
												);
	my $dt = $parser->parse_datetime( $str );
	return $dt->epoch;
}

sub yesterday { 
	# Borrowed from perlfaq4; note changes below.
	my $now  = defined $_[0] ? $_[0] : time;
	my $then = $now - 60 * 60 * 24;
	my $ndst = (localtime $now)[8] > 0;
	my $tdst = (localtime $then)[8] > 0;
	
	# Added '=' to avoid warning (and return)
	$then -= ($tdst - $ndst) * 60 * 60;
	return($then);
}

sub writeFile {
	my ($fdate, $content, $timestamp) = @_;
	my @folders;
	push(@folders, $destfolder);
	push(@folders, "y" . substr($fdate, 0, 4));
	push(@folders, "m" . substr($fdate, 5, 2));

	my $fn = File::Spec->catfile( @folders, $fileprefix . $fdate . ".txt");
	print "Working on file $fn ...\n" if ($DEBUG);

	my $d = File::Spec->catdir(@folders);
	if(not -d $d) {
		make_path($d) or die "Error creating folder $d.\n$!\n";
	}

	open(TXT, ">$fn") or die "Write error for file '$fn'. $!\n";
	binmode(TXT, ":utf8");
	print TXT << "__UND_AUS__";
$subjectprefix$fdate
meta-Author: <a rel="author" href="/static/about-me.html">Martin Leyrer</a>
Tags: links, delicious, shaarli, collection

__UND_AUS__
	print TXT "$content\n";
	close(TXT);
	
	# Properly timestamp the file
	print "Timestamping file $fn for $timestamp ...\n" if ($DEBUG);
	my $utimeerg= utime ( $timestamp, $timestamp, $fn);
}

sub entry2string {
	my ($entry) = @_;
	my $ret = '';
	my $e = &cleanupString($entry->title);
	my $c = $entry->content;
	my $body = $c->body;
	$body =~ s/(<br>\&#8212; <a href=\"https:\/\/delicious\.leyrer.*)$//m;
	chomp $body;

	$ret .= "<$headlinestring><a href=\"" . $entry->link . '" title="' . $e . '">' . $e . "</a></$headlinestring>\n";
	$ret .= '<p>' . $body . "</p>\n";
		
	return($ret);
}

sub cleanupString {
	my ($text) = @_;
	my $ret = $text;
	$ret =~ s/\"/\&quote;/gi;
	return($ret);
}


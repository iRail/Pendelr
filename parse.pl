#!/usr/bin/perl

################################################################################
# Configuration
#

use strict;
use warnings;

use Data::Dumper;

use Text::CSV_XS;
my $csv = Text::CSV_XS->new({
	binary			=> 1,
	sep_char		=> ';',
	allow_loose_quotes	=> 1		# DeLijn CSV sucks
}) or die "Cannot use CSV: ".Text::CSV->error_diag();

my $window_start = 12;
my $window_stop = 18;


################################################################################
# Main
#

#
# Stops
#

print "* Loading stops\n";
my %stops;

open(my $data_stops, '<', 'data/stops.csv') or die('Could not open stops datafile');
while (my $data_stop = $csv->getline($data_stops)) {
	next unless ($data_stop->[0] =~ m{^\d+$});
	
	my $stop_id = $data_stop->[0];
	my $stop = {
		description	=> $data_stop->[2],
		"x"		=> $data_stop->[6],
		"y"		=> $data_stop->[7],
	};
	
	$stops{$stop_id} = $stop;
}
close($data_stops);


#
# Routes
#

print "* Loading routes\n";
my %routes;

open(my $data_routes, '<', 'data/routes.csv') or die('Could not open routes datafile');
while (my $data_route = $csv->getline($data_routes)) {
	next unless ($data_route->[0] =~ m{^\d+$});
	
	my $route_id = $data_route->[0];
	my $route = {
		description	=> $data_route->[2],
		public_id	=> $data_route->[3],
		service_mode	=> $data_route->[6]
	};
	$routes{$route_id} = $route;
}
close($data_routes);


#
# Trips
#

print "* Loading trips\n";
my %trips;

open(my $data_trips, '<', 'data/trips.csv') or die('Could not open trips datafile');
while (my $data_trip = $csv->getline($data_trips)) {
	next unless ($data_trip->[0] =~ m{^\d+$});
	$trips{$data_trip->[0]} = {
		route	=> $data_trip->[1]
	};
}
close($data_trips);


###

#my %routes_ghent;
#
#open(my $data_segments, '<', 'data/segments.csv') or die('Could not open segments datafile');
#while (my $data_segment = $csv->getline($data_segments)) {
#	next unless ($data_segment->[0] =~ m{^\d+$});	
#	my ($segment, $trip_id, $stop_id, $sequence, $start, $end) = @$data_segment;
#	next unless ($start);
#	
#	# Lookup route id
#	my $trip = $trips{$trip_id};
#	if (not defined($trip)) {
#		print "! Could not find trip $trip\n";
#		next;
#	}
#	my $route_id = $trip->{route};
#	
#	my $relevant = 0;
#	if (defined $stops_ghent{$stop_id}) {
#		$relevant = 1;
#		$routes_ghent{$route_id} = 1;
#	} elsif (defined $routes_ghent{$route_id}) {
#		$relevant = 1;
#	}
#	
#	if ($relevant) {
#		print join(';', @$data_segment), "\n";
#	}
#}

###


#
# Route times
#

print "* Loading route times\n";
my %route_times;
my %stops_ghent;

open(my $data_segments, '<', 'data/segments_ghent2.csv') or die('Could not open segments datafile');
while (my $data_segment = $csv->getline($data_segments)) {
	next unless ($data_segment->[0] =~ m{^\d+$});	
	
	my ($segment, $trip_id, $stop_id, $sequence, $start, $end) = @$data_segment;
	next unless ($start);
	
	# hack, should happen at pre processing
	$stops_ghent{$stop_id} = $stops{$stop_id};
	if (not defined $stops{$stop_id}) {
		print "! Warning, could not find information for stop $stop_id\n";
	}
	
	# Lookup route id
	my $trip = $trips{$trip_id};
	if (not defined($trip)) {
		print "! Could not find trip $trip\n";
		next;
	}
	my $route_id = $trip->{route};
	
	my ($start_hour, $start_minutes) = split(/:/, $start);
	my $time = $start_hour * 60 + $start_minutes;
	
	if ( $sequence == 1) {
		$route_times{$route_id} = [ [$stop_id, $time] ];
	} elsif (defined $route_times{$route_id} && $sequence > scalar @{$route_times{$route_id}}) {
		push @{$route_times{$route_id}}, [$stop_id, $time];
	}
	
	# First of a sequence
#	if ($sequence == 1) {
#		# Only process if first of an entry
#		if (not defined $route_times{$route_id} && not defined $route_done{$route_id}) {
#			next unless($start_hour > $window_start && $start_hour < $window_stop);			
#			$route_times{$route_id} = [$stop_id, $time];
#			print "Start of line $route_id at " . $start . "\n";
#		} else {
#			delete $route_times{$route_id};
#			$route_done{$route_id} = 1;
#		}
#	}
#	# Continuation of a sequence: only process if sequence=1 was defined
#	elsif (defined $route_times{$route_id}) {
#		my ($stop_prev, $time_prev) = @{$route_times{$route_id}};
#		print $output_segments join(";", $stop_id, $stop_prev, $time - $time_prev, $route_id), "\n";
#		print "Stop $sequence (id $stop_id) at $start, distance of " . ($time - $time_prev) . "\n";
#		$route_times{$route_id} = [$stop_id, $time];
#		
#	}
}
close($data_segments);


#
# Output stops
#

print "* Writing stops \n";

open(my $output_stops, '>', 'output/stops.csv');
foreach my $stop_id (keys %stops_ghent) {
	my $stop = $stops_ghent{$stop_id};
	
	print $output_stops join(';', ($stop_id, $stop->{description}, $stop->{'x'}, $stop->{'y'})), "\n";
}
close($output_stops);


#
# Output routes
#

print "* Writing routes\n";

open(my $output_routes, '>', 'output/routes.csv');
foreach my $route_id (keys %route_times) {	
	my $route = $routes{$route_id};
	print $output_routes join(';', $route_id, $route->{description}, $route->{public_id}, $route->{service_mode}), "\n";
}
close($output_routes);


#
# Output connections
#

print "* Writing connections\n";

open(my $output_connections, '>', 'output/connections.csv');
foreach my $route_id (keys %route_times) {
	my @times = @{$route_times{$route_id}};
	my ($minutes_prev, $stop_id_prev);
	foreach my $time (@times) {
		my ($stop_id, $minutes) = @{$time};
		if (defined $minutes_prev) {
			print $output_connections join(";", $stop_id_prev, $stop_id, $minutes - $minutes_prev, $route_id), "\n";
		}
		$minutes_prev = $minutes;
		$stop_id_prev = $stop_id;
	}
}
close($output_connections);

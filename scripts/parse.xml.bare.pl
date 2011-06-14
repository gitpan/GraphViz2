#!/usr/bin/env perl
#
# Note: t/test.t searches for the next line.
# Annotation: Demonstrates using XML::Bare to parse XML.

use strict;
use warnings;

use File::Spec;

use GraphViz2;
use GraphViz2::Data::Grapher;

use Perl6::Slurp;

use Log::Handler;

use XML::Bare;

# ------------------------------------------------

my($logger) = Log::Handler -> new;

$logger -> add
	(
	 screen =>
	 {
		 maxlevel       => 'debug',
		 message_layout => '%m',
		 minlevel       => 'error',
	 }
	);

my($graph) = GraphViz2 -> new
	(
	 edge   => {color => 'grey'},
	 global => {directed => 1},
	 graph  => {rankdir => 'TB', label => "Graph produced by GraphViz2::Data::Grapher's $0"},
	 logger => $logger,
	 node   => {color => 'darkblue', shape => 'oval'},
	);
my $xml   = slurp(File::Spec -> catfile('t', 'sample.xml'), {chomp => 1});
my($g)    = GraphViz2::Data::Grapher -> new(graph => $graph);
my($bare) = XML::Bare -> new(text => $xml) -> simple;
my(@key)  = sort keys %$bare;

$g -> create(name => $key[0], thing => $$bare{$key[0]});

my($format)      = shift || 'svg';
my($output_file) = shift || File::Spec -> catfile('html', "parse.xml.bare.$format");

$graph -> run(format => $format, output_file => $output_file, timeout => 11);

#!/usr/bin/env perl
#
# Note: t/test.t searches for the next line.
# Annotation: Demonstrates graphing a Parse::RecDescent-style grammar.

use strict;
use warnings;

use File::Spec;

use GraphViz2;
use GraphViz2::Parse::RecDescent;

use Log::Handler;

use Parse::RecDescent;

use Perl6::Slurp;

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
my($g)      = GraphViz2::Parse::RecDescent -> new(graph => $graph);
my $grammar = slurp(File::Spec -> catfile('t', 'sample.recdescent.1.dat') );
my($parser) = Parse::RecDescent -> new($grammar);

$g -> create(name => 'Grammar', grammar => $parser);

my($format)      = shift || 'svg';
my($output_file) = shift || File::Spec -> catfile('html', "parse.recdescent.$format");

$graph -> run(format => $format, output_file => $output_file, timeout => 11);

#!/usr/bin/env perl
#
# Note: t/test.t searches for the next line.
# Annotation: Demonstrates graphing an Algorithm::Dependency object.

use strict;
use warnings;

use Algorithm::Dependency;
use Algorithm::Dependency::Source::HoA;

use File::Spec;

use GraphViz2;

use Log::Handler;

# ---------------

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
	 graph  => {label => "Parent (Graph produced by GraphViz2::Data::Grapher's $0)", rankdir => 'BT'},
	 logger => $logger,
	 node   => {shape => 'oval'},
	);
my($data) =
{
	'Parent' => [],
	'Parent::Child1' => [qw/Parent/],
	'Parent::Child2' => [qw/Parent/],
	'Parent::Child::Grandchild' => [qw/Parent::Child1 Parent::Child2/],
};

$graph -> dependency(data => Algorithm::Dependency -> new(source => Algorithm::Dependency::Source::HoA -> new($data) ) );

my($format)      = shift || 'svg';
my($output_file) = shift || File::Spec -> catfile('html', "dependency.$format");

$graph -> run(format => $format, output_file => $output_file, timeout => 11);

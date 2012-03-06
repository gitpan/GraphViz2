#!/usr/bin/env perl
#
# Note: t/test.t searches for the next line.
# Annotation: Demonstrates utf8 chars in labels.

use strict;
use utf8;
use warnings;

use File::Spec;

use GraphViz2;

# ---------------

my($graph) = GraphViz2 -> new
	(
	 edge   => {color => 'grey'},
	 global => {directed => 1},
	 graph  => {label => '5 deltas, despite message:\nWide character in print...', rankdir => 'TB'},
	 node   => {shape => 'oval'},
	);

$graph -> add_node(name => '5 deltas',  label => 'ΔΔΔΔΔ');

my($format)      = shift || 'svg';
my($output_file) = shift || File::Spec -> catfile('html', "utf8.test.$format");

$graph -> run(format => $format, output_file => $output_file);

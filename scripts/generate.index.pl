#!/usr/bin/env perl

use strict;
use warnings;

use File::Spec;

use GraphViz2::Utils;

use Text::Xslate 'mark_raw';

# ------------------------------------------------

my(%annotation) = GraphViz2::Utils -> new -> get_annotations;
my(%svg_file)   = GraphViz2::Utils -> new -> get_svg_files;
my($templater)  = Text::Xslate -> new
(
  input_layer => '',
  path        => 'html',
);
my($count) = 0;
my($index) = $templater -> render
(
 'graphviz.index.tx',
 {
	 sample_list => mark_raw('<tr><td>' . (join(qq|</td></tr>\n<tr><td>|, map{$count++; qq|<a href="./$svg_file{$_}">$count: $annotation{$_}</a>|} sort keys %svg_file) ) . '</td></tr>'),
 }
);
my($file_name) = File::Spec -> catfile('html', 'graphviz.index.html');

open(OUT, '>', $file_name);
print OUT $index;
close OUT;

print "Wrote: $file_name. \n";

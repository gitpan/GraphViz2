use ExtUtils::MakeMaker;

use File::Which; # For which().

if (! which('dot') )
{
	die "Did not find 'dot'. Please install graphviz from http://www.graphviz.org/";
}

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile
(
 ($] ge '5.005') ?
 (
  AUTHOR   => 'Ron Savage (ron@savage.net.au)',
  ABSTRACT => "A wrapper for AT&T's Graphviz",
    ) : (),
 clean =>
 {
	 FILES => 'blib/* Makefile MANIFEST GraphViz2-*'
 },
 dist =>
 {
	 COMPRESS => 'gzip',
	 SUFFIX   => 'gz'
 },
 DISTNAME  => 'GraphViz2',
 NAME      => 'GraphViz2',
 PL_FILES  => {},
 PREREQ_PM =>
 {
	 Capture::Tiny               => 0.10,
	 Data::Section::Simple       => 0.02,
	 DBI                         => 1.616,
	 File::Basename              => 2.78,
	 File::Spec                  => 3.33,
	 File::Temp                  => 0.22,
	 File::Which                 => 1.09,
	 Hash::FieldHash             => 0.10,
	 HTML::Entities::Interpolate => 1.04,
	 HTML::TreeBuilder           => 4.2,
	 HTTP::Tiny                  => 0.012,
	 Parse::RecDescent           => 1.965001,
	 Perl6::Slurp                => 0.03,
	 Scalar::Util                => 1.23,
	 Set::Array                  => 0.23,
 	 Test::More                  => 0.94,
 	 Test::Pod                   => 1.44,
	 Text::Xslate                => 1.2000,
	 Tree::DAG_Node              => 1.06,
	 Try::Tiny                   => 0.09,
	 XML::Bare                   => 0.45,
	 XML::Tiny                   => 2.06,
 },
 VERSION_FROM => 'lib/GraphViz2.pm',
);
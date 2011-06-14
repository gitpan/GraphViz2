use File::Which; # For which().

use Module::Build;

if (! which('dot') )
{
	die "Did not find 'dot'. Please install graphviz from http://www.graphviz.org/";
}

Module::Build -> new
(
 module_name    => 'GraphViz2',
 license        => 'artistic',
 dist_abstract  => "A wrapper for AT&T's Graphviz",
 dist_author    => 'Ron Savage <ron@savage.net.au>',
 build_requires =>
 {
 	 Test::More => 0.94,
 	 Test::Pod  => 1.44,
 },
 configure_requires =>
 {
 	 Module::Build => 0.3800,
 },
 requires =>
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
	 Text::Xslate                => 1.2000,
	 Tree::DAG_Node              => 1.06,
	 Try::Tiny                   => 0.09,
	 XML::Bare                   => 0.45,
	 XML::Tiny                   => 2.06,
 },
) -> create_build_script();
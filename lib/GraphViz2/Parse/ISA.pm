package GraphViz2::Parse::ISA;

use parent 'Pod::Simple';
use strict;
use warnings;

use Algorithm::Dependency;
use Algorithm::Dependency::Source::HoA;

use GraphViz2;

our $VERSION = '1.02';

my(@candidate);
my($graph);
my(%ignore);
my(%parent);

# ------------------------------------------------

sub _add
{
	my($self, @module) = @_;

	my($file_name);
	my(@parent);

	for my $module (@module)
	{
		next if ($ignore{$module});

		($file_name = $module) =~ s|::|/|g;
		$file_name  .= '.pm';

		eval
		{
			require $file_name;
		};

		if ($@)
		{
			die "Error. Unable to require $file_name. $@";
		};

		@candidate = ();

		$self -> scanner($file_name);

		no strict 'refs';

		for my $candidate ($module, @candidate)
		{
			$parent{$candidate} = [];

			@parent = @{"$candidate\::ISA"};

			if (@parent >= 0)
			{
				for my $parent (@parent)
				{
					push @{$parent{$candidate} }, $parent if (! $ignore{$parent});
				}

				$self -> _add(@parent);
			}
		}
	}

} # End of _add.

# ------------------------------------------------

sub create
{
	my($self, %arg) = @_;
	my($class)  = delete $arg{class} || die 'Error. No class name specified';
	my($ignore) = delete $arg{ignore};

	if ($ignore)
	{
		if (ref $ignore ne 'ARRAY')
		{
			die "Error. The ignore parameter's value must be an arrayref";
		}

		@ignore{@$ignore} = (1) x @$ignore;
	}

	$self -> code_handler(\&scanner);
	$self -> _add($class);

	my(@parent);
	my($s1, $s2);

	for $class (sort keys %parent)
	{
		($s1 = $class) =~ s/::/_/g;
		$ignore{$class} = 1;
		@parent         = @{$parent{$class} };

		for my $parent (@parent)
		{
			next if ($ignore{$parent});

			($s1 = $parent) =~ s/::/_/g;
		}

		for my $parent (@parent)
		{
			($s1 = $class)  =~ s/::/_/g;
			($s2 = $parent) =~ s/::/_/g;
		}
	}

	$self -> graph -> dependency(data => Algorithm::Dependency -> new(source => Algorithm::Dependency::Source::HoA -> new(\%parent) ) );

	return $self;

} # End of create.

# ------------------------------------------------

sub graph
{
	my($self) = @_;

	return $graph;

} # End of graph.

# ------------------------------------------------

sub new
{
	my($class, %arg) = @_;
	$arg{graph}      ||= GraphViz2 -> new
		(
		 edge   => {color => 'grey'},
		 global => {directed => 1},
		 graph  => {rankdir => 'BT'},
		 logger => '',
		 node   => {color => 'darkblue', shape => 'Mrecord'},
		);
	$graph = delete $arg{graph};

	$class -> SUPER::new;

} # End of new.

# ------------------------------------------------
# This is a function.

sub scanner
{
	my($line, $line_count, $parser) = @_;

	push @candidate, $1 if ($line =~ /^package\s+(\w)/);

} # End of scanner.

# ------------------------------------------------

1;

=pod

=head1 NAME

L<GraphViz2::Parse::ISA> - Visualize a Perl class hierarchy as a graph

=head1 Synopsis

	#!/usr/bin/env perl
	
	use strict;
	use warnings;
	
	use File::Spec;
	
	use GraphViz2;
	use GraphViz2::Parse::ISA;
	
	use Log::Handler;
	
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
		 graph  => {rankdir => 'BT', label => "Graph produced by GraphViz2::Data::Grapher's $0"},
		 logger => $logger,
		 node   => {color => 'darkblue', shape => 'Mrecord'},
		);
	my($parser) = GraphViz2::Parse::ISA -> new(graph => $graph);
	
	$parser -> create(class => 'Parent::Child::Grandchild', ignore => []);
	
	my($format)      = shift || 'svg';
	my($output_file) = shift || File::Spec -> catfile('html', "parse.code.$format");
	
	$graph -> run(format => $format, output_file => $output_file, timeout => 11);

See scripts/parse.isa.pl (L<GraphViz2/Scripts Shipped with this Module>).

=head1 Description

Takes a class name and converts its class hierarchy into a graph.

You can write the result in any format supported by L<Graphviz|http://www.graphviz.org/>.

Here is the list of L<output formats|http://www.graphviz.org/content/output-formats>.

=head1 Distributions

This module is available as a Unix-style distro (*.tgz).

See L<http://savage.net.au/Perl-modules/html/installing-a-module.html>
for help on unpacking and installing distros.

=head1 Installation

Install L<GraphViz2> as you would for any C<Perl> module:

Run:

	cpanm GraphViz2

or run:

	sudo cpan GraphViz2

or unpack the distro, and then either:

	perl Build.PL
	./Build
	./Build test
	sudo ./Build install

or:

	perl Makefile.PL
	make (or dmake or nmake)
	make test
	make install

=head1 Constructor and Initialization

=head2 Calling new()

C<new()> is called as C<< my($obj) = GraphViz2::Parse::ISA -> new(k1 => v1, k2 => v2, ...) >>.

It returns a new object of type C<GraphViz2::Parse::ISA>.

Key-value pairs accepted in the parameter list:

=over 4

=item o graph => $graphviz_object

This option specifies the GraphViz2 object to use. This allows you to configure it as desired.

The default is GraphViz2 -> new. The default attributes are the same as in the synopsis, above,
except for the graph label of course.

This key is optional.

=back

=head1 Methods

=head2 create(class => $class, ignore => $arrayref)

Creates the graph, which is accessible via the graph() method, or via the graph object you passed to new().

The '::' in class names is replaced with '_' in the graph, because ':' has a special meaning for
L<Graphviz|http://www.graphviz.org/>. It is used to separate a node name from a port name.

Returns $self for method chaining.

$class is the name of the class whose parents are to be found.

$ignore is an arrayref of class names to ignore.

=head2 graph()

Returns the graph object, either the one supplied to new() or the one created during the call to new().

=head1 FAQ

See L<GraphViz2/FAQ> and L<GraphViz2/Scripts Shipped with this Module>.

=head1 Thanks

Many thanks are due to the people who chose to make L<Graphviz|http://www.graphviz.org/> Open Source.

And thanks to L<Leon Brocard|http://search.cpan.org/~lbrocard/>, who wrote L<GraphViz>, and kindly gave me co-maint of the module.

The code in add() was adapted from L<GraphViz::ISA::Multi> by Marcus Thiesen, but that code gobbled up package declarations
in comments and POD, so I used L<Pod::Simple> to give me just the source code.

=head1 Version Numbers

Version numbers < 1.00 represent development versions. From 1.00 up, they are production versions.

=head1 Machine-Readable Change Log

The file CHANGES was converted into Changelog.ini by L<Module::Metadata::Changes>.

=head1 Support

Email the author, or log a bug on RT:

L<https://rt.cpan.org/Public/Dist/Display.html?Name=GraphViz2>.

=head1 Author

L<GraphViz2> was written by Ron Savage I<E<lt>ron@savage.net.auE<gt>> in 2011.

Home page: L<http://savage.net.au/index.html>.

=head1 Copyright

Australian copyright (c) 2011, Ron Savage.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut

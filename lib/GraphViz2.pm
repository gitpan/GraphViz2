package GraphViz2;

use strict;
use warnings;

use Capture::Tiny 'capture';

use Data::Section::Simple 'get_data_section';

use File::Temp ();
use File::Which; # For which().

use Hash::FieldHash ':all';

use Set::Array;

use Try::Tiny;

fieldhash my %command          => 'command';
fieldhash my %dot_input        => 'dot_input';
fieldhash my %dot_output       => 'dot_output';
fieldhash my %edge             => 'edge';
fieldhash my %global           => 'global';
fieldhash my %graph            => 'graph';
fieldhash my %logger           => 'logger';
fieldhash my %node             => 'node';
fieldhash my %node_hash        => 'node_hash';
fieldhash my %scope            => 'scope';
fieldhash my %verbose          => 'verbose';
fieldhash my %valid_attributes => 'valid_attributes';

our $VERSION = '1.00';

# -----------------------------------------------

sub add_edge
{
	my($self, %arg) = @_;
	my($from)   = delete $arg{from};
	$from       = defined($from) ? $from : '';
	my($to)     = delete $arg{to};
	$to         = defined($to) ? $to : '';
	my($label)  = delete $arg{label};
	$arg{label} = defined($label) ? $label : '';

	$self -> validate_params('edge', %arg);

	# If either from or to is unknown, add a new node.

	my($new)  = 0;
	my($node) = $self -> node_hash;

	my($port, %port);

	for my $name ($from, $to)
	{
		# Remove port, if any, from name.

		if ($name =~ m/^([^:]+)(:.+)$/)
		{
			$name        = $1;
			$port{$name} = $2;
		}
		else
		{
			$port{$name} = '';
		}

		if (! defined $$node{$name})
		{
			$new = 1;

			$self -> add_node(name => $name);
		}
	}

	$self -> node_hash($node) if ($new);

	my($dot) = $self -> stringify_attributes(qq|"$from"$port{$from} ${$self -> global}{label} "$to"$port{$to}|, {%arg}, 1);

	$self -> command -> push($dot);
	$self -> log(debug => "Added edge: $dot");

	return $self;

} # End of add_edge.

# -----------------------------------------------

sub add_node
{
	my($self, %arg) = @_;
	my($name) = delete $arg{name};
	$name     = defined($name) ? $name : '';

	$self -> validate_params('node', %arg);

	my($node)                 = $self -> node_hash;
	$$node{$name}             = {} if (! $$node{$name});
	$$node{$name}{attributes} = {} if (! $$node{$name}{attributes});
	$$node{$name}{attributes} = {%{$$node{$name}{attributes} }, %arg};
	%arg                      = %{$$node{$name}{attributes} };
	my($label)                = $arg{label};

	# Handle ports.

	if (ref $label eq 'ARRAY')
	{
		my($lab, @label);

		for my $port (1 .. scalar @$label)
		{
			# HTML labels affect this code.

			($lab = $$label[$port - 1]) =~ s#([[\]{}"])#\\$1#g;

			push @label, "<port$port> $lab";
		}

		my(%global)      = %{$self -> global};
		my($orientation) = $global{record_orientation};
		$arg{label}      = join('|', @label);
		$arg{label}      = "{$arg{label}}" if ($orientation eq 'vertical');
		$arg{shape}      = 'record';
	}
	elsif ($arg{shape} && ( ($arg{shape} =~ /M?record/) || ( ($arg{shape} eq 'plaintext') && ($arg{label} =~ /^<</) ) ) )
	{
		# Do not escape anything.
	}
	elsif ($arg{label})
	{
		# HTML labels affect this code.

		$arg{label} =~ s#([[\]{}"])#\\$1#g;
	}

	$$node{$name}{attributes} = {%arg};
	my($dot)                  = $self -> stringify_attributes(qq|"$name"|, {%arg}, 1);

	$self -> command -> push($dot);
	$self -> node_hash($node);
	$self -> log(debug => "Added node: $dot");

	return $self;

} # End of add_node.

# -----------------------------------------------

sub default_edge
{
	my($self, %arg) = @_;

	$self -> validate_params('edge', %arg);

	my($scope)    = $self -> scope -> last;
	$$scope{edge} = {%{$$scope{edge} }, %arg};
	my($tos)      = $self -> scope -> length - 1;

	$self -> command -> push($self -> stringify_attributes('edge', $$scope{edge}, 1) );
	$self -> scope -> fill($scope, $tos, 1);
	$self -> log(debug => 'Default edge: ' . join(', ', map{"$_ => $$scope{edge}{$_}"} sort keys %{$$scope{edge} }) );

	return $self;

} # End of default_edge.

# -----------------------------------------------

sub default_graph
{
	my($self, %arg) = @_;

	$self -> validate_params('graph', %arg);

	my($scope)     = $self -> scope -> last;
	$$scope{graph} = {%{$$scope{graph} }, %arg};
	my($tos)       = $self -> scope -> length - 1;

	$self -> command -> push($self -> stringify_attributes('graph', $$scope{graph}, 1) );
	$self -> scope -> fill($scope, $tos, 1);
	$self -> log(debug => 'Default graph: ' . join(', ', map{"$_ => $$scope{graph}{$_}"} sort keys %{$$scope{graph} }) );

	return $self;

} # End of default_graph.

# -----------------------------------------------

sub default_node
{
	my($self, %arg) = @_;

	$self -> validate_params('node', %arg);

	my($scope)    = $self -> scope -> last;
	$$scope{node} = {%{$$scope{node} }, %arg};
	my($tos)      = $self -> scope -> length - 1;

	$self -> command -> push($self -> stringify_attributes('node', $$scope{node}, 1) );
	$self -> scope -> fill($scope, $tos, 1);
	$self -> log(debug => 'Default node: ' . join(', ', map{"$_ => $$scope{node}{$_}"} sort keys %{$$scope{node} }) );

	return $self;

} # End of default_node.

# -----------------------------------------------

sub _init
{
	my($self, $arg)                   = @_;
	$$arg{command}                    = Set::Array -> new;
	$$arg{dot_input}                  = '';
	$$arg{dot_output}                 = '';
	$$arg{edge}                       ||= {}; # Caller can set.
	$$arg{global}                     ||= {}; # Caller can set.
	$$arg{global}{directed}           = $$arg{global}{directed} ? 'digraph' : 'graph';
	$$arg{global}{driver}             ||= which('dot');
	$$arg{global}{format}             ||= 'svg';
	$$arg{global}{label}              ||= $$arg{global}{directed} eq 'digraph' ? '->' : '--';
	$$arg{global}{name}               ||= 'Perl';
	$$arg{global}{record_orientation} = $$arg{global}{record_orientation} && $$arg{global}{record_orientation} =~ /^horizontal$/ ? $1 : 'vertical';
	$$arg{global}{record_shape}       = $$arg{global}{record_shape} && $$arg{global}{record_shape} =~ /^(M?record)$/ ? $1 : 'Mrecord';
	$$arg{global}{strict}             ||= 0;
	$$arg{global}{timeout}            ||= 10;
	$$arg{graph}                      ||= {}; # Caller can set.
	$$arg{logger}                     ||= ''; # Caller can set.
	$$arg{node}                       ||= {}; # Caller can set.
	$$arg{node_hash}                  =  {};
	$$arg{scope}                      = Set::Array -> new;
	$$arg{valid_attributes}           = {};
	$$arg{verbose}                    ||= 0;  # Caller can set.
	$self                             = from_hash($self, $arg);

	$self -> load_valid_attributes;
	$self -> validate_params('global', %{$self -> global});
	$self -> validate_params('graph',  %{$self -> graph});
	$self -> validate_params('node',   %{$self -> node});
	$self -> validate_params('edge',   %{$self -> edge});
	$self -> scope -> push
		({
			edge  => $self -> edge,
			graph => $self -> graph,
			node  => $self -> node,
		 });

	my(%global) = %{$self -> global};

	$self -> log(debug => "Default global: $_ => $global{$_}") for sort keys %global;

	my($command) = (${$self -> global}{strict} ? 'strict ' : '')
		. (${$self -> global}{directed} . ' ')
		. ${$self -> global}{name}
		. "\n{\n";

	$self -> command -> push($command); 

	$self -> default_graph;
	$self -> default_node;
	$self -> default_edge;

	return $self;

} # End of _init.

# -----------------------------------------------

sub load_valid_attributes
{
	my($self) = @_;

	# Phase 1: Get attributes from __DATA__ section.

	my($data) = get_data_section;

	my(%data);

	for my $key (sort keys %$data)
	{
		$data{$key} = [grep{! /^$/ && ! /^(?:\s*)#/} split(/\n/, $$data{$key})];
	}

	# Phase 2: Reorder them so the major key is the context and the minor key is the attribute.
	# I.e. $attribute{global}{directed} => 1 means directed is valid in a global context.

	my(%attribute);

	for my $context (grep{! /common_attribute/} keys %$data)
	{
		for my $a (@{$data{$context} })
		{
			$attribute{$context}{$a} = 1;
		}
	}

	# Common attributes are a special case, since one attribute can be valid is several contexts...
	# Format: attribute_name => context_1, context_2.

	my($attribute);
	my($context, @context);

	for my $a (@{$data{common_attribute} })
	{
		($attribute, $context) = split(/\s*=>\s*/, $a);
		@context               = split(/\s*,\s*/, $context);

		for my $c (@context)
		{
			$attribute{$c}             = {} if (! $attribute{$c});
			$attribute{$c}{$attribute} = 1;
		}
	}

	$self -> valid_attributes(\%attribute);

	return $self;

} # End of load_valid_attributes.

# -----------------------------------------------

sub log
{
	my($self, $level, $message) = @_;
	$level   ||= 'debug';
	$message ||= '';

	# Avoid odd warning: Useless use of a constant () in void context at /home/ron/perl.modules/GraphViz2/blib/lib/GraphViz2.pm
	# $self -> logger ? $self -> logger -> $level($message) : $level eq 'error' ? die $message : $self -> verbose ? print "$level: $message\n" : '';

	if ($self -> logger)
	{
		$self -> logger -> $level($message);
	}
	elsif ($level eq 'error')
	{
		die $message;
	}
	elsif ($self -> verbose)
	{
		print "$level: $message\n";
	}

	return $self;

} # End of log.

# -----------------------------------------------

sub new
{
	my($class, %arg) = @_;
	my($self)        = bless {}, $class;
	$self            = $self -> _init(\%arg);

	return $self;

}	# End of new.

# -----------------------------------------------

sub pop_subgraph
{
	my($self) = @_;

	$self -> command -> push("}\n");
	$self -> scope -> pop;

	return $self;

}	# End of pop_subgraph.

# -----------------------------------------------

sub push_subgraph
{
	my($self, %arg) = @_;
	my($name) = delete $arg{name};
	$name     = defined($name) ? $name : '';

	$self -> validate_params('graph',  %{$arg{graph} });
	$self -> validate_params('node',   %{$arg{node} });
	$self -> validate_params('edge',   %{$arg{edge} });

	# Child inherits parent attributes.

	my($scope) = $self -> scope -> last;

	$self -> scope -> push
		({
			edge  => {%{$$scope{edge} },  %{$arg{edge} } },
			graph => {%{$$scope{graph} }, %{$arg{graph} } },
			node  => {%{$$scope{node} },  %{$arg{node} } },
		 });
	$self -> command -> push("subgraph $name {\n");
	$self -> default_graph;
	$self -> default_node;
	$self -> default_edge;

	return $self;

}	# End of push_subgraph.

# -----------------------------------------------

sub report_valid_attributes
{
	my($self)       = @_;
	my($attributes) = $self -> valid_attributes;

	$self -> log(info => 'Global attributes:');

	for my $a (sort keys %{$$attributes{global} })
	{
		$self -> log(info => $a);
	}

	$self -> log;
	$self -> log(info => 'Graph attributes:');

	for my $a (sort keys %{$$attributes{graph} })
	{
		$self -> log(info => $a);
	}

	$self -> log;
	$self -> log(info => 'Cluster attributes:');

	for my $n (sort keys %{$$attributes{cluster} })
	{
		$self -> log(info => $n);
	}

	$self -> log;
	$self -> log(info => 'Subgraph attributes:');

	for my $n (sort keys %{$$attributes{subgraph} })
	{
		$self -> log(info => $n);
	}

	$self -> log;
	$self -> log(info => 'Node attributes:');

	for my $n (sort keys %{$$attributes{node} })
	{
		$self -> log(info => $n);
	}

	$self -> log;
	$self -> log(info => 'Arrow modifiers:');

	for my $a (sort keys %{$$attributes{arrow_modifier} })
	{
		$self -> log(info => $a);
	}

	$self -> log;
	$self -> log(info => 'Arrow attributes:');

	for my $a (sort keys %{$$attributes{arrow} })
	{
		$self -> log(info => $a);
	}

	$self -> log;
	$self -> log(info => 'Edge attributes:');

	for my $a (sort keys %{$$attributes{edge} })
	{
		$self -> log(info => $a);
	}

	$self -> log;
	$self -> log(info => 'Output formats:');

	for my $a (sort keys %{$$attributes{output_format} })
	{
		$self -> log(info => $a);
	}

	$self -> log;

} # End of report_valid_attributes.

# -----------------------------------------------

sub run
{
	my($self, %arg)  = @_;
	my($driver)      = delete $arg{driver}      || ${$self -> global}{driver};
	my($format)      = delete $arg{format}      || ${$self -> global}{format};
	my($timeout)     = delete $arg{timeout}     || ${$self -> global}{timeout};
	my($output_file) = delete $arg{output_file} || '';
	%arg             = ($format => 1);

	$self -> validate_params('output_format', %arg);

	$self -> log(debug => "Driver: $driver. Output file: $output_file. Format: $format. Timeout: $timeout second(s)");
	$self -> log;

	my($result);

	try
	{
		$self -> dot_input(join('', @{$self -> command -> print} ) . "}\n");
		$self -> log(debug => $self -> dot_input);

		my($fh)   = File::Temp -> new;
		my($name) = $fh -> filename;

		binmode $fh;
		print $fh $self -> dot_input;
		close $fh;

		$Capture::Tiny::TIMEOUT = $timeout;
		my($stdout, $stderr)    = capture{system $driver, "-T$format", $name};

		die $stderr if ($stderr);

		$self -> dot_output($stdout);

		if ($output_file)
		{
			open(OUT, '>', $output_file) || die "Can't open(> $output_file): $!";
			binmode OUT;
			print OUT $stdout;
			close OUT;

			$self -> log(debug => "Wrote $output_file. Size: " . length($stdout) . ' bytes');
		}
	}
	catch
	{
		$result = $_;
	};

	die $result if ($result);

	return $self;

} # End of run.

# -----------------------------------------------

sub stringify_attributes
{
	my($self, $context, $option, $bracket) = @_;
	my($dot) = '';

	for my $key (sort keys %$option)
	{
		$dot .= $$option{$key} =~ /^<.+>$/ ? qq|$key=$$option{$key} | : qq|$key="$$option{$key}" |;
	}

	if ($bracket && $dot)
	{
		$dot = "$context [ $dot]\n";
	}
	else
	{
		$dot = $context =~ /^(?:edge|graph|node)/ ? '' : "$context\n";
	}

	return $dot;

} # End of stringify_attributes.

# -----------------------------------------------

sub validate_params
{
	my($self, $context, %attributes) = @_;
	my(%attr) = %{$self -> valid_attributes};

	for my $a (sort keys %attributes)
	{
		if (! $attr{$context}{$a})
		{
			$self -> log(error => "Error: '$a' is not a valid attribute in the '$context' context");
		}
	}

	return $self;

} # End of validate_params.

# -----------------------------------------------

1;

=pod

=head1 NAME

L<GraphViz2> - A wrapper for AT&T's Graphviz

=head1 Synopsis

=head2 Sample output

Unpack the distro and copy html/*.html and html/*.svg to your web server's doc root directory.

Then, point your browser at 127.0.0.1/graphviz.index.html.

Or, hit L<http://savage.net.au/Perl-modules/html/GraphViz2/graphviz.index.html>.

=head2 Perl code

	#!/usr/bin/env perl
	
	use strict;
	use warnings;
	
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
		 graph  => {label => "Parent (Graph produced by GraphViz2::Data::Grapher's $0)", rankdir => 'TB'},
		 logger => $logger,
		 node   => {shape => 'oval'},
		);
	
	$graph -> add_node(name => 'Carnegie', shape => 'circle');
	$graph -> add_node(name => 'Murrumbeena', shape => 'box', color => 'green');
	$graph -> add_node(name => 'Oakleigh',    color => 'blue');
	
	$graph -> add_edge(from => 'Murrumbeena', to    => 'Carnegie', arrowsize => 2);
	$graph -> add_edge(from => 'Murrumbeena', to    => 'Oakleigh', color => 'brown');
	
	$graph -> push_subgraph
	(
	 name  => 'cluster_1',
	 graph => {label => 'Child'},
	 node  => {color => 'magenta', shape => 'diamond'},
	);
	
	$graph -> add_node(name => 'Chadstone', shape => 'hexagon');
	$graph -> add_node(name => 'Waverley', color => 'orange');
	
	$graph -> add_edge(from => 'Chadstone', to => 'Waverley');
	
	$graph -> pop_subgraph;
	
	$graph -> default_node(color => 'cyan');
	
	$graph -> add_node(name => 'Malvern');
	$graph -> add_node(name => 'Prahran', shape => 'trapezium');
	
	$graph -> add_edge(from => 'Malvern', to => 'Prahran');
	$graph -> add_edge(from => 'Malvern', to => 'Murrumbeena');
	
	my($format)      = shift || 'svg';
	my($output_file) = shift || File::Spec -> catfile('html', "sub.graph.$format");
	
	$graph -> run(format => $format, output_file => $output_file, timeout => 11);

This program ships as scripts/sub.graph.pl. See L</Scripts Shipped with this Module>.

=head1 Description

=head2 Overview

This module provides a Perl interface to the amazing L<Graphviz|http://www.graphviz.org/>, an open source graph visualization tool from AT&T.

It is called GraphViz2 so that pre-existing code using (the Perl module) GraphViz continues to work.

To avoid confusion, when I use L<GraphViz2> (note the capital V), I'm referring to this Perl module, and
when I use L<Graphviz|http://www.graphviz.org/> (lower-case v) I'm referring to the underlying tool (which is in fact a set of programs).

This version of GraphViz2 targets V 2.23.6+ of L<Graphviz|http://www.graphviz.org/>.

Version 1.00 of L<GraphViz2> is a complete re-write, by Ron Savage, of GraphViz V 2, which was written by Leon Brocard. The point of the re-write
is to provide access to all the latest options available to users of L<Graphviz|http://www.graphviz.org/>.

GraphViz2 V 1 is not backwards compatible with GraphViz V 2, despite the considerable similarity. It was not possible to maintain compatibility
while extending support to all the latest features of L<Graphviz|http://www.graphviz.org/>.

To ensure L<GraphViz2> is a light-weight module, L<Hash::FieldHash> has been used to provide getters and setters,
rather than L<Moose>.

=head2 What is a Graph?

An undirected graph is a collection of nodes optionally linked together with edges.

A directed graph is the same, except that the edges have a direction, normally indicated by an arrow head.

A quick inspection of L<Graphviz|http://www.graphviz.org/>'s L<gallery|http://www.graphviz.org/Gallery.php> will show better than words
just how good L<Graphviz|http://www.graphviz.org/> is, and will reinforce the point that humans are very visual creatures.

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

C<new()> is called as C<< my($obj) = GraphViz2 -> new(k1 => v1, k2 => v2, ...) >>.

It returns a new object of type C<GraphViz2>.

Key-value pairs accepted in the parameter list:

=over 4

=item o edge => $hashref

The edge key points to a hashref which is used to set default attributes for edges.

Hence, allowable keys and values within that hashref are anything supported by L<Graphviz|http://www.graphviz.org/>.

The default is {}.

This key is optional.

=item o global => $hashref

The global key points to a hashref which is used to set attributes for the output stream.

Valid keys within this hashref are:

=over 4

=item o directed => $Boolean

This option affects the content of the output stream.

directed => 1 outputs 'digraph name {...}', while directed => 0 outputs 'graph name {...}'.

At the Perl level, directed graphs have edges with arrow heads, such as '->', while undirected graphs have
unadorned edges, such as '--'.

The default is 0.

This key is optional.

=item o driver => $program_name

This option specifies which external program to run to process the output stream.

The default is to use L<File::Which>'s which() method to find the 'dot' program.

This key is optional.

=item o format => $string

This option specifies what type of output file to create.

The default is 'svg'.

This key is optional.

=item o label => $string

This option specifies what an edge looks like: '->' for directed graphs and '--' for undirected graphs.

You wouldn't normally need to use this option.

The default is '->' if directed is 1, and '--' if directed is 0.

This key is optional.

=item o name => $string

This option affects the content of the output stream.

name => 'G666' outputs 'digraph G666 {...}'.

The default is 'Perl' :-).

This key is optional.

=item o record_orientation => /^(?:horizontal|vertical)$/

This option affects how records are plotted. The value must be 'horizontal' or 'vertical'.

The default is 'vertical', which suits L<GraphViz2::DBI>.

=item o record_shape => /^(?:M?record)$/

This option affects the shape of records. The value must be 'Mrecord' or 'record'.

Mrecords have nice, rounded corners, whereas plain old records have square corners.

The default is 'Mrecord'.

See L<Record shapes|http://www.graphviz.org/content/node-shapes#record> for details.

=item o strict => $Boolean

This option affects the content of the output stream.

strict => 1 outputs 'strict digraph name {...}', while strict => 0 outputs 'digraph name {...}'.

The default is 0.

This key is optional.

=item o timeout => $integer

This option specifies how long to wait for the external program before exiting with an error.

The default is 10 (seconds).

This key is optional.

=back

This key (global) is optional.

=item o graph => $hashref

The graph key points to a hashref which is used to set default attributes for graphs.

Hence, allowable keys and values within that hashref are anything supported by L<Graphviz|http://www.graphviz.org/>.

The default is {}.

This key is optional.

=item o logger => $logger_object

Provides a logger object so $logger_object -> $level($message) can be called at certain times.

See "Why such a different approach to logging?" in the "FAQ" for details.

Retrieve and update the value with the logger() method.

The default is ''.

See also the verbose option, which can interact with the logger option.

This key is optional.

=item o node => $hashref

The node key points to a hashref which is used to set default attributes for nodes.

Hence, allowable keys and values within that hashref are anything supported by L<Graphviz|http://www.graphviz.org/>.

The default is {}.

This key is optional.

=item o verbose => $Boolean

Provides a way to control the amount of output when a logger is not specified.

Setting verbose to 0 means print nothing.

Setting verbose to 1 means print the log level and the message to STDOUT, when a logger is not specified.

Retrieve and update the value with the verbose() method.

The default is 0.

See also the logger option, which can interact with the verbose option.

This key is optional.

=back

=head2 Validating Parameters

The secondary keys (under the primary keys 'edge|graph|node') are checked against lists of valid attributes (stored at the end of this
module, after the __DATA__ token, and made available using L<Data::Section::Simple>).

This mechanism has the effect of hard-coding L<Graphviz|http://www.graphviz.org/> options in the source code of L<GraphViz2>.

Nevertheless, the implementation of these lists is handled differently from the way it was done in V 2.

V 3 ships with a set of scripts, scripts/extract.*.pl, which retrieve pages from the L<Graphviz|http://www.graphviz.org/> web site and
extract the current lists of valid attributes. These are then copied manually into the source code of L<GraphViz2>, meaning any time those
lists change on the L<Graphviz|http://www.graphviz.org/> web site, it's a trivial matter to update the lists stored within this module.

See L<GraphViz2/Scripts Shipped with this Module>.

=head1 Attribute Scope

=head2 Graph Scope

The graphical elements graph, node and edge, have attributes. Attributes can be set when calling new().

Within new(), the defaults are graph => {}, node => {}, and edge => {}.

You override these with code such as new(edge => {color => 'red'}).

These attributes are pushed onto a scope stack during new()'s processing of its parameters, and they apply thereafter until changed.
They are the 'current' attributes. They live at scope level 0 (zero).

You change the 'current' attributes by calling any of the methods default_edge(%hash), default_graph(%hash) and default_node(%hash).

See scripts/trivial.pl (L<GraphViz2/Scripts Shipped with this Module>) for an example.

=head2 Subgraph Scope

When you wish to create a subgraph, you call push_subgraph(%hash). The word push emphasises that you are moving into a new scope,
and that the default attributes for the new scope are pushed onto the scope stack.

This module, as with L<Graphviz|http://www.graphviz.org/>, defaults to using inheritance of attributes.

That means the parent's 'current' attributes are combined with the parameters to push_subgraph(%hash) to generate a new set of 'current'
attributes for each of the graphical elements, graph, node and edge.

After a single call to push_subgraph(%hash), these 'current' attributes will live a level 1 in the scope stack.

See scripts/sub.graph.pl (L<GraphViz2/Scripts Shipped with this Module>) for an example.

Another call to push_subgraph(%hash), I<without> an intervening call to pop_subgraph(), will repeat the process, leaving you with
a set of attributes at level 2 in the scope stack.

Both L<GraphViz2> and L<Graphviz|http://www.graphviz.org/> handle this situation properly.

See scripts/sub.sub.graph.pl (L<GraphViz2/Scripts Shipped with this Module>) for an example.

At the moment, due to design defects (IMHO) in the underlying L<Graphviz|http://www.graphviz.org/> logic, there are some tiny problems with this:

=over 4

=item o A global frame

I can't see how to make the graph at level 0 in the scope stack have a frame.

=item o Frame color

When you specify graph => {color => 'red'} at the parent level, the subgraph has a red frame.

I think a subgraph should control its own frame.

=item o Parent and child frames

When you specify graph => {color => 'red'} at the subgraph level, both that subgraph and it children have red frames.

This contradicts what happens at the global level, in that specifying color there does not given the whole graph a frame.

=item o Frame visibility

A subgraph is currently forced to have a frame, unless you rig it by specifying a color the same as the background.

=back

I've posted an email to the L<Graphviz|http://www.graphviz.org/> mailing list suggesting a new option, framecolor, so deal with
this issue, including a special color of 'invisible'.

I'm using V 2.26.3 of L<Graphviz|http://www.graphviz.org/> as I write this (2011-06-06).

=head1 Methods

=head2 add_edge(from => $from_node_name, to => $to_node_name, [label => $label, %hash])

Adds an edge to the graph.

Returns $self to allow method chaining.

Here, [] indicate optional parameters.

Add a edge from 1 node to another.

$from_node_name and $to_node_name default to ''.

If either of these node names is unknown, add_node(name => $node_name) is called automatically. The lack of
attributes in this call means such nodes are created with the default set of attributes, and that may not
be what you want. To avoid this, you have to call add_node(...) yourself, with the appropriate attributes,
before calling add_edge(...).

$label defaults to the value supplied in the call to new(global => {label => '...'}), which in turn defaults
to '->' for directed graphs and '--' for undirected graphs. You wouldn't normally need to use this option.

%hash is any edge attributes accepted as L<Graphviz attributes|http://www.graphviz.org/content/attrs>. These are validated in exactly
the same way as the edge parameters in the calls to default_edge(%hash), new(edge => {}) and push_subgraph(edge => {}).

=head2 add_node(name => $node_name, [%hash])

Adds a node to the graph.

Returns $self to allow method chaining.

If you want to embed newlines or double-quotes in node names or labels, see scripts/quote.pl in L<GraphViz2/Scripts Shipped with this Module>.

If you want anonymous nodes, see scripts/anonymous.pl in L<GraphViz2/Scripts Shipped with this Module>.

Here, [] indicates an optional parameter.

%hash is any node attributes accepted as L<Graphviz attributes|http://www.graphviz.org/content/attrs>. These are validated in exactly
the same way as the node parameters in the calls to default_node(%hash), new(node => {}) and push_subgraph(node => {}).

The attribute name 'label' may point to a string or an arrayref. If it is an arrayref:

=over 4

=item o Each element is treated as a label

=item o Each label is given a port number (1 .. N)

=item o Each label + port appears in a separate, small, rectangle

=item o These rectangles are combined into a single node

=item o The shape of this node is forced to be a record

=item o Judicious use of '{' and '}' in the label can make this record appear horizontally or vertically, and even nested

=back

For more details on this complex topic, see L<Records|http://www.graphviz.org/content/node-shapes#record> and L<Ports|http://www.graphviz.org/content/attrs#kportPos>.

I could not get HTML-like labels working, so don't try them!

=head2 default_edge(%hash)

Sets defaults attributes for edges added subsequently.

Returns $self to allow method chaining.

%hash is any edge attributes accepted as L<Graphviz attributes|http://www.graphviz.org/content/attrs>. These are validated in exactly
the same way as the edge parameters in the calls to new(edge => {}) and push_subgraph(edge => {}).

=head2 default_graph(%hash)

Sets defaults attributes for the graph.

Returns $self to allow method chaining.

%hash is any graph attributes accepted as L<Graphviz attributes|http://www.graphviz.org/content/attrs>. These are validated in exactly
the same way as the graph parameter in the calls to new(graph => {}) and push_subgraph(graph => {}).

=head2 default_node(%hash)

Sets defaults attributes for nodes added subsequently.

Returns $self to allow method chaining.

%hash is any node attributes accepted as L<Graphviz attributes|http://www.graphviz.org/content/attrs>. These are validated in exactly
the same way as the node parameters in the calls to new(node => {}) and push_subgraph(node => {}).

=head2 dot_input()

Returns the output stream, formatted nicely, which was passed to the external program (e.g. dot).

You I<must> call run() before calling dot_input(), since it is only during the call to run() that the output stream is
stored in the buffer controlled by dot_input().

=head2 dot_output()

Returns the output from calling the external program (e.g. dot).

You I<must> call run() before calling dot_output(), since it is only during the call to run() that the output of the
external program is stored in the buffer controlled by dot_output().

This output is available even if run() does not write the output to a file.

=head2 load_valid_attributes()

Load various sets of valid attributes from within the source code of this module, using L<Data::Section::Simple>.

Returns $self to allow method chaining.

These attributes are used to validate attributes in many situations.

You wouldn't normally need to use this method.

=head2 sub log([$level, $message])

Logs the message at the given log level.

Returns $self to allow method chaining.

Here, [] indicate optional parameters.

$level defaults to 'debug', and $message defaults to ''.

log() then executes this, admittedly complex, line:

        $self -> logger                       # If there is a logger...
        ? $self -> logger -> $level($message) # Call it.
        : $level eq 'error'                   # Otherwise (no logger) and it's an error...
        ? die $message                        # Die.
        : $self -> verbose                    # Otherwise (no error) and we're verbose...
        ? print "$level: $message\n"          # Print.
        : '';                                 # Otherwise (silent) do nothing.

=head2 logger($logger_object])

Gets or sets the log object.

Here, [] indicates an optional parameter.

=head2 pop_subgraph()

Pop off and discard the top element of the scope stack.

Returns $self to allow method chaining.

=head2 push_subgraph([name => $name, edge => {...}, graph => {...}, node => {...}])

Sets up a new subgraph environment.

Returns $self to allow method chaining.

Here, [] indicate optional parameters.

name => $name is the name to assign to the subgraph. Name defaults to ''.

So, without $name, 'subgraph {' is written to the output stream.

With $name, "subgraph $name {" is written to the output stream.

Note that subgraph names beginning with 'cluster' are special to L<Graphviz|http://www.graphviz.org/>.

edge => {...} is any edge attributes accepted as L<Graphviz attributes|http://www.graphviz.org/content/attrs>. These are validated in exactly
the same way as the edge parameters in the calls to default_edge(%hash), new(edge => {}) and push_subgraph(edge => {}).

graph => {...} is any graph attributes accepted as L<Graphviz attributes|http://www.graphviz.org/content/attrs>. These are validated in exactly
the same way as the graph parameters in the calls to default_graph(%hash), new(graph => {}) and push_subgraph(graph => {}).

node => {...} is any node attributes accepted as L<Graphviz attributes|http://www.graphviz.org/content/attrs>. These are validated in exactly
the same way as the node parameters in the calls to default_node(%hash), new(node => {}) and push_subgraph(node => {}).

=head2 report_valid_attributes()

Prints all attributes known to this module.

Returns nothing.

You wouldn't normally need to use this method.

See scripts/report.valid.attributes.pl. See L<GraphViz2/Scripts Shipped with this Module>.

=head2 run([driver => $exe, format => $string, timeout => $integer, output_file => $output_file])

Runs the given program to process the output stream.

Returns $self to allow method chaining.

Here, [] indicate optional parameters.

$driver is the name of the external program to run.

It defaults to the value supplied in the call to new(global => {driver => '...'}), which in turn defaults
to L<File::Which>'s which('dot') return value.

$format is the type of output file to write.

It defaults to the value supplied in the call to new(global => {format => '...'}), which in turn defaults
to 'svg'.

$timeout is the time in seconds to wait while the external program runs, before dieing with an error.

It defaults to the value supplied in the call to new(global => {timeout => '...'}), which in turn defaults
to 10.

$output_file is the name of the file into which the output from the external program is written.

Perl's binmode is called on this file.

There is no default value for $output_file. If a value is not supplied for $output_file, the only way
to recover the output of the external program is to call dot_output().

This method performs a series of tasks:

=over 4

=item o Formats the output stream

=item o Stores the formatted output in a buffer controlled by the dot_input() method

=item o Output the output stream to a file

=item o Run the chosen external program on that file

=item o Capture STDOUT and STDERR from that program

=item o Die if STDERR contains anything

=item o Copies STDOUT to the buffer controlled by the dot_output() method

=item o Write the captured contents of STDOUT to $output_file, if $output_file has a value

=back

=head2 stringify_attributes($context, $option, $bracket)

Returns a string suitable to writing to the output stream.

$context is one of 'edge', 'graph', 'node', or a special string. See the code for details.

You wouldn't normally need to use this method.

=head2 validate_params($context, %attributes)

Validate the given attributes within the given context.

Returns $self to allow method chaining.

$context is one of 'edge', 'global', 'graph', 'node' or 'output_format'.
 
You wouldn't normally need to use this method.

=head2 verbose([$integer])

Gets or sets the verbosity level, for when a logging object is not used.

Here, [] indicates an optional parameter.

=head1 FAQ

=head2 o I'm having trouble with special characters in node names and labels

L<GraphViz2> escapes these characters in those contexts: []{}".

It would be nice to also escape | and <, but these characters are used in specifying ports in records.

See the next point for details.

=head2 A warning about L<Graphviz|http://www.graphviz.org/> and ports

Ports are what L<Graphviz|http://www.graphviz.org/> calls those places on the outline of a node where edges
leave and terminate.

The L<Graphviz|http://www.graphviz.org/> syntax for ports is a bit unusual:

=over 4

=item o This works: "node_name":port5

=item o This doesn't: "node_name:port5"

=back

You don't have to quote all node names in L<Graphviz|http://www.graphviz.org/>, but some, such as digits, must be quoted, so I've decided to quote them all.

=head2 What happened to GraphViz::No?

The default_node(%hash) method in L<GraphViz2> allows you to make nodes vanish.

Try: $graph -> default_node(label => '', height => 0, width => 0, style => 'invis');

Because that line is so simple, I feel it's unnecessary to make a subclass of GraphViz2.

=head2 What happened to GraphViz::Regex?

See L<GraphViz2::Parse::Regexp>.

=head2 What happened to GraphViz::Small?

The default_node(%hash) method in L<GraphViz2> allows you to make nodes which are small.

Try: $graph -> default_node(label => '', height => 0.2, width => 0.2, style => 'filled');

Because that line is so simple, I feel it's unnecessary to make a subclass of GraphViz2.

=head2 What happened to GraphViz::XML?

Use L<GraphViz2::Parse::XML> instead, which uses the pure-Perl XML::Tiny.

Alternately, see L<GraphViz2/Scripts Shipped with this Module> for how to use L<XML::Bare>, L<GraphViz2>
and L<GraphViz2::Data::Grapher> instead.

See L</scripts/parse.xml.pp.pl> or L</scripts/parse.xml.bare.pl> below.

=head2 GraphViz returned a node name from add_node() when given an anonymous node. What does GraphViz2 do?

You can give the node a name, and an empty string for a label, to suppress plotting the name.

See L</scripts/anonymous.pl> for demo code.

If there is some specific requirement which this does not cater for, let me know and I can change the code.

=head2 Why such a different approach to logging?

As you can see from scripts/*.pl, I always use L<Log::Handler>.

By default (i.e. without a logger object), L<GraphViz2> prints warning and debug messages to STDOUT,
and dies upon errors.

However, by supplying a log object, you can capture these events.

Not only that, you can change the behaviour of your log object at any time, by calling
L</logger($logger_object)>.

=head2 A Note about XML Containers

The 2 demo programs L</scripts/parse.html.pl> and L</scripts/parse.xml.bare.pl>, which both use L<XML::Bare>, assume your XML has a single
parent container for all other containers. The programs use this container to provide a name for the root node of the graph.

=head2 Is there a pure-Perl version of GraphViz2?

Yes, this one (AFAIK), not counting dependencies, such as your operating system, Perl, and of course L<Graphviz|http://www.graphviz.org/>.

I've made XML::Bare a pre-req, and that module needs a compiler, but the only place XML::Bare is used is in
scripts/parse.xml.bare.pl.

If you wish to remove this dependency, here's what you need to do:

=over 4

=item o Remove XML::Bare from Build.PL

=item o Remove XML::Bare from Makefile.PL.

=item o Edit scripts/generate.svg.sh to comment out running scripts/parse.xml.bare.pl

=item o Move scripts/parse.xml.bare.pl to t/

The point of this is that t/test.t looks in scripts/ for programs having annotations on line 4, and we want to skip it
so that all tests pass.

The other point is that scripts/generate.index.pl looks for scripts with annotations, too.

=back

=head2 Why did you choose L<Hash::FieldHash> over L<Moose>?

My policy is to use L<Hash::FieldHash> for stand-alone modules and L<Moose> for applications.

=head1 Scripts Shipped with this Module

=head2 scripts/anonymous.pl

Demonstrates empty strings for node names and labels.

Outputs to ./html/anonymous.svg by default.

=head2 scripts/cluster.pl

Demonstrates building a cluster as a subgraph.

Outputs to ./html/cluster.svg by default.

See </TODO> below for more on clusters.

=head2 scripts/dbi.schema.pl

If the environment vaiables DBI_DSN, DBI_USER and DBI_PASS are set (the latter 2 are optional), then this demonstrates building a
graph from a database schema.

Outputs to ./html/dbi.schema.svg by default.

=head2 scripts/extract.arrow.shapes.pl

Downloads the arrow shapes from L<Graphviz's Arrow Shapes|http://www.graphviz.org/content/arrow-shapes> and outputs them to ./data/arrow.shapes.html.
Then it extracts the reserved words into ./data/arrow.shapes.dat.

=head2 scripts/extract.attributes.pl

Downloads the attributes from L<Graphviz's Attributes|http://www.graphviz.org/content/attrs> and outputs them to ./data/attributes.html.
Then it extracts the reserved words into ./data/attributes.dat.

=head2 scripts/extract.node.shapes.pl

Downloads the node shapes from L<Graphviz's Node Shapes|http://www.graphviz.org/content/node-shapes> and outputs them to ./data/node.shapes.html.
Then it extracts the reserved words into ./data/node.shapes.dat.

=head2 scripts/extract.output.formats.pl

Downloads the output formats from L<Graphviz's Output Formats|http://www.graphviz.org/content/output-formats> and outputs them to ./data/output.formats.html.
Then it extracts the reserved words into ./data/output.formats.dat.

=head2 scripts/generate.index.pl

Run by scripts/generate.svg.sh. See next point.

=head2 scripts/generate.svg.sh

A bash script to run all the scripts and generate the *.svg and *.log files, in ./html.

You can them copy html/*.html and html/*.svg to your web server's doc root, for viewing.

=head2 scripts/Heawood.pl

Demonstrates the transitive 6-net, also known as Heawood's graph.

Outputs to ./html/Heawood.svg by default.

This program was reverse-engineered from graphs/undirected/Heawood.gv in the distro for L<Graphviz|http://www.graphviz.org/> V 2.26.3.

=head2 scripts/parse.data.pl

Demonstrates graphing a Perl data structure.

Outputs to ./html/parse.data.svg by default.

=head2 scripts/parse.html.pl

Demonstrates using L<XML::Bare> to parse HTML.

Inputs from ./t/sample.html, and outputs to ./html/parse.html.svg by default.

=head2 scripts/parse.recdescent.pl

Demonstrates graphing a L<Parse::RecDescent>-style grammar.

Inputs from t/sample.recdescent.grammar.1 and outputs to ./html/parse.recdescent.svg by default.

The input grammar was extracted from t/basics.t in L<Parse::RecDescent> V 1.965001.

You can patch the *.pl to read from t/sample.recdescent.grammar.2, which was copied from L<a V 2 bug report|https://rt.cpan.org/Ticket/Display.html?id=36057>.

=head2 scripts/parse.regexp.pl

Demonstrates graphing a Perl regular expression.

Outputs to ./html/parse.regexp.svg by default.

=head2 scripts/parse.yacc.pl

Demonstrates graphing a L<byacc|http://invisible-island.net/byacc/byacc.html>-style grammar.

Inputs from t/calc3.output, and outputs to ./html/parse.yacc.svg by default.

The input was copied from test/calc3.y in byacc V 20101229 and process as below.

Note: The version downloadable via HTTP is 20101127.

I installed byacc like this:

	sudo apt-get byacc

Now get a sample file to work with:

	cd ~/Downloads
	curl ftp://invisible-island.net/byacc/byacc.tar.gz > byacc.tar.gz
	tar xvzf byacc.tar.gz
	cd ~/perl.modules/GraphViz2
	cp ~/Downloads/byacc-20101229/test/calc3.y t
	byacc -v t/calc3.y
	mv y.output t/calc3.output
	diff ~/Downloads/byacc-20101229/test/calc3.output t/calc3.output
	rm y.tab.c

It's the file calc3.output which ships in the t/ directory.

=head2 scripts/parse.yapp.pl

Demonstrates graphing a L<Parse::Yapp>-style grammar.

Inputs from t/calc.output, and outputs to ./html/parse.yapp.svg by default.

The input was copied from t/calc.t in L<Parse::Yapp>'s and processed as below.

I installed L<Parse::Yapp> (and yapp) like this:

	cpanm Parse::Yapp

Now get a sample file to work with:

	cd ~/perl.modules/GraphViz2
	cp ~/.cpanm/latest-build/Parse-Yapp-1.05/t/calc.t t/calc.input

Edit t/calc.input to delete the code, leaving the grammar after the __DATA__token.

	yapp -v t/calc.input > t/calc.output
	rm t/calc.pm

It's the file calc.output which ships in the t/ directory.

=head2 scripts/parse.xml.bare.pl

Demonstrates using L<XML::Bare> to parse XML.

Inputs from ./t/sample.xml, and outputs to ./html/parse.xml.bare.svg by default.

=head2 scripts/parse.xml.pp.pl

Demonstrates using L<XML::Tiny> to parse XML.

Inputs from ./t/sample.xml, and outputs to ./html/parse.xml.pp.svg by default.

=head2 scripts/quote.pl

Demonstrates embedded newlines and double-quotes in node names and labels.

It also demonstrates that the justification escapes, \l and \r, work too, sometimes.

Outputs to ./html/quote.svg by default.

Tests which run dot directly show this is a bug in L<Graphviz|http://www.graphviz.org/> itself.

For example, in this graph, it looks like \r only works after \l (node d), but not always (nodes b, c).

Call this x.dot:

	digraph G {
		rankdir=LR;
		node [shape=oval];
		a [ label ="a: Far, far, Left\rRight"];
		b [ label ="\lb: Far, far, Left\rRight"];
		c [ label ="XXX\lc: Far, far, Left\rRight"];
		d [ label ="d: Far, far, Left\lRight\rRight"];
	}

and use the command:

	dot -Tsvg x.dot

See L<the Graphviz docs|http://www.graphviz.org/content/attrs#kescString> for escString, where they write 'l to mean \l, for some reason.

=head2 scripts/report.valid.attributes.pl

Prints all current (V 2.23.6) L<Graphviz|http://www.graphviz.org/> attributes, along with a few global ones I've invented for the purpose of writing this module.

Outputs to STDOUT.

=head2 scripts/sub.graph.pl

Demonstrates a graph combined with a subgraph.

Outputs to ./html/sub.graph.svg by default.

=head2 scripts/sub.sub.graph.pl

Demonstrates a graph combined with a subgraph combined with a subsubgraph.

Outputs to ./html/sub.sub.graph.svg by default.

=head2 scripts/trivial.pl

Demonstrates a trivial 3-node graph, with colors, just to get you started.

Outputs to ./html/trivial.svg by default.

=head1 TODO

=over 4

=item o Does GraphViz2 need to emulate the sort option in GraphViz?

That depends on what that option really does.

=item o Finish work on clusters

For instance, L<the compound attribute|http://www.graphviz.org/content/attrs#dcompound> indicates we have to allow edges between clusters.

V 1.00 assumes the cluster names are node names, and fabricates unwanted nodes to match.

There are no samples of using compound in the examples shipped with L<Graphviz|http://www.graphviz.org/> V 2.23.6.

=item o Handle edges such as 1 -> 2 -> {A B}, as seen in L<Graphviz|http://www.graphviz.org/>'s graphs/directed/switch.gv

But how?

=item o Handle HTML-style labels

=item o Validate parameters more carefully, e.g. to reject non-hashref arguments where appropriate

Some method parameter lists take keys whose value must be a hashref.

=item o Integrate with the new, unreleased, L<Graph::Easy::Marpa>

=item o Extend to Perl class relationships

See L<Class::Sniff> and L<GraphViz::ISA::Multi> for previous work.

=back

=head1 A Extremely Short List of Other Graphing Software

L<Axis Maps|http://www.axismaps.com/>.

L<Polygon Map Generation|http://www-cs-students.stanford.edu/~amitp/game-programming/polygon-map-generation/>.
Read more on that L<here|http://blogs.perl.org/users/max_maischein/2011/06/display-your-data---randompoissondisc.html>.

L<Voronoi Applications|http://www.voronoi.com/wiki/index.php?title=Voronoi_Applications>.

=head1 Machine-Readable Change Log

The file CHANGES was converted into Changelog.ini by L<Module::Metadata::Changes>.

=head1 Thanks

Many thanks are due to the people who chose to make L<Graphviz|http://www.graphviz.org/> Open Source.

And thanks to L<Leon Brocard|http://search.cpan.org/~lbrocard/>, who wrote L<GraphViz>, and kindly gave me co-maint of the module.

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

__DATA__
@@ arrow_modifier
l
o
r

@@ arrow
box
crow
diamond
dot
inv
none
normal
tee
vee

@@ common_attribute
Damping => graph
K => graph, cluster
URL => edge, node, graph, cluster
area => node, cluster
arrowhead => edge
arrowsize => edge
arrowtail => edge
aspect => graph
bb => graph
bgcolor => graph, cluster
center => graph
charset => graph
clusterrank => graph
color => edge, node, cluster
colorscheme => edge, node, cluster, graph
comment => edge, node, graph
compound => graph
concentrate => graph
constraint => edge
decorate => edge
defaultdist => graph
dim => graph
dimen => graph
dir => edge
diredgeconstraints => graph
distortion => node
dpi => graph
edgeURL => edge
edgehref => edge
edgetarget => edge
edgetooltip => edge
epsilon => graph
esep => graph
fillcolor => node, cluster
fixedsize => node
fontcolor => edge, node, graph, cluster
fontname => edge, node, graph, cluster
fontnames => graph
fontpath => graph
fontsize => edge, node, graph, cluster
group => node
headURL => edge
headclip => edge
headhref => edge
headlabel => edge
headport => edge
headtarget => edge
headtooltip => edge
height => node
href => graph, cluster, node, edge
id => graph, node, edge
image => node
imagescale => node
label => edge, node, graph, cluster
labelURL => edge
label_scheme => graph
labelangle => edge
labeldistance => edge
labelfloat => edge
labelfontcolor => edge
labelfontname => edge
labelfontsize => edge
labelhref => edge
labeljust => graph, cluster
labelloc => node, graph, cluster
labeltarget => edge
labeltooltip => edge
landscape => graph
layer => edge, node
layers => graph
layersep => graph
layout => graph
len => edge
levels => graph
levelsgap => graph
lhead => edge
lheight => graph, cluster
lp => edge, graph, cluster
ltail => edge
lwidth => graph, cluster
margin => node, graph
maxiter => graph
mclimit => graph
mindist => graph
minlen => edge
mode => graph
model => graph
mosek => graph
nodesep => graph
nojustify => graph, cluster, node, edge
normalize => graph
nslimit => graph
ordering => graph, node
orientation => node
orientation => graph
outputorder => graph
overlap => graph
overlap_scaling => graph
pack => graph
packmode => graph
pad => graph
page => graph
pagedir => graph
pencolor => cluster
penwidth => cluster, node, edge
peripheries => node, cluster
pin => node
pos => edge, node
quadtree => graph
quantum => graph
rank => subgraph
rankdir => graph
ranksep => graph
ratio => graph
rects => node
regular => node
remincross => graph
repulsiveforce => graph
resolution => graph
root => graph, node
rotate => graph
rotation => graph
samehead => edge
sametail => edge
samplepoints => node
scale => graph
searchsize => graph
sep => graph
shape => node
shapefile => node
showboxes => edge, node, graph
sides => node
size => graph
skew => node
smoothing => graph
sortv => graph, cluster, node
splines => graph
start => graph
style => edge, node, cluster
stylesheet => graph
tailURL => edge
tailclip => edge
tailhref => edge
taillabel => edge
tailport => edge
tailtarget => edge
tailtooltip => edge
target => edge, node, graph, cluster
tooltip => node, edge, cluster
truecolor => graph
vertices => node
viewport => graph
voro_margin => graph
weight => edge
width => node
z => node

@@ global
directed
driver
format
label
name
record_orientation
record_shape
strict
timeout

@@ node
Mcircle
Mdiamond
Msquare
box
box3d
circle
component
diamond
doublecircle
doubleoctagon
egg
ellipse
folder
hexagon
house
invhouse
invtrapezium
invtriangle
none
note
octagon
oval
parallelogram
pentagon
plaintext
point
polygon
rect
rectangle
septagon
square
tab
trapezium
triangle
tripleoctagon

@@ output_format
bmp
canon
cmap
cmapx
cmapx_np
dot
eps
fig
gd
gd2
gif
gtk
ico
imap
imap_np
ismap
jpe
jpeg
jpg
pdf
plain
plain-ext
png
ps
ps2
svg
svgz
tif
tiff
vml
vmlz
vrml
wbmp
xdot
xlib
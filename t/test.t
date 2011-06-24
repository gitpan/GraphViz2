use strict;
use warnings;

use Capture::Tiny 'capture';

use File::Spec;
use File::Temp;

use GraphViz2::Utils;

use Test::More;

# ------------------------------------------------

BEGIN{ use_ok('GraphViz2'); }

my($count)    = 1; # Counting the use_ok above.
my(%script)   = GraphViz2::Utils -> new -> get_scripts;
my($temp_dir) = File::Temp -> newdir;

my($stdout, $stderr);

for my $script (sort keys %script)
{
		$count++;
		($stdout, $stderr) = capture{system $^X, '-Ilib', $script, 'svg', File::Spec -> catfile($temp_dir, "$script{$script}.svg")};

		ok(length($stderr) == 0, "$script runs without error");
}

done_testing($count);

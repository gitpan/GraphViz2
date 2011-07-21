#!/bin/bash

perl -Ilib scripts/anonymous.pl        png > /tmp/anonymous.log
perl -Ilib scripts/cluster.pl          png > /tmp/cluster.log
perl -Ilib scripts/dbi.schema.pl       png > /tmp/dbi.schema.log
perl -Ilib scripts/dependency.pl       png > /tmp/dependency.log
perl -Ilib scripts/Heawood.pl          png > /tmp/Heawood.log

# The default png output does not work, for unknown reasons...
# jointed.edges.pl has been patched to output to *.png.

perl -Ilib scripts/jointed.edges.pl png:gd > /tmp/jointed.edges.log
perl -Ilib scripts/parse.data.pl       png > /tmp/parse.data.log
perl -Ilib scripts/parse.html.pl       png > /tmp/parse.hml.log
perl -Ilib scripts/parse.isa.pl        png > /tmp/parse.isa.log
perl -Ilib scripts/parse.marpa.pl      png > /tmp/parse.marpa.log
perl -Ilib scripts/parse.recdescent.pl png > /tmp/parse.recdescent.log
perl -Ilib scripts/parse.regexp.pl     png > /tmp/parse.regexp.log
perl -Ilib scripts/parse.stt.pl        png > /tmp/parse.stt.log
perl -Ilib scripts/parse.xml.bare.pl   png > /tmp/parse.xml.bare.log
perl -Ilib scripts/parse.xml.pp.pl     png > /tmp/parse.xml.pp.log
perl -Ilib scripts/parse.yacc.pl       png > /tmp/parse.yacc.log
perl -Ilib scripts/parse.yapp.pl       png > /tmp/parse.yapp.log
perl -Ilib scripts/quote.pl            png > /tmp/quote.log
perl -Ilib scripts/sub.graph.pl        png > /tmp/sub.graph.log
perl -Ilib scripts/sub.sub.graph.pl    png > /tmp/sub.sub.graph.log
perl -Ilib scripts/trivial.pl          png > /tmp/trivial.log

perl -Ilib scripts/generate.demo.pl

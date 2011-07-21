#!/bin/bash

perl -Ilib scripts/anonymous.pl        > /tmp/anonymous.log
perl -Ilib scripts/cluster.pl          > /tmp/cluster.log
perl -Ilib scripts/dbi.schema.pl       > /tmp/dbi.schema.log
perl -Ilib scripts/dependency.pl       > /tmp/dependency.log
perl -Ilib scripts/Heawood.pl          > /tmp/Heawood.log
perl -Ilib scripts/jointed.edges.pl    > /tmp/jointed.edges.log
perl -Ilib scripts/parse.data.pl       > /tmp/parse.data.log
perl -Ilib scripts/parse.html.pl       > /tmp/parse.hml.log
perl -Ilib scripts/parse.isa.pl        > /tmp/parse.isa.log
perl -Ilib scripts/parse.marpa.pl      > /tmp/parse.marpa.log
perl -Ilib scripts/parse.recdescent.pl > /tmp/parse.recdescent.log
perl -Ilib scripts/parse.regexp.pl     > /tmp/parse.regexp.log
perl -Ilib scripts/parse.stt.pl        > /tmp/parse.stt.log
perl -Ilib scripts/parse.xml.bare.pl   > /tmp/parse.xml.bare.log
perl -Ilib scripts/parse.xml.pp.pl     > /tmp/parse.xml.pp.log
perl -Ilib scripts/parse.yacc.pl       > /tmp/parse.yacc.log
perl -Ilib scripts/parse.yapp.pl       > /tmp/parse.yapp.log
perl -Ilib scripts/quote.pl            > /tmp/quote.log
perl -Ilib scripts/sub.graph.pl        > /tmp/sub.graph.log
perl -Ilib scripts/sub.sub.graph.pl    > /tmp/sub.sub.graph.log
perl -Ilib scripts/trivial.pl          > /tmp/trivial.log

perl -Ilib scripts/generate.demo.pl

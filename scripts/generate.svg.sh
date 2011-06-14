#!/bin/bash

perl -Ilib scripts/anonymous.pl        > html/anonymous.log
perl -Ilib scripts/cluster.pl          > html/cluster.log
perl -Ilib scripts/dbi.schema.pl       > html/dbi.schema.log
perl -Ilib scripts/Heawood.pl          > html/Heawood.log
perl -Ilib scripts/parse.data.pl       > html/parse.data.log
perl -Ilib scripts/parse.html.pl       > html/parse.hml.log
perl -Ilib scripts/parse.recdescent.pl > html/parse.recdescent.log
perl -Ilib scripts/parse.regexp.pl     > html/parse.regexp.log
perl -Ilib scripts/parse.xml.bare.pl   > html/parse.xml.bare.log
perl -Ilib scripts/parse.xml.pp.pl     > html/parse.xml.pp.log
perl -Ilib scripts/parse.yacc.pl       > html/parse.yacc.log
perl -Ilib scripts/parse.yapp.pl       > html/parse.yapp.log
perl -Ilib scripts/quote.pl            > html/quote.log
perl -Ilib scripts/sub.graph.pl        > html/sub.graph.log
perl -Ilib scripts/sub.sub.graph.pl    > html/sub.sub.graph.log
perl -Ilib scripts/trivial.pl          > html/trivial.log

perl -Ilib scripts/generate.index.pl

#!/usr/local/jci/perl/bin/perl

use strict;

use eMatrix::DB;
use eMatrix::Person;


my $mdb = eMatrix::DB::connect("MATRIX-R",
                               "/app/matrixone/ematrix/scripts");

my @ppl = $mdb->list_person("creator");

foreach my $person (@ppl) {
   print "Name   = " . $person->get_name() . "\n";
   print "DESC   = " . $person->get_description() . "\n";

}

$mdb->disconnect();

#!/usr/local/perl/bin/perl

use strict;

use eMatrix::DB;
use eMatrix::Vault;

my $mdb = eMatrix::DB::connect("MATRIX-R",
                               "/app/matrixone/ematrix/scripts");

my @vaults = $mdb->list_vault("eService Production");

foreach my $vault (@vaults) {
   print "Name   = " . $vault->get_name() . "\n";
   print "DESC   = " . $vault->get_description() . "\n";
   print "STATS  = " . $vault->get_statistics() . "\n";
   print $vault->get_numberofobjects(), " objects in ", $vault->get_name(), "\n";

}

$mdb->disconnect();

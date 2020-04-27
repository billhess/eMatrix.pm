#!/usr/local/perl/bin/perl

use strict;

use eMatrix::DB;
use eMatrix::Store;

my $mdb = eMatrix::DB::connect("MATRIX-R",
                               "/app/matrixone/ematrix/scripts");

my @vaults = $mdb->list_store("STORE");

foreach my $vault (@vaults) {
   print "Name   = " . $vault->get_name() . "\n";
   print "DESC   = " . $vault->get_description() . "\n";
   print "Host   = " . $vault->get_host() . "\n";
   print "Path   = " . $vault->get_path() . "\n";
   print "Perms  = " . $vault->get_permission() . "\n";

}

$mdb->disconnect();

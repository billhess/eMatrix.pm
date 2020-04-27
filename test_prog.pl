#!/usr/local/perl/bin/perl

use strict;

use eMatrix::DB;
use eMatrix::Program;


my $mdb = eMatrix::DB::connect("MATRIX-R",
                               "/app/matrixone/ematrix/scripts");

$mdb->set_context("creator");

my @progs = $mdb->list_program("emxTriggerWrapper.tcl");

foreach my $prog (@progs) {
   print "Name   = " . $prog->get_name() . "\n";
   print "DESC   = " . $prog->get_description() . "\n";

   print "Code: \n";
   print "-------------------------------------------\n";
   print $prog->get_code(), "\n";
   print "-------------------------------------------\n";
}

$mdb->disconnect();

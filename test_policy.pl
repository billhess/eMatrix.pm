#!/usr/local/perl/bin/perl

use strict;

use eMatrix::DB;
use eMatrix::Policy;
use eMatrix::Format;


my $mdb = eMatrix::DB::connect("MATRIX-R",
                               "/app/matrixone/ematrix/scripts");

my @pols = $mdb->list_policy("Organization");

foreach my $policy (@pols) {
   print "Name   = " . $policy->get_name() . "\n";
   print "DESC   = " . $policy->get_description() . "\n";

   my @formats = $policy->get_format();

   print "Formats: \n";
   foreach my $format (@formats) {
      print "Name: ", $format->get_name(), "\n";
   }
}

$mdb->disconnect();

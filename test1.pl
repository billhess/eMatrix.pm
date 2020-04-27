#!/usr/local/jci/perl/bin/perl

use strict;

use eMatrix::DB;
use eMatrix::Type;


my $mdb = eMatrix::DB::connect("MATRIX-R",
			       "/app/matrixone/ematrix/scripts");

my @types = $mdb->list_type("Document");

foreach my $type (@types) {
   print "TYPE = " . $type->get_name() . "\n";
   print "DESC = " . $type->get_description() . "\n";

   my @attrs = $type->get_attributes();

   foreach my $attr (@attrs) {
      print "ATTR = '" . $attr->get_name() . "'\n";
      foreach my $range ($attr->get_range()) {
	 print "   RANGE = '$range'\n";
      }
   }
}

$mdb->disconnect();

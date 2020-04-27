#!/usr/local/perl/bin/perl

use strict;

use eMatrix::DB;
use eMatrix::Type;
use eMatrix::Relationship;


my $mdb = eMatrix::DB::connect("MATRIX-R",
                               "/app/matrixone/ematrix/scripts");

my @rels = $mdb->list_relationship("Risk Item");

foreach my $rel (@rels) {
   print "Rel Name = " . $rel->get_name() . "\n";
   print "DESC     = " . $rel->get_description() . "\n";

   my @to_types = $rel->get_to_type();

   print "Connects TO:\n";
   foreach my $type (@to_types) {
      print $type->get_name(), "\n";
   }

}

$mdb->disconnect();

#!/usr/local/perl/bin/perl

use strict;

use eMatrix::DB;
use eMatrix::Group;
use eMatrix::Person;


my $mdb = eMatrix::DB::connect("MATRIX-R",
                               "/app/matrixone/ematrix/scripts");

my @groups = $mdb->list_group("Distribution Groups");

foreach my $group (@groups) {
   print "Name   = " . $group->get_name() . "\n";
   print "DESC   = " . $group->get_description() . "\n";

   my @members = $group->get_members();

   print "Members: \n";
   foreach my $person (@members) {
      print "Name: ", $person->get_name(), "\n";
   }
}

$mdb->disconnect();

#!/usr/local/jci/perl/bin/perl

use strict;

use eMatrix::DB;
use eMatrix::Role;
use eMatrix::Person;


my $mdb = eMatrix::DB::connect("MATRIX-R",
                               "/app/matrixone/ematrix/scripts");

my @roles = $mdb->list_role("Employee");

foreach my $role (@roles) {
   print "Name   = " . $role->get_name() . "\n";
   print "DESC   = " . $role->get_description() . "\n";

   my @members = $role->get_members();

   print "Members: \n";
   foreach my $person (@members) {
      print "Name: ", $person->get_name(), "\n";
   }
}

$mdb->disconnect();

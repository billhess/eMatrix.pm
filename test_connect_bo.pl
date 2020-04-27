#!/usr/local/perl/bin/perl
####
# Connecting Business Obejcts
####

use strict;

use eMatrix::DB;
use eMatrix::BizObj;
use eMatrix::Expand;


my $mdb = eMatrix::DB::connect("MATRIX-R",
                               "/app/matrixone/ematrix/scripts");

$mdb->set_context("creator", "", "eService Production");




my $rc = 0;
my @errors;
my $rel_name = "Document Structure";

my $where = qq(last == revision);

my ($bo1) = eMatrix::BizObj::query_businessobject("Document", 
                                                  "steve1", "A", 
                                                  $where);

my ($bo2) = eMatrix::BizObj::query_businessobject("Document", 
                                                  "steve1", "B",
                                                  $where);

print "From:\n";
print $bo1->get_type(), " ", $bo1->get_name(), " ", $bo1->get_rev(), 
      ": ", $bo1->get_oid(), "\n";

print "To:\n";
print $bo2->get_type(), " ", $bo2->get_name(), " ", $bo2->get_rev(), 
      ": ", $bo2->get_oid(), "\n";


$rc = $bo1->connect_businessobject(
                                   $bo2,
                                   $rel_name
                                  );

if ($rc) {
   @errors = $mdb->get_error();
   print "Error:\n";
   print join("\n", @errors), "\n";
} else {
   print "Success\n";
}



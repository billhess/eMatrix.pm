#!/usr/local/jci/perl/bin/perl
####
# Checkin files to a Business Obejcts
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
my @paths    = (
                "/tmp/test1.doc",
                "/tmp/test2.doc",
                "/tmp/test3.doc",
                );
my $store    = "STORE";
my $format   = "generic";


my ($bo) = eMatrix::BizObj::query_businessobject("Document", 
                                                 "steve1", "A", 
                                                 );

print "BO:\n";
print $bo->get_type(), " ", $bo->get_name(), " ", $bo->get_rev(), 
      ": ", $bo->get_oid(), "\n";


$rc = $bo->checkin_businessobject(
                                  \@paths,
                                  $format,
                                  $store,
                                  );

if ($rc) {
   @errors = $mdb->get_error();
   print "Error:\n";
   print join("\n", @errors), "\n";
} else {
   print "Success\n";
}



$mdb->disconnect;



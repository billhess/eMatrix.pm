#!/usr/local/perl/bin/perl
####
# Creating Business Obejcts
####

use strict;

use eMatrix::DB;
use eMatrix::BizObj;
use eMatrix::Expand;


my $mdb = eMatrix::DB::connect("MATRIX-R",
                               "/app/matrixone/ematrix/scripts");

$mdb->set_context("creator", "", "eService Production");





my $type     = "Document";
my $name     = "steve1";
my $policy   = "Document";
my $rev      = "H";
my $attrs    = {
                description => "Testing Revisions 1",
               };

my %hash     = (
                -type       => $type,
                -name       => $name,
                -revision   => $rev,
                -policy     => $policy,
               );

my $bo = eMatrix::BizObj->new(%hash);

my $rc = $bo->add_businessobject($attrs);

if ($rc != 0) {
   print "Error:\n";
   print join("\n", $mdb->get_error()), "\n";
} else {
   print "Success\n";
   print "BO = ", $bo, "\n";
   foreach (sort keys %$bo) {
      print "   $_ = ", $bo->{$_}, "\n";
   }
}



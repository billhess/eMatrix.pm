#!/usr/local/perl/bin/perl

use strict;

use eMatrix::DB;
use eMatrix::BizObj;
use eMatrix::Expand;


my $mdb = eMatrix::DB::connect("MATRIX-R",
                               "/app/matrixone/ematrix/scripts");

$mdb->set_context("creator", "", "eService Production");



####
# Test 1 -- Listing Business Obejcts
####
if (0) {

my $time2 = time;
my $where = qq(last == revision && attribute[Title] match "image*JPG");

my @bos2 = eMatrix::BizObj::query_businessobject("Document", "auto_*", 
                                                 "*", $where);

print "Found ", scalar @bos2, " Business Objects\n";
print "In ", time - $time2, " seconds\n";

}



####
# Test 2 -- Creating Business Obejcts
####
if (0) {


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

}





####
# Test 3 -- Connecting Business Obejcts
####
if (0) {


my $rc = 0;
my @errors;
my $rel_name = "Document Structure";

my $where = qq(last == revision);

my $bo1 = (eMatrix::BizObj::query_businessobject("Document", 
                                                 "steve1", "A", 
                                                 $where))[0];

my $bo2 = (eMatrix::BizObj::query_businessobject("Document", 
                                                 "steve1", "B",
                                                 $where))[0];

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

}






####
# Test 4 -- Expand Business Obejcts
####

my $type     = "Workspace Vault";
my $name     = "007_fuel_economy_p85";
my $revision = "auto_*";
my $rel_name = "";
my $recurse  = "5";
my $to_from  = "";

my $rel_exp  = "Workspace Vaults";

my $start_bo = (eMatrix::BizObj::query_businessobject($type, 
                                                      $name, 
                                                      $revision))[0];

my $expand = $start_bo->expand_businessobject($rel_name, 
                                 $recurse, $to_from);

print "Starting Business Object:\n";
print "'", $start_bo->get_type(), "' '", $start_bo->get_name(), "' '",
      $start_bo->get_rev(), "'\n";

print "***DUMP*******************************\n";
print $expand->dump;
print "***DUMP*******************************\n";


my $start_bo2 = $expand->get_start();

my @related_bos = $expand->get_from($start_bo2, $rel_exp);

print scalar @related_bos, " business objects related via '$rel_exp'\n"; 
foreach my $bo (@related_bos) {
   print "  '", $bo->get_type(), "' '", $bo->get_name(), "' '";
   print $bo->get_rev(), "' \n";

   my @related_children = $expand->get_to($bo, "*");

   print scalar @related_children, " business objects related via 'TO'\n"; 
   foreach my $boc (@related_children) {
      print "  '", $boc->get_type(), "' '", $boc->get_name(), "' '";
      print $boc->get_rev(), "' \n";
   }

   @related_children = $expand->get_from($bo, "*");

   print scalar @related_children, " business objects related via 'FROM'\n"; 
   foreach my $boc (@related_children) {
      print "  '", $boc->get_type(), "' '", $boc->get_name(), "' '";
      print $boc->get_rev(), "' \n";
   }


}





$mdb->disconnect();



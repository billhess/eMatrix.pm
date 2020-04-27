#!/usr/local/jci/perl/bin/perl
####
# Test 4 -- Expand Business Obejcts
####

use strict;

use eMatrix::DB;
use eMatrix::BizObj;
use eMatrix::Expand;


my $mdb = eMatrix::DB::connect("MATRIX-R",
                               "/app/matrixone/ematrix/scripts");

$mdb->set_context("creator", "", "eService Production");



my $type     = "Workspace Vault";
my $name     = "007_fuel_economy_p85";
my $revision = "auto_*";
my $rel_name = "";
my $recurse  = "4";
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


if (0) {
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
}





$mdb->disconnect();



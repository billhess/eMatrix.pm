#!/usr/local/jci/perl/bin/perl

####
# Listing Business Obejcts
####

use strict;

use eMatrix::DB;
use eMatrix::BizObj;
use eMatrix::Expand;


my $mdb = eMatrix::DB::connect("MATRIX-R",
                               "/app/matrixone/ematrix/scripts");

$mdb->set_context("creator", "", "eService Production");


my $time2 = time;
my $where = qq(last == revision && attribute[Title] match "image*JPG");

my @bos2 = eMatrix::BizObj::query_businessobject("Document", "auto_*", 
                                                 "*", $where);

print "Found ", scalar @bos2, " Business Objects\n";
print "In ", time - $time2, " seconds\n";




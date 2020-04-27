#!/usr/local/jci/perl/bin/perl
####
# Testing Context
####

use strict;

use eMatrix::DB;
use eMatrix::BizObj;
use eMatrix::Expand;

$| = 1;

my ($context, $person, $vault);

my $mdb = eMatrix::DB::connect("MATRIX-R",
                               "/app/matrixone/ematrix/scripts");

print "Context after initial Connection...\n";
$context = $mdb->get_context();
$person  = $context->get_person();
$vault   = $context->get_vault();

#print "Context = '", $context, "'\n";
#print "Person  = '", $person, "'\n";
#print "Vault   = '", $vault, "'\n";

print "Person = '", $person->get_name(), "'\n" if $person;
print "Vault  = '", $vault->get_name(), "'\n" if $vault;


print "\nSetting Context to p:creator, v:eService Production\n";
$mdb->set_context("creator", "", "eService Production");

$context = $mdb->get_context();
$person  = $context->get_person();
$vault   = $context->get_vault();

#print "Context = '", $context, "'\n";
#print "Person  = '", $person, "'\n";
#print "Vault   = '", $vault, "'\n";

print "Person = '", $person->get_name(), "'\n";
print "Vault  = '", $vault->get_name(), "'\n";


print "\nPushing Context to p:Test Everything, v:ADMINISTRATION\n";
$mdb->push_context("Test Everything", "", "ADMINISTRATION");

$context = $mdb->get_context();
$person  = $context->get_person();
$vault   = $context->get_vault();

#print "Context = '", $context, "'\n";
#print "Person  = '", $person, "'\n";
#print "Vault   = '", $vault, "'\n";

print "Person = '", $person->get_name(), "'\n";
print "Vault  = '", $vault->get_name(), "'\n";


print "\nPushing Context to v:eService Production\n";
$mdb->push_context("", "", "eService Production");

$context = $mdb->get_context();
$person  = $context->get_person();
$vault   = $context->get_vault();

#print "Context = '", $context, "'\n";
#print "Person  = '", $person, "'\n";
#print "Vault   = '", $vault, "'\n";

print "Person = '", $person->get_name(), "'\n";
print "Vault  = '", $vault->get_name(), "'\n";



print "\nPopping Context\n";
$mdb->pop_context();

$context = $mdb->get_context();
$person  = $context->get_person();
$vault   = $context->get_vault();

print "Person = '", $person->get_name(), "'\n";
print "Vault  = '", $vault->get_name(), "'\n";



print "\nPopping Context\n";
$mdb->pop_context();

$context = $mdb->get_context();
$person  = $context->get_person();
$vault   = $context->get_vault();

print "Person = '", $person->get_name(), "'\n";
print "Vault  = '", $vault->get_name(), "'\n";



$mdb->disconnect;

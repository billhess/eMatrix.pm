#======================================================================
# NAME:  eMatrix::Person
#
# DESC:  
#
# VARS:  
#
#======================================================================
# Copyright 2002 - Technology Resource Group LLC as an unpublished work
#======================================================================
package eMatrix::Person;

use strict;

#----------------------------------------------------------------------
# Load both MQL and MQL::SOAP modules if available
#----------------------------------------------------------------------
BEGIN {
   my %mql_found = undef;
   for (qw(MQL MQL::SOAP)) {
      if(eval "use $_") {
         $mql_found{$_} = 1;
      }
   }
   
   die "Cannot find any MQL Modules..." unless %mql_found;
}

use eMatrix::DB;
use eMatrix::Group;


my %objs = ();
my @wcs  = ();  


#======================================================================
# NAME:  new() 
#
# DESC:  Creates new eMatrix Person Object
#
# ARGS:  Attribute hash:
#        -name       str
#        -desc       str
#        -hidden     int
#        -abstract   int
#
# RET:   TYPE Object
#
# HIST:  
#
#======================================================================
sub new {
   my ($class, %args) = @_;

   my $self = bless \%args, $class;

   $objs{$self->{-name}} = $self;

   return $self;
}



#======================================================================
# NAME:  Attribute Return Methods 
#
# DESC:  Methods to return each attribute value for a Person
#
# HIST:  
#
#======================================================================
sub get_name {
   my ($self) = @_;
   return $self->{-name};
}

sub get_description {
   my ($self) = @_;
   return $self->{-description};
}

sub is_hidden {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-hidden}};
}

sub is_person {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-isaperson}};
}

sub is_group {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-isagroup}};
}

sub is_role {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-isarole}};
}

sub has_business {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-business}};
}

sub has_system {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-system}};
}



#======================================================================
# NAME:  list_person() 
#
# DESC:  Gets a list of Person objects
#        First check if the objects have already been created
#        using the Person name as the unique ID - if not then make a call 
#        to MQL and create the objects
#
# ARGS:  person - A wildcardable string using a "*" for the 
#                  Persons to match by name
#        needy  - Create new objects even if the already exists
#
# RET:   List of Person Objects
#
# HIST:  
#
#======================================================================
sub list_person {
   my ($mdb, $name, $needy) = @_;

   $name  = "*" if $name  eq "";

   my @list  = ();
   my $domql = 1;

   if($name =~ /\*/) {
      my $expr = $name;
      $expr =  "*" if $expr =~ /^\*+$/;
      $expr =~ s/([^a-zA-Z0-9_*])/\\$1/g; 
      $expr =  "^" . $expr  if $expr !~ /^\*/;
      $expr =  $expr . "\$" if $expr !~ /\*$/;
      $expr =~ s/\*/\.\*/g;

      if(grep /^$expr$/, @wcs) {
         foreach (keys %objs) {
            push @list, $objs{$_} if $_ =~ /$expr/;
         }
         
         $domql = 0;
      }
      else {
         push @wcs, $name;
      }
   }
   elsif(defined($objs{$name})) {
      push @list, $objs{$name};
      $domql = 0;
   }


   my $rc;
   my @output;
   my @error;
   
   if($domql) {
      if($mdb->{-mql}) {
         my %r = $mdb->{-mql}->execute(qq(list person "$name" select *));

         $rc     = $r{-rc};
         @output = @{$r{-output}};
         @error  = @{$r{-error}};
        
         $mdb->set_error(@output);
      }
      else {
         $mdb->set_error("Error: #999: Not connected to MQL");
      }
      

      if(! $rc) {
         my $first = 1;
         my (%hash, $c, $key, $val);
         
         foreach (@output) {	 
            if($_ =~ /^person /i) {
               push @list, eMatrix::Person->new(%hash) if ! $first;
               $first = 0;
               
               %hash = (-mdbh                => $mdb,
                        -name                => "",
                        -description         => "",
                        -hidden              => "",
                        -id                  => "",
                        -modified            => "",
                        -originated          => "",
                        -mask                => "",
                        -admin               => "",
                        -email               => "",
                        -isaperson           => "",
                        -isagroup            => "",
                        -isarole             => "",
                        -fullname            => "",
                        -phone               => "",
                        -fax                 => "",
                        -address             => "",
                        -full                => "",
                        -business            => "",
                        -system              => "",
                        -inactive            => "",
                        -vault               => "",
                        -lattice             => "",
                        -assignment          => [],
                        -property            => [],
                       );
               next;
            }
            else {
               $c   = index $_, " = ";
               $key = substr $_, 0, $c;
               $val = substr $_, $c+3;
               
               $key =~ s/^\s+/\-/;
               
               if(ref($hash{$key}) eq "ARRAY") {
                  push @{$hash{$key}}, $val;
               }
               else {
                  $hash{$key} = $val;
               }
            }
         }

         push @list, eMatrix::Person->new(%hash) if $hash{-name} ne "";
      }
   }


   return @list;
}




#======================================================================
# End of eMatrix::Person
#======================================================================
1;

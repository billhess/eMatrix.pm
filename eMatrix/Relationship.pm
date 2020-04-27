#======================================================================
# NAME:  eMatrix::Relationship
#
# DESC:  
#
# VARS:  
#
#======================================================================
# Copyright 2002 - Technology Resource Group LLC as an unpublished work
#======================================================================
package eMatrix::Relationship;

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
use eMatrix::Type;
use eMatrix::Attribute;


my %objs = ();
my @wcs  = ();  


#======================================================================
# NAME:  new() 
#
# DESC:  Creates new eMatrix Relationship Object
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
# DESC:  Methods to return each attribute value for a Relationship
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

sub is_abstract {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-abstract}};
}

sub get_fromcardinality {
   my ($self) = @_;
   return $eMatrix::DB::card{$self->{-fromcardinality}};
}

sub get_tocardinality {
   my ($self) = @_;
   return $eMatrix::DB::card{$self->{-tocardinality}};
}



#======================================================================
# NAME:  get_fromtype() 
#
# DESC:  Gets a list of Type objects based on -fromtype
#
# ARGS:  NONE
#
# RET:   List of Type Objects
#
# HIST:  
#
#======================================================================
sub get_fromtype {
   my ($self) = @_;

   my @list = ();

   foreach (@{$self->{-fromtype}}) {
      push @list, eMatrix::Type::list_type($_);
   }

   return @list;
}



#======================================================================
# NAME:  get_totype() 
#
# DESC:  Gets a list of Type objects based on -totype
#
# ARGS:  NONE
#
# RET:   List of Type Objects
#
# HIST:  
#
#======================================================================
sub get_totype {
   my ($self) = @_;

   my @list = ();

   foreach (@{$self->{-totype}}) {
      push @list, eMatrix::Type::list_type($_);
   }

   return @list;
}



#======================================================================
# NAME:  get_attributes() 
#
# DESC:  Gets a list ATTRIBUTE objects
#        based on this Relationship's Attributes, and Immediate attributes
#
# ARGS:  NONE
#
# RET:   List of ATTRIBUTE Objects
#
# HIST:  
#
#======================================================================
sub get_attributes {
   my ($self) = @_;

   my @list = ();

   foreach (@{$self->{-attribute}}) {
      push @list, eMatrix::Attribute::list_attribute($_);
   }

   foreach (@{$self->{-immediateattribute}}) {
      push @list, eMatrix::Attribute::list_attribute($_);
   }

   return @list;
}



#======================================================================
# NAME:  list_relationship() 
#
# DESC:  Gets a list of Relationship objects
#        First check if the objects have already been created
#        using the Relationship name as the unique ID - if not then make a call 
#        to MQL and create the objects
#
# ARGS:  rel   - A wildcardable string using a "*" for the 
#                 Relationship's to match by name
#        needy - Create new objects even if the already exists
#
# RET:   List of Relationship Objects
#
# HIST:  
#
#======================================================================
sub list_relationship {
   my ($mdb, $rel, $needy) = @_;

   $rel  = "*" if $rel  eq "";

   my @list  = ();
   my $domql = 1;

   if($rel =~ /\*/) {
      my $expr = $rel;
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
         push @wcs, $rel;
      }
   }
   elsif(defined($objs{$rel})) {
      push @list, $objs{$rel};
      $domql = 0;
   }


   my $rc;
   my @output;
   my @error;
   
   if($domql) {
      if($mdb->{-mql}) {
         my %r = $mdb->{-mql}->execute(qq(list relationship "$rel" select *));
         
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
            if($_ =~ /^relationship type/i) {
               push @list, eMatrix::Relationship->new(%hash) if ! $first;
               $first = 0;
               
               %hash = (-mdbh                => $mdb,
                        -name                => "",
                        -description         => "",
                        -hidden              => "",
                        -id                  => "",
                        -modified            => "",
                        -originated          => "",
                        -sparse              => "",
                        -abstract            => "",
                        -frommeaning         => "",
                        -fromcardinality     => "",
                        -fromaction          => "",
                        -fromreviseaction    => "",
                        -fromcloneaction     => "",
                        -tomeaning           => "",
                        -tocardinality       => "",
                        -toaction            => "",
                        -toreviseaction      => "",
                        -tocloneaction       => "",
                        -preventduplicates   => "",
                        -warnduplicates      => "",
                        -attribute           => [],
                        -immediateattribute  => [],
                        -property            => [],
                        -fromtype            => [],
                        -totype              => [],
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

         push @list, eMatrix::Relationship->new(%hash) if $hash{-name} ne "";
      }
   }


   return @list;
}




#======================================================================
# End of eMatrix::Relationship
#======================================================================
1;

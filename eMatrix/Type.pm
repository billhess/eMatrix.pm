#======================================================================
# NAME:  eMatrix::Type
#
# DESC:  
#
# VARS:  
#
#======================================================================
# Copyright 2002 - Technology Resource Group LLC as an unpublished work
#======================================================================
package eMatrix::Type;

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
use eMatrix::Attribute;
use eMatrix::Policy;


my %objs = ();
my @wcs  = ();  


#======================================================================
# NAME:  new() 
#
# DESC:  Creates new eMatrix TYPE Object
#
# ARGS:  Attribute hash:
#        -name       str
#        -desc       str
#        -hidden     int
#        -abstract   int
#        -derived    str (Name of another TYPE)
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
# DESC:  Methods to return each attribute value for a TYPE
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

sub get_id {
   my ($self) = @_;
   return $self->{-id};   
}

sub get_modified {
   my ($self) = @_;
   return $self->{-modified};   
}

sub get_originated {
   my ($self) = @_;
   return $self->{-originated};   
}

sub get_sparse {
   my ($self) = @_;
   return $self->{-sparse};   
}

sub is_abstract {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-abstract}};
}

sub get_properties{
   my ($self) = @_;
   return keys %{$self->{-property}};
}

sub get_property{
   my ($self, $prop) = @_;
   return $self->{-property}->{$prop};
}



#======================================================================
# NAME:  get_derived() 
#
# DESC:  Gets the Type from which this Type was derived
#
# ARGS:  NONE
#
# RET:   Type Object
#
# HIST:  
#
#======================================================================
sub get_derived {
   my ($self) = @_;

   if($self->is_abstract()) {
      return list_type($self->{-derived});
   }
   else {
      return "";
   }
}




#======================================================================
# NAME:  get_attributes() 
#
# DESC:  Gets a list ATTRIBUTE objects
#        based on this Type's Attributes, and Immediate attributes
#
# ARGS:  NONE
#
# RET:   List of ATTRIBUTE Objects
#
# HIST:  
#
#======================================================================
sub get_immediateattributes {
   my ($self) = @_;

   my @list = ();
   
   foreach (@{$self->{-immediateattribute}}) {
      push @list, eMatrix::Attribute::list_attribute($self->{-mdbh}, $_);
   }

   return @list;
}

sub get_attributes {
   my ($self) = @_;

   my @list = ();

   foreach (@{$self->{-attribute}}) {
      push @list, eMatrix::Attribute::list_attribute($self->{-mdbh}, $_);
   }

   return @list;
}

sub get_allattributes {
   my ($self) = @_;

   my @list = ();

   push @list, $self->get_attributes();
   push @list, $self->get_immediateattributes();

   return @list;
}



#======================================================================
# NAME:  get_fromrelationships() 
#
# DESC:  Gets a list of Relationship objects that connect from this Type
#
# ARGS:  NONE
#
# RET:   List of Relationship Objects
#
# HIST:  
#
#======================================================================
sub get_fromrelationships {
   my ($self) = @_;

   my @list = ();

   foreach (@{$self->{-fromrel}}) {
      push(@list, 
           eMatrix::Relationship::list_relationship($self->{-mdbh}, $_));
   }
   
   return @list;
}

sub get_torelationships {
   my ($self) = @_;

   my @list = ();

   foreach (@{$self->{-torel}}) {
      push(@list, 
           eMatrix::Relationship::list_relationship($self->{-mdbh}, $_));
   }

   return @list;
}

sub get_relationships {
   my ($self) = @_;

   my @list = ();

   push @list, $self->get_fromrelationships();
   push @list, $self->get_torelationships();

   return @list;
}



#======================================================================
# NAME:  get_policy() 
#
# DESC:  Gets a list of Policy objects that connect to this Type
#
# ARGS:  NONE
#
# RET:   List of Policy Objects
#
# HIST:  
#
#======================================================================
sub get_policy {
   my ($self) = @_;

   my @list = ();

   foreach (@{$self->{-policy}}) {
      push @list, eMatrix::Policy::list_policy($self->{-mdbh}, $_);
   }

   return @list;
}





#======================================================================
# NAME:  list_type() 
#
# DESC:  Gets a list of TYPE objects
#        First check if the objects have already been created
#        using the TYPE name as the unique ID - if not then make a call 
#        to MQL and create the objects
#
# ARGS:  type  - A wildcardable string using a "*" for the 
#                 TYPE's to match by name
#        needy - Create new objects even if the already exists
#
# RET:   List of TYPE Objects
#
# HIST:  
#
#======================================================================
sub list_type {
   my ($mdb, $type, $needy) = @_;

   $type  = "*" if $type  eq "";

   my @list  = ();
   my $domql = 1;

   if($type =~ /\*/) {
      my $expr = $type;
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
         push @wcs, $type;
      }
   }
   elsif(defined($objs{$type})) {
      push @list, $objs{$type};
      $domql = 0;
   }


   my $rc;
   my @output;
   my @error;
   
   if($domql) {
      if($mdb->{-mql}) {
         my %r = $mdb->{-mql}->execute(qq(list type "$type" select *));
         
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
            if($_ =~ /^business type/i) {
               push @list, eMatrix::Type->new(%hash) if ! $first;
               $first = 0;
               
               %hash = (-mdbh                => $mdb,
                        -name                => "",
                        -description         => "",
                        -hidden              => "",
                        -id                  => "",
                        -modified            => "",
                        -originated          => "",
                        -derived             => "",
                        -sparse              => "",
                        -abstract            => "",
                        -property            => {},
                        -attribute           => [],
                        -immediateattribute  => [],
                        -policy              => [],
                        -fromrel             => [],
                        -torel               => []);
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
               elsif(ref($hash{$key}) eq "HASH") {
                  if($key eq "-property") {
                     my ($n, $v) = split /\s+value\s+/, $val;
                     $hash{$key}->{$n} = $v;
                  }
               }
               else {
                  $hash{$key} = $val;
               }
            }
         }

         push @list, eMatrix::Type->new(%hash) if $hash{-name} ne "";
      }
   }


   return @list;
}




#======================================================================
# End of eMatrix::Type
#======================================================================
1;

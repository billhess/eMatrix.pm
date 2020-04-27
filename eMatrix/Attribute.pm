#======================================================================
# NAME:  eMatrix::Attribute
#
# DESC:  
#
# VARS:  
#
#======================================================================
# Copyright 2002 - Technology Resource Group LLC as an unpublished work
#======================================================================
package eMatrix::Attribute;

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




my %objs = ();
my @wcs  = ();  


#======================================================================
# NAME:  new() 
#
# DESC:  Creates new eMatrix ATTRIBUTE Object
#
# ARGS:  Attribute hash:
#        -name       str
#        -desc       str
#        -hidden     int
#        -abstract   int
#        -derived    str (Name of another TYPE)
#
# RET:   ATTRIBUTE Object
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
# DESC:  Methods to return each attribute value for a ATTRIBUTE
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
   return $self->{-hidden};
}

sub get_range {
   my ($self) = @_;
   return @{$self->{-range}};
}




#======================================================================
# NAME:  list_attribute() 
#
# DESC:  Gets a list of ATTRIBUTE objects
#        First check if the objects have already been created
#        using the ATTRIBUTE name as the unique ID - if not then make 
#        a call to MQL and create the objects
#
# ARGS:  type - A wildcardable string using a "*" for the 
#               ATTRIBUTE's to match by name
#
# RET:   List of ATTRIBUTE Objects
#
# HIST:  
#
#======================================================================
sub list_attribute {
   my ($mdb, $attr, $needy) = @_;

   $attr = "*" if $attr eq "";

   my @list  = ();
   my $domql = 1;

   if($attr =~ /\*/) {
      my $expr = $attr;
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
         push @wcs, $attr;
      }
   }
   elsif(defined($objs{$attr})) {
      push @list, $objs{$attr};
      $domql = 0;
   }



   my $rc;
   my @output;
   my @error;


   if($domql) {
      if($mdb->{-mql}) {
         my %r = $mdb->{-mql}->execute(qq(list attribute "$attr" select *));

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
            if($_ =~ /^attribute type/i) {
               push @list, eMatrix::Attribute->new(%hash) if ! $first;
               $first = 0;
               
               %hash = (-mdbh                => $mdb,
                        -name                => "",
                        -description         => "",
                        -hidden              => "",
                        -id                  => "",
                        -modified            => "",
                        -originated          => "",
                        -default             => "",
                        -multiline           => "",
                        -type                => "",
                        -property            => [],
                        -range               => []);
               
               next;
            }
            else {
               $c   = index  $_, " = ";
               $key = substr $_, 0, $c;
               $val = substr $_, $c+3;
               
               $key =~ s/^\s+/\-/;
               $key = "-range" if $key =~ /^\-range/i;
               
               if(ref($hash{$key}) eq "ARRAY") {
                  push @{$hash{$key}}, $val;
               }
               else {
                  $hash{$key} = $val;
               }
            }
         }

         push @list, eMatrix::Attribute->new(%hash) if $hash{-name} ne "";
      }
   }


   return @list;
}







#======================================================================
# End of eMatrix::Attribute
#======================================================================
1;

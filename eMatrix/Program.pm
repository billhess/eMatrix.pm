#======================================================================
# NAME:  eMatrix::Program
#
# DESC:  
#
# VARS:  
#
#======================================================================
# Copyright 2002 - Technology Resource Group LLC as an unpublished work
#======================================================================
package eMatrix::Program;

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


my %objs = ();
my @wcs  = ();  


#======================================================================
# NAME:  new() 
#
# DESC:  Creates new eMatrix Program Object
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
# DESC:  Methods to return each attribute value for a Program
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

sub is_mql {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-ismqlprogram}};
}

sub is_java {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-isjavaprogram}};
}

sub is_piped {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-ispipedprogram}};
}

sub need_context {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-doesneedcontext}};
}

sub is_wizard {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-iswizardprogram}};
}

sub use_interface {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-doesuseinterface}};
}

sub is_method {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-isamethod}};
}

sub is_function {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-isafunction}};
}



#======================================================================
# NAME:  get_code() 
#
# DESC:  Gets the code associated with this Program
#
# ARGS:  NONE
#
# RET:   Actual code of the Program
#
# HIST:  
#
#======================================================================
sub get_code {
   my ($self) = @_;

   return $self->{-code};
}



#======================================================================
# NAME:  list_program() 
#
# DESC:  Gets a list of Program objects
#        First check if the objects have already been created
#        using the Program name as the unique ID - if not then make a call 
#        to MQL and create the objects
#
# ARGS:  name   - A wildcardable string using a "*" for the 
#                  Programs to match by name
#        needy  - Create new objects even if the already exists
#
# RET:   List of Program Objects
#
# HIST:  
#
#======================================================================
sub list_program {
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
         my %r = $mdb->{-mql}->execute(qq(list program "$name" select *));
      
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
         
         while (my $line = shift @output) {
            if($line =~ /^program /i) {
               push @list, eMatrix::Program->new(%hash) if ! $first;
               $first = 0;
               
               %hash = (-mdbh                => $mdb,
                        -name                => "",
                        -description         => "",
                        -hidden              => "",
                        -id                  => "",
                        -modified            => "",
                        -originated          => "",
                        -ismqlprogram        => "",
                        -isjavaprogram       => "",
                        -ispipedprogram      => "",
                        -doesneedcontext     => "",
                        -iswizardprogram     => "",
                        -doesuseinterface    => "",
                        -execute             => "",
                        -isamethod           => "",
                        -isafunction         => "",
                        -store               => "",
                        -islockingenforced   => "",
                        -code                => "",
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
                  if ($key eq "-code") {
                     $hash{$key} = $val;
                     my $newline = shift (@output) . "\n";
                     while (!($newline =~ /downloadable \=/)) {
                        $hash{$key} .= $newline."\n";
                        $newline = shift @output;
                     }
                     unshift @output, $newline;
                  } else {
                     $hash{$key} = $val;
                  }
               }
            }
         }

         push @list, eMatrix::Program->new(%hash) if $hash{-name} ne "";
      }
   }


   return @list;
}




#======================================================================
# End of eMatrix::Program
#======================================================================
1;

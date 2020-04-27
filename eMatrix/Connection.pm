#======================================================================
# NAME:  eMatrix::Connection
#
# DESC:  eMatrix Connection is the instance of a Relationship.  A
#        Connection exists only when two Business Objects are related
#        The ways to list the properties of a Connection are by either
#        looking it up by the OID, or by looking at two BO's connected 
#
# VARS:  objs
#        wcs
#
#======================================================================
# Copyright 2002 - Technology Resource Group LLC as an unpublished work
#======================================================================
package eMatrix::Connection;

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

use File::Basename;
use eMatrix::Expand;

use vars qw(%objs);

%objs    = ();
my @wcs  = ();  




#======================================================================
# NAME:  new() 
#
# DESC:  Creates new eMatrix Connection Object
#
# ARGS:  Attribute hash:
#        -name       str
#        -desc       str
#        -hidden     int
#        -abstract   int
#
# RET:   Connection Object
#
# HIST:  
#
#======================================================================
sub new {
   my ($class, %args) = @_;

   my $self = bless \%args, $class;

   $objs{$self->{-id}} = $self;

   return $self;
}



#======================================================================
# NAME:  Attribute Return Methods 
#
# DESC:  Methods to return each attribute value for a Connection Object
#
# HIST:  
#
#======================================================================
sub get_oid {
   my ($self) = @_;
   return $self->{-id};
}

sub get_id {
   my ($self) = @_;
   return $self->{-id};
}

sub get_type {
   my ($self) = @_;
   return $self->{-type};
}

sub get_name {
   my ($self) = @_;
   return $self->{-name};
}

sub get_rev {
   my ($self) = @_;
   return $self->{-revision};
}

sub get_revision {
   my ($self) = @_;
   return $self->{-revision};
}

sub is_locked {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-locked}};
}





#======================================================================
# NAME:  Attribute Set Methods 
#
# DESC:  Methods to set values for a Connection Object
#
# HIST:  
#
#======================================================================
sub set_oid {
   my ($self, $oid) = @_;
   $self->{-id}  = $oid;
}

sub set_id {
   my ($self, $id) = @_;
   $self->{-id}  = $id;
}

sub set_type {
   my ($self, $type) = @_;
   $self->{-type} = $type;
}

sub set_name {
   my ($self, $name) = @_;
   $self->{-name} = $name;
}

sub set_rev {
   my ($self, $rev) = @_;
   $self->{-revision} = $rev;
}

sub set_revision {
   my ($self, $rev) = @_;
   $self->{-revision} = $rev;
}



#======================================================================
# NAME:  print_connection() 
#
# DESC:  Gets a single Connection object
#
# ARGS:  oid    - The Matrix Business Object OID
#        select - Ref to a Hash which contains all the selectables
#        needy  - Create new objects even if the already exists
#
# RET:   eMatrix::Connection Object
#
# HIST:  
#
#======================================================================
sub print_connection {
   if (ref $_[0] eq "eMatrix::BizObj") {
      return print_conn_bizobj(@_);
   }
   else {
      return print_conn_oid(@_);
   }
}




#======================================================================
# NAME:  print_conn_bizobj() 
#
# DESC:  Gets a single Connection object from two BizObj's
#
# ARGS:  from_bo  - from Side of the relationship BO
#        to_bo    - To side of the relationship BO
#        relation - The Relationship Object
#
# RET:   eMatrix::Connection Object
#
# HIST:  
#
#======================================================================
sub print_conn_bizobj {
   my ($mdb, $from_bo, $to_bo, $relation, $select, $needy) = @_;

   my $obj = undef;

   #-----------------------------------------------------------------
   # MQL Usage:
   #
   # print connection from OBJECTID to OBJECTID relationship RELTYPE;
   #
   #-----------------------------------------------------------------
   my $mql = qq(print connection 
                from         "$from_bo->get_oid()" 
                to           "$to_bo->get_oid()"
                relationship "$relation->get_name()"
                select id type name revision );

   foreach (keys %$select) {
      next if $_ eq "-attribute" || $_ eq "-files";

      $mql .= substr($_, 1)." ";
   }

   if (defined $select->{-attribute}) {
      if (! ref $select->{-attribute}) {
         if ($select->{-attribute} eq "*") {
            $mql .= qq(attribute.* );
         }
         else {
            $mql .= qq(attribute$select->{-attribute} );
         }
      }
      else {
         foreach (@{$select->{-attribute}}) {
            $mql .= qq(attribute$_ );
         }
      }
   }

   if (defined $select->{-files}) {
      $mql .= qq(format.file.* );
   }


   #my $mql = qq(print bus "$oid" 
   #             select id type name revision
   #             next first last originated modified
   #             description policy state current owner
   #             vault attribute.* revisions history
   #             locked locker format.file );

   print "MQL = \n$mql\n" if $mdb->{-debug};

   
   my $rc;
   my @output;
   my @error;

   if($mdb->{-mql}) {
      my %r = $mdb->{-mql}->execute($mql);

      $rc     = $r{-rc};
      @output = @{$r{-output}};
      @error  = @{$r{-error}};

      $mdb->set_error(@output);
   }
   else {
      $mdb->set_error("Error: #999: Not connected to MQL");
   }


   if(! $rc) {
      my (%hash, $c, $key, $val);
      
      foreach (@output) {
         if($_ =~ /^connection  /) {
            
            %hash = (-mdbh                => $mdb,
                     -id                  => "",
                     -type                => "",
                     -name                => "",
                     -businessobject      => "",
                     -to                  => "",
                     -from                => "",
                     -isfrozen            => ""
                     -propagatemodifyto   => "",
                     -propagatemodifyfrom => "",
                     -rule                => "",
                     -context             => "",
                     -originated          => "",
                     -attribute           => {},
                     -history             => [],
                     );
            next;
         }
         else {
            $c   = index $_, " = ";
            $key = substr $_, 0, $c;
            $val = substr $_, $c+3;
               
            $key =~ s/^\s+/\-/;

            if ($key =~ /^\-attribute\[.*\]/) {
               #-------------------------------------------------------
               # For now, we only care about the Attribute Values
               #-------------------------------------------------------
               if ($key =~ /^\-attribute\[(.*)\]\.value$/) {
                  $key =~ s/^\-attribute\[(.*)\]\.value$/$1/;
                  $hash{-attribute}->{$key} = $val;
               }
            }
            elsif ($key =~ /^\-format\.file\.host/) {
               push @{$hash{-files_host}}, $val;
            }
            elsif ($key =~ /^\-format\.file\.path/) {
               push @{$hash{-files_path}}, $val;
            }
            elsif ($key =~ /^\-format\.file\.name/) {
               push @{$hash{-files}}, $val;
               push @{$hash{-files_name}}, $val;
            }
            elsif ($key =~ /^\-format\.file\.size/) {
               push @{$hash{-files_size}}, $val;
            }
            elsif(ref($hash{$key}) eq "ARRAY") {
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
      
      $obj = eMatrix::Connection->new(%hash);
   }


   return $obj;
}






#======================================================================
# NAME:  print_conn_oid() 
#
# DESC:  Gets a single Connection object from the OID of the Rel
#
# ARGS:  oid  - The OID of the Connection
#
# RET:   eMatrix::Connection Object
#
# HIST:  
#
#======================================================================
sub print_conn_oid {
   my ($mdb, $oid, $select, $needy) = @_;

   return $objs{$oid} if (! $needy) && (defined $objs{$oid});

   my $obj = undef;

   #-----------------------------------------------------------------
   # MQL Usage:
   #
   # print connection from OBJECTID to OBJECTID relationship RELTYPE;
   #
   #-----------------------------------------------------------------
   my $mql = qq(print connection "$oid" select id );

   foreach (keys %$select) {
      next if $_ eq "-attribute" || $_ eq "-files";

      $mql .= substr($_, 1)." ";
   }

   if (defined $select->{-attribute}) {
      if (! ref $select->{-attribute}) {
         if ($select->{-attribute} eq "*") {
            $mql .= qq(attribute.* );
         }
         else {
            $mql .= qq(attribute$select->{-attribute} );
         }
      }
      else {
         foreach (@{$select->{-attribute}}) {
            $mql .= qq(attribute$_ );
         }
      }
   }

   if (defined $select->{-files}) {
      $mql .= qq(format.file.* );
   }


   #my $mql = qq(print bus "$oid" 
   #             select id type name revision
   #             next first last originated modified
   #             description policy state current owner
   #             vault attribute.* revisions history
   #             locked locker format.file );

   print "MQL = \n$mql\n" if $mdb->{-debug};

   my $rc;
   my @output;
   my @error;
   
   if($mdb->{-mql}) {      
      my %r = $mdb->{-mql}->execute($mql);
      
      $rc     = $r{-rc};
      @output = @{$r{-output}};
      @error  = @{$r{-error}};
      
      $mdb->set_error(@output);
   }
   else {
      $mdb->set_error("Error: #999: Not connected to MQL");
   }


   if(! $rc) {
      my (%hash, $c, $key, $val);
         
      foreach (@output) {
         if($_ =~ /^connection /i) {

            %hash = (-mdbh                => $mdb,
                     -id                  => $oid,
                     -type                => "",
                     -name                => "",
                     -revision            => "",
                     -next                => "",
                     -first               => "",
                     -last                => "",
                     -originated          => "",
                     -modified            => "",
                     -description         => "",
                     -policy              => "",
                     -current             => "",
                     -owner               => "",
                     -vault               => "",
                     -locked              => "",
                     -locker              => "",
                     -attribute           => {},
                     -state               => [],
                     -files               => [],
                     -files_host          => [],
                     -files_path          => [],
                     -files_name          => [],
                     -files_size          => [],
                     -revisions           => [],
                     -history             => [],
                     );
            next;
         }
         else {
            $c   = index $_, " = ";
            $key = substr $_, 0, $c;
            $val = substr $_, $c+3;
               
            $key =~ s/^\s+/\-/;

            if ($key =~ /^\-attribute\[.*\]/) {
               #-------------------------------------------------------
               # For now, we only care about the Attribute Values
               #-------------------------------------------------------
               if ($key =~ /^\-attribute\[(.*)\]\.value$/) {
                  $key =~ s/^\-attribute\[(.*)\]\.value$/$1/;
                  $hash{-attribute}->{$key} = $val;
               }
            }
            elsif ($key =~ /^\-format\.file\.host/) {
               push @{$hash{-files_host}}, $val;
            }
            elsif ($key =~ /^\-format\.file\.path/) {
               push @{$hash{-files_path}}, $val;
            }
            elsif ($key =~ /^\-format\.file\.name/) {
               push @{$hash{-files}}, $val;
               push @{$hash{-files_name}}, $val;
            }
            elsif ($key =~ /^\-format\.file\.size/) {
               push @{$hash{-files_size}}, $val;
            }
            elsif(ref($hash{$key}) eq "ARRAY") {
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
      
      $obj = eMatrix::Connection->new(%hash);
   }


   return $obj;
}








#======================================================================
# NAME:  fill_attributes() 
#
# DESC:  fills in the Attribute values for this Connection
#
# ARGS:  self   - This Connection Object
#
# RET:   Nothing
#
# HIST:  
#
#======================================================================
sub fill_attributes {
   my ($self) = @_;

   #-----------------------------------------------------------------
   # MQL Usage:
   #
   # print businessobject BO_NAME [SELECT] [DUMP] [tcl] [output FILENAME];
   # where BO_NAME is:
   #  | TYPE_NAME NAME REVISION [in VAULT] |
   #  | ID                                 |
   #
   # where SELECT is:
   #  | selected                           |
   #  | select [+] FIELD_NAME {FIELD_NAME} |
   #
   # where +:
   #  appends FIELD_NAME(s) to the current selected fields,
   #  otherwise select creates a new select list from FIELD_NAME(s)
   #
   # where FIELD_NAME is:
   #  SUB_FIELD[.SUB_FIELD{.SUB_FIELD}]
   #
   # where SUB_FIELD is:
   #  | string          |
   #  | string[string]  |
   #
   #-----------------------------------------------------------------
   my $mql = qq(print bus "$self->{-id}" select attribute.*);

   my $rc;
   my @output;
   my @error;
   
   if($self->{-mdbh}->{-mql}) {
      my %r = $self->{-mdbh}->{-mql}->execute($mql);
      
      $rc     = $r{-rc};
      @output = @{$r{-output}};
      @error  = @{$r{-error}};
      
      $self->{-mdbh}->set_error(@output);
   }
   else {
      $self->{-mdbh}->set_error("Error: #999: Not connected to MQL");
   }
   
      
   if(! $rc) {
      my ($key, $val);
      $self->{-attributes} = ();
         
      foreach (@output) {
         $_ =~ s/^\s+//;

         if ($_ =~ /^attribute\[(.*)\]\.value = (.*)$/) {
            # chomp $2;
            $self->{-attributes}->{$1} = $2;
         }
         else {
            next;
         }
      }
   }
}










#======================================================================
# End of eMatrix::Connection
#======================================================================
1;

#======================================================================
# NAME:  eMatrix::BizObj
#
# DESC:  eMatrix Business Objects, can be accessed using this Module
#        It treats all Business Objects as generic.  The two major
#        ways to access an existing BO are either by "Type", "Name",
#        and "Revision", or by OID.
#
# VARS:  objs
#        wcs
#
#======================================================================
# Copyright 2002 - Technology Resource Group LLC as an unpublished work
#======================================================================
package eMatrix::BizObj;

use strict;
use Data::Dumper;

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
use eMatrix::DB;
use eMatrix::Expand;
use eMatrix::Policy;

use vars qw($objs);


$objs    = {};
my @wcs  = ();  




#======================================================================
# NAME:  new() 
#
# DESC:  Creates new eMatrix Business Object
#
# ARGS:  Attribute hash:
#        -name       str
#        -desc       str
#        -hidden     int
#        -abstract   int
#
# RET:   Business Object
#
# HIST:  
#
#======================================================================
sub new {
   my ($class, %args) = @_;

   my $self = bless \%args, $class;

   $objs->{$self->{-mql}->{-session}}->{$self->{-id}} = $self;

   return $self;
}



#======================================================================
# NAME:  Attribute Return Methods 
#
# DESC:  Methods to return each attribute value for a Business Object
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

sub update_lock {
   my $self = shift;

   if($self->{-mdbh}->{-mql}) {
      $self->{-mdbh}->{-mql}->update_lock(@_);
   }
   else {
      $self->{-mdbh}->set_error("Error: #999: Not connected to MQL");
   }

   return $self->{-mdbh}->is_error();
}

sub update_lock_batch {
   my $self = shift;

   if($self->{-mdbh}->{-mql}) {
      $self->{-mdbh}->update_lock_batch(@_);
   }
   else {
      $self->{-mdbh}->set_error("Error: #999: Not connected to MQL");
   }

   return $self->{-mdbh}->is_error();
}

sub is_locked {
   my ($self) = @_;
   return $eMatrix::DB::bool{$self->{-locked}};
}



#======================================================================
# NAME:  Attribute Set Methods 
#
# DESC:  Methods to set values for a Business Object
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
# NAME:  add_businessobject() 
#
# DESC:  Creates a Business object in Matrix 
#        make a call to MQL and create the object
#
# ARGS:  self   - eMatrix::BizObj Object
#        attrs  - A hash of name/value pairs to attach to the new
#                 Business Object
#
# RET:   Return Code
#
# HIST:  
#
#======================================================================
sub add_businessobject {
   my ($self, $attrs) = @_;

   #-----------------------------------------------------------------
   # MQL Usage:
   #
   # add businessobject BO_NAME [ITEM {ITEM}];
   # where BO_NAME is:
   #  | TYPE_NAME NAME REVISION [in VAULT] |
   #  | ID                                 |
   #
   # where ITEM is:
   #  | description VALUE              |
   #  | image FILENAME                 |
   #  | vault VAULT_NAME               |
   #  | name NAME [revision REVISION]  |
   #  | owner USER_NAME                |
   #  | policy POLICY_NAME             |
   #  | state STATE_NAME schedule DATE |
   #  | type TYPE_NAME                 |
   #  | ATTRIBUTE_NAME VALUE           |
   #
   #-----------------------------------------------------------------
   my $mql = qq(add bus "$self->{-type}" "$self->{-name}" );
   $mql   .= qq("$self->{-revision}" );

   if (exists $self->{-policy} && $self->{-policy} ne "") {
      $mql .= qq(policy "$self->{-policy}" );
   }
   
   if (exists $self->{-vault} && $self->{-vault} ne "") {
      $mql .= qq(vault "$self->{-vault}" );
   }

   foreach (keys %$attrs) {
      $mql .= qq( "$_" "$attrs->{$_}" );
   }


   if($self->{-mdbh}->{-mql}) {
      print "MQL = " . scalar localtime() . "\n$mql\n" if $self->{-mdbh}->{-debug};

      my %r = $self->{-mdbh}->{-mql}->execute($mql, 
                                              $self->{-mdbh}->{-context});
      
      $self->{-mdbh}->set_error(@{$r{-output}});

      my ($temp) = eMatrix::BizObj::query_businessobject($self->{-mdbh},
                                                         $self->{-type}, 
                                                         $self->{-name}, 
                                                         $self->{-revision},
                                                         $self->{-vault});
      foreach (keys %$temp) {
         if($self->{$_} eq "") {
            $self->{$_} = $temp->{$_};
         }
      }
   }
   else {
      $self->{-mdbh}->set_error("Error: #999: Not connected to MQL");
   }


   return $self->{-mdbh}->is_error();
}




#======================================================================
# NAME:  connect_businessobject() 
#
# DESC:  Creates a Relationship between two Business objects in Matrix 
#
# ARGS:  self     - The FROM eMatrix::BizObj Object
#        to_bo    - The TO   eMatrix::BizObj Object
#        rel_name - The Relationship name
#        attrs    - A hash ref of name/value pairs to attach to the new
#                   Relationship
#
# RET:   Return Code
#
# HIST:  
#
#======================================================================
sub connect_businessobject {
   my ($self, $to_bo, $rel_name, $attrs) = @_;

   my $from_oid = $self->{-id};
   my $to_oid   = $to_bo->{-id};

   #-----------------------------------------------------------------
   # MQL Usage:
   #
   # connect businessobject BO_NAME relationship NAME to  | BO_NAME
   #                                               | from |
   # [ATTRIBUTE_NAME VALUE {ATTRIBUTE_NAME VALUE}];
   #
   #-----------------------------------------------------------------
   my $mql = qq(connect bus $from_oid relationship "$rel_name" to $to_oid);

   foreach (keys %$attrs) {
      $mql .= qq( "$_" "$attrs->{$_}" );
   }


   if($self->{-mdbh}->{-mql}) {
      print "MQL = " . scalar localtime() . "\n$mql\n" if $self->{-mdbh}->{-debug};

      my %r = $self->{-mdbh}->{-mql}->execute($mql, 
                                              $self->{-mdbh}->{-context});
      
      $self->{-mdbh}->set_error(@{$r{-output}});
   }
   else {
      $self->{-mdbh}->set_error("Error: #999: Not connected to MQL");
   }


   return $self->{-mdbh}->is_error();
}





#======================================================================
# NAME:  expand_businessobject() 
#
# DESC:  Expands a Business Object following Relationships, and passes
#        the Output array to the eMatrix::Expand->new method.
#
# ARGS:  self       - eMatrix::BizObj Object
#        rel_name   - The Wildcarded Relationship name
#        recurse_to - How far to expand
#                     "all", or some number (default = 1)
#        to_from    - Specify which side of the relationship should
#                     contain the starting Object
#                     "from" this BO
#                     "to"   this BO
#        type       - The Business Object Type to retrieve
#        bo_where   - Where clause to filter the results on (for business object)
#        rel_where  - Where clause to filter the results on (for relationship)
#        bo_selects - Ref to a Hash of selectables for the business object
#        rel_selects- Ref to a Hash of selectables for the relationship
#        needy      - Whether to create a new BizObj for each BO
#
# RET:   eMatrix::Expand Object
#
# HIST:  
#
#======================================================================
sub expand_businessobject {
   my ($self, $rel_name, $recurse_to, $to_from, $type,
       $bo_where, $rel_where, $bo_selects, $rel_selects, $needy) = @_;

   my $expand = undef;
   my $bo_sel_mql  = "id type name revision description ";
   my $rel_sel_mql = "id ";


   #-------------------------------------------------------
   # Create the MQL Business Object Selects from the
   # Hash ref $bo_selects
   #-------------------------------------------------------
   foreach (keys %$bo_selects) {
      next if $_ eq "-attribute" || $_ eq "-files";

      $bo_sel_mql .= substr($_, 1)." ";
   }

   if (defined $bo_selects->{-attribute}) {
      if (! ref $bo_selects->{-attribute}) {
         if ($bo_selects->{-attribute} eq "*") {
            $bo_sel_mql .= qq(attribute.value );
         }
         else {
            $bo_sel_mql .= qq(attribute$bo_selects->{-attribute} );
         }
      }
      else {
         foreach (@{$bo_selects->{-attribute}}) {
            $bo_sel_mql .= qq(attribute$_ );
         }
      }
   }

   if (defined $bo_selects->{-files}) {
      $bo_sel_mql .= qq(format.file.* );
   }


   #-------------------------------------------------------
   # Create the MQL Connection Selects from the
   # Hash ref $rel_selects
   #-------------------------------------------------------
   foreach (keys %$rel_selects) {
      next if $_ eq "-attribute" || $_ eq "-files";

      $rel_sel_mql .= substr($_, 1)." ";
   }

   if (defined $rel_selects->{-attribute}) {
      if (! ref $rel_selects->{-attribute}) {
         if ($rel_selects->{-attribute} eq "*") {
            $rel_sel_mql .= qq(attribute.value );
         }
         else {
            $rel_sel_mql .= qq(attribute$rel_selects->{-attribute} );
         }
      }
      else {
         foreach (@{$rel_selects->{-attribute}}) {
            $rel_sel_mql .= qq(attribute$_ );
         }
      }
   }


   #-----------------------------------------------------------------
   # MQL Usage:
   #
   #   expand bus BO_NAME     [| from [relationship PATTERN] [type PATTERN] |]
   #                           | to   [relationship PATTERN] [type PATTERN] |
   #                           | activefilters [reversefilters]             |
   #                           | filter PATTERN [reversefilters]            |
   #   [recurse [to | N   |]] [| | [ into ] | set NAME          |];
   #                | all |      | onto     |
   #                             | [SELECT_BO] [SELECT_REL]     |
   #                             | [DUMP [RECORDSEP]] [tcl] [output FILENAME] |
   #                             | terse                        |
   #                             | structure NAME               |
   #                             | limit N                      |
   #
   #-----------------------------------------------------------------
   my $start_oid = $self->{-id};

   my $mql  = qq(expand bus $start_oid );
   $mql    .= qq(recurse to $recurse_to )    if $recurse_to ne "";
   $mql    .= qq($to_from )                  if $to_from    ne "";
   $mql    .= qq(relationship "$rel_name" )  if $rel_name   ne "";
   $mql    .= qq(type "$type" )              if $type       ne "";
   $mql    .= qq(terse );
   $mql    .= qq(select bus $bo_sel_mql )       if $bo_selects  ne "";
   $mql    .= qq(where '$bo_where' )            if $bo_where    ne "";
   $mql    .= qq(select rel $rel_sel_mql )      if $rel_selects ne "";
   $mql    .= qq(where '$rel_where' )           if $rel_where   ne "";

   print "MQL = \n$mql\n" if $self->{-mdbh}->{-debug};   

   if($self->{-mdbh}->{-mql}) {
      my %r = $self->{-mdbh}->{-mql}->execute($mql, 
                                              $self->{-mdbh}->{-context});
      
      $self->{-mdbh}->set_error(@{$r{-output}});

      if(! $self->{-mdbh}->is_error()) {
         $expand = eMatrix::Expand::new($self->{-mdbh}, $self, 
                                        $needy, $rel_name, @{$r{-output}});
      }
   }
   else {
      $self->{-mdbh}->set_error("Error: #999: Not connected to MQL");
   }

   return $expand;
}







#======================================================================
# NAME:  query_businessobject() 
#
# DESC:  Gets a list of Business objects
#        First check if the objects have already been created
#        using the Busness Objects name as the unique ID - if not then 
#        make a call to MQL and create the objects
#
# ARGS:  type   - The Business Object Type
#        name   - A wildcardable string using a "*" for the 
#                 Business Object's to match by name
#        rev    - The Revision to search for (or LATEST)
#        where  - where clause in string form
#        select - Ref to a Hash which contains all the selectables
#        max    - Maximum number of Business Objects to get
#        needy  - Create new objects even if the already exists
#
# RET:   List of Business Objects
#
# HIST:  
#
#======================================================================
sub query_businessobject {
   my ($mdb, $type, $name, $rev, $vaults, 
       $where, $select, $max, $needy) = @_;

   my @list;

   $type  = "*" if $type  eq "";
   $name  = "*" if $name  eq "";
   $rev   = "*" if $rev   eq "";

   $where = qq(where '$where') if $where ne "";
   $needy = 0 if $needy eq "";
   $max   = qq(limit $max) if $max ne "";


   #-----------------------------------------------------------------
   # MQL Usage:
   #
   # temporary query {ITEM} limit N [SELECT] [!expand] [DUMP] [RECORDSEP] 
   #                 [tcl] [output FILENAME] [querytrigger];
   # where ITEM is:
   #  | businessobject TYPE_PATTERN PATTERN REVISION_PATTERN |
   #  | owner PATTERN                                        |
   #  | vault PATTERN                                        |
   #  | [!|not]expandtype                                    |
   #  | where QUERY_EXPR                                     |
   #
   # where SELECT is:
   #  | selected                           |
   #  | select [+] FIELD_NAME {FIELD_NAME} |
   #
   # where QUERY_EXPR is:
   #  | ( QUERY_EXPR )                             |
   #  | ARITHM_EXPR   RELATIONAL_OP   ARITHM_EXPR  |
   #  | BOOLEAN_EXPR                               |
   #
   # where BOOLEAN_EXPR is:
   #  | QUERY_EXPR   BINARY_BOOLEAN_OP   QUERY_EXPR |
   #  | UNARY_BOOLEAN_OP   QUERY_EXPR               |
   #
   # where ARITHM_EXPR is:
   #  | ( ARITHM_EXPR )                                  |
   #  | ARITHM_EXPR   BINARY_ARITHMETIC_OP   ARITHM_EXPR |
   #  | - ARITHM_EXPR                                    |
   #
   # where RELATIONAL_OP is: 
   #  | LT      |      | lt      |      | <   |
   #  | GT      |      | gt      |      | >   |
   #  | LE      |      | le      |      | <=  |
   #  | GE      |      | ge      |      | >=  |
   #  | EQ      |      | eq      |      | ==  |
   #  | NEQ     |  or  | neq     |  or  | !=  |
   #  | MATCH   |      | match   |      | ~~  |
   #  | SMATCH  |      | smatch  |      | ~=  |
   #  | NMATCH  |      | nmatch  |      | !~~ |
   #  | NSMATCH |      | nsmatch |      | !~= |
   #
   # where BINARY_BOOLEAN_OP is:
   #  | AND     |  or  | and     |  or  | &&  |
   #  | OR      |      | or      |      | ||  |
   #
   # where UNARY_BOOLEAN_OP is:
   #  | NOT     |
   #  | not     |
   #  | !       |
   #
   # where BINARY_ARITHMETIC_OP is:
   #  | +       |
   #  | -       |
   #  | *       |
   #  | /       |
   #
   #-----------------------------------------------------------------
   my $mql = qq(temp query bus "$type" "$name" "$rev" );
   
   if ($vaults ne "") {
      $mql .= qq(vault "$vaults" );
   }

   $mql   .= qq($where $max select id type name revision );

   foreach (keys %$select) {
      next if $_ eq "-attribute" || $_ eq "-files";

      $mql .= substr($_, 1)." ";
   }

   if (defined $select->{-attribute}) {
      if (! ref $select->{-attribute}) {
         if ($select->{-attribute} eq "*") {
            $mql .= qq(attribute.value );
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

   #my $mql = qq(temp query bus "$type" "$name" "$rev" 
   #             $where $max select id type name revision
   #             next first last originated modified
   #             description policy state current owner
   #             vault revisions attribute.* history 
   #             locked locker format.file );
   
   print "MQL = \n$mql\n" if $mdb->{-debug};


   my $rc;
   my @output;
   my @error;
   if($mdb->{-mql}) {
      my %r = $mdb->{-mql}->execute($mql, $mdb->{-context});

      $rc     = $r{-rc};
      @output = @{$r{-output}};
      @error  = @{$r{-error}};
      
      $mdb->set_error(@{$r{-output}});
   }
   else {
      $mdb->set_error("Error: #999: Not connected to MQL");
   }

   $rc = $mdb->is_error();


   if(! $rc) {
      my $first = 1;
      my (%hash, $c, $key, $val);
      foreach (@output) {

         if($_ =~ /^businessobject/i) {
            push @list, eMatrix::BizObj->new(%hash) if ! $first;
            $first = 0;
    
            %hash = (-mdbh                => $mdb,
                     -id                  => "",
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
            elsif ($key =~ /^\-format\.file\.store/) {
               push @{$hash{-files_store}}, $val;
            }
            elsif ($key =~ /^\-format\.file\.location/) {
               push @{$hash{-files_location}}, $val;
            }
            elsif ($key =~ /^\-format\.file\.format/) {
               push @{$hash{-files_format}}, $val;
            }
            elsif ($key =~ /^\-format\.file\.modified/) {
               push @{$hash{-files_modified}}, $val;
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
      

      # Check to see if object was already created
      if(! $needy && exists $objs->{$mdb->{-mql}->{-session}}->{$hash{-id}}) {
         push @list, $objs->{$mdb->{-mql}->{-session}}->{$hash{-id}};
      }
      else {
         if ($hash{-id} ne "") {
            push @list, eMatrix::BizObj->new(%hash);
         }
      }
   }

   return @list;
}





#======================================================================
# NAME:  print_businessobject() 
#
# DESC:  Gets a single Business objects
#
# ARGS:  oid    - The Matrix Business Object OID
#        select - Ref to a Hash which contains all the selectables
#        needy  - Create new objects even if the already exists
#
# RET:   eMatrix::BizObj Object
#
# HIST:  
#
#======================================================================
sub print_businessobject {
   my ($mdb, $oid, $select, $needy) = @_;

   return $objs->{$mdb->{-mql}->{-session}}->{$oid} 
   if (! $needy) && (exists $objs->{$mdb->{-mql}->{-session}}->{$oid});
   
   my $obj = undef;

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
   my $mql = qq(print bus "$oid" select id type name revision );

   foreach (keys %$select) {
      next if $_ eq "-attribute" || $_ eq "-files";

      $mql .= substr($_, 1)." ";
   }

   if (defined $select->{-attribute}) {
      if (! ref $select->{-attribute}) {
         if ($select->{-attribute} eq "*") {
            $mql .= qq(attribute.value );
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
      my %r = $mdb->{-mql}->execute($mql, $mdb->{-context});

      $rc     = $r{-rc};
      @output = @{$r{-output}};
      @error  = @{$r{-error}};
      
      $mdb->set_error(@{$r{-output}});
   }
   else {
      $mdb->set_error("Error: #999: Not connected to MQL");
   }

   $rc = $mdb->is_error();


   if(! $rc) {
      my (%hash, $c, $key, $val);
      
      foreach (@output) {
         
         if($_ =~ /business object/i) {
            
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
      
      if (exists $hash{-id}) {
      $obj = eMatrix::BizObj->new(%hash);
   }
      else {
         $obj = undef;
      }
   }


   return $obj;
}







#======================================================================
# NAME:  lock_businessobject
#
# DESC:  Lock this Business Object
#
# ARGS:  self   - This BizObj Object
#
# RET:   0 if no Errors found in output, 1 otherwise
#
# HIST:  
#
#======================================================================
sub lock_businessobject {
   my ($self, $storage_area) = @_;

   my $mql = qq(lock bus $self->{-id});

   if($self->{-mdbh}->{-mql}) {
      print "MQL = " . scalar localtime() . "\n$mql\n" if $self->{-mdbh}->{-debug};

      my %r = $self->{-mdbh}->{-mql}->execute($mql, 
                                              $self->{-mdbh}->{-context});

      if (! $r{-rc}) {
         $self->{-locked} = "TRUE";
      }

      $self->{-mdbh}->set_error(@{$r{-output}});
   }
   else {
      $self->{-mdbh}->set_error("Error: #999: Not connected to MQL");
   }


   return $self->{-mdbh}->is_error();
}





#======================================================================
# NAME:  unlock_businessobject
#
# DESC:  Unlock this Business Object
#
# ARGS:  self   - This BizObj Object
#
# RET:   0 if no Errors found in output, 1 otherwise
#
# HIST:  
#
#======================================================================
sub unlock_businessobject {
   my ($self) = @_;

   my $mql = qq(unlock bus $self->{oid});

   if($self->{-mdbh}->{-mql}) {
      print "MQL = " . scalar localtime() . "\n$mql\n" if $self->{-mdbh}->{-debug};

      my %r = $self->{-mdbh}->{-mql}->execute($mql, 
                                              $self->{-mdbh}->{-context});
      
      if (! $r{-rc}) {
         $self->{-locked} = "FALSE";
      }
      
      $self->{-mdbh}->set_error(@{$r{-output}});
   }
   else {
      $self->{-mdbh}->set_error("Error: #999: Not connected to MQL");
   }


   return $self->{-mdbh}->is_error();
}





#======================================================================
# NAME:  fill_attributes() 
#
# DESC:  fills in the Attribute values for this BizObj
#
# ARGS:  self   - This BizObj Object
#
# RET:   0 if no Errors found in output, 1 otherwise
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
   my $mql = qq(print bus "$self->{-id}" select attribute.value);

   my $rc;
   my @output;
   my @error;
   if($self->{-mdbh}->{-mql}) {
      print "MQL = " . scalar localtime() . "\n$mql\n" if $self->{-mdbh}->{-debug};

      my %r = $self->{-mdbh}->{-mql}->execute($mql, 
                                              $self->{-mdbh}->{-context});

      $rc     = $r{-rc};
      @output = @{$r{-output}};
      @error  = @{$r{-error}};

      $self->{-mdbh}->set_error(@{$r{-output}});
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
   

   return $self->{-mdbh}->is_error();   
}





#======================================================================
# NAME:  checkin_businessobject() 
#
# DESC:  Checkin files as attachments to this Business Object
#
# ARGS:  self   - This Business Object
#        paths  - Reference to an Array which is a list of 
#                 full-path files
#        format - The format to use for the files (generic by default)
#        store  - The Store to check the files into (STORE by default)
#       
#
# RET:   Return code
#
# HIST:  
#
#======================================================================
sub checkin_businessobject {
   my ($self, $files, $format, $store, 
       $keep_lock, $append, $storage_area) = @_;

   $format = "generic" if $format eq "";
   $store  = "STORE"   if $store  eq "";

   #-----------------------------------------------------------------
   # MQL Usage:
   #
   # checkin businessobject BO_NAME [unlock] [|server|]
   #                                          |client|
   #  [format FORMAT_NAME] [store STORE_NAME] [append] FILENAME { FILENAME};
   #
   #-----------------------------------------------------------------

   my $mql = qq(checkin bus $self->{-id} );

   $mql .= qq(unlock ) if ! $keep_lock;
   $mql .= qq(client );
   $mql .= qq(format "$format" store "$store" );


   #------------------------------------------------------------
   # If we append to the attachments, it will keep all previous
   # revs of the Gerber Export files.
   #------------------------------------------------------------
   if ($append) {
      $mql   .= qq(append );
   }

   #------------------------------------------------------------
   # Support for checking in multiple attachments
   #------------------------------------------------------------
   foreach (@$files) {
      $mql .= qq("$_" );
   }

   print "MQL = \n$mql\n" if $self->{-mdbh}->{-debug};

   my $rc;
   if($self->{-mdbh}->{-mql}) {
      my %r = $self->{-mdbh}->{-mql}->checkin($mql, $files, $keep_lock, $self,
                                              $storage_area,
                                              $self->{-mdbh}->{-context});
      $rc = $r{-rc};
      
      $self->{-mdbh}->set_error(@{$r{-output}});
   }
   else {
      $self->{-mdbh}->set_error("Error: #999: Not connected to MQL");
   }
   
   
   #if(!$rc && !$keep_lock) {
   #   if($self->{-mdbh}->{-mql}) {
   #      my %r = $self->{-mdbh}->{-mql}->execute(qq(unlock bus $self->{-id}));
   #      
   #      $self->{-mdbh}->set_error(@{$r{-output}});
   #   }
   #}
   

   return $self->{-mdbh}->is_error();   
}





#======================================================================
# NAME:  checkout_businessobject() 
#
# DESC:  Check out files attached to this Business Object.  Currently,
#        all the files are checked out.  The files are exported to
#        the directory specified.  Only the files stored in the 
#        default Format are checked out.
#
# ARGS:  self    - This Business Object
#        dir     - The directory where the files are to be stored
#        for_mod - Checking out for Modification (lock the BO)
#
# RET:   Return code
#
# HIST:  
#
#======================================================================
sub checkout_businessobject {
   my ($self, $format, $files, $dir, $for_mod) = @_;

   #-----------------------------------------------------------------
   # MQL Usage:
   #
   #  checkout businessobject BO_NAME [lock] [|server|]
   #                                          |client|
   #     [format FORMAT_NAME] [file |FILENAME{,FILENAME}|] [DIRECTORY];
   #                                |all                |
   #
   #-----------------------------------------------------------------
   my $file_str = "all";
   if(ref $files eq "SCALAR" || ref $files eq "") {
      if(uc $files ne "ALL") {
         $file_str = "file $files";
      }
   }
   elsif(ref $files eq "ARRAY") {
      $file_str = "file '" . join ("', '", @$files) . "' ";
   }

   my $mql = qq(checkout bus $self->{-id} );
   
   $mql .= qq(lock ) if $for_mod;
   
   if ($format ne "") {
      $mql .= qq(format $format );
   }
   
   $mql .= qq($file_str $dir);

   print "MQL = \n$mql\n" if $self->{-mdbh}->{-debug};

   my $rc;
   if($self->{-mdbh}->{-mql}) {
      my %r = $self->{-mdbh}->{-mql}->checkout($mql, $dir);

      $rc = $r{-rc};
      
      $self->{-mdbh}->set_error(@{$r{-output}});
   }
   else {
      $self->{-mdbh}->set_error("Error: #999: Not connected to MQL");
   }
   
   
   #if(!$rc && $for_mod) {
   #   if($self->{-mdbh}->{-mql}) {
   #      my %r = $self->{-mdbh}->{-mql}->execute(qq(lock bus $self->{-id}));
   #      
   #      $self->{-mdbh}->set_error(@{$r{-output}});
   #   }
   #}


   return $self->{-mdbh}->is_error();
}





#======================================================================
# NAME:  modify_businessobject() 
#
# DESC:  
#        
#        
#        
#
# ARGS:  self    - This Business Object
#        items   - Ref to a Hash with contains all the names and values
#                  to modify
#
# RET:   Return code
#
# HIST:  
#
#======================================================================
sub modify_businessobject {
   my ($self, $items) = @_;

   #-----------------------------------------------------------------
   # MQL Usage:
   #
   #  modify businessobject OBJECTID [ITEM {ITEM}];
   #
   #-----------------------------------------------------------------
   my $mql = qq(modify bus $self->{-id} );

   foreach (keys %$items) {
      if ($items->{$_} =~ /\"/) {
         $mql .= qq("$_" '$items->{$_}' );
      }
      else {
         $mql .= qq("$_" "$items->{$_}" );
      }
   }

   my $rc;
   my %r;
   if($self->{-mdbh}->{-mql}) {
      print "MQL = " . scalar localtime() . "\n$mql\n" if $self->{-mdbh}->{-debug};
      
      #$self->{-mdbh}->{-mql}->execute(qq(trigger off)) ;
      
      %r = $self->{-mdbh}->{-mql}->execute($mql, 
                                           $self->{-mdbh}->{-context});
      $rc = $r{-rc};
   }
   else {
      $self->{-mdbh}->set_error("Error: #999: Not connected to MQL");
   }

   #my $rc     = $r{-rc};
   #my @output = @{$r{-output}};
   #my @error  = @{$r{-error}};
   
   #$self->{-mdbh}->{-mql}->execute(qq(trigger on));

   $self->{-mdbh}->set_error(@{$r{-output}});
   $self->{-mdbh}->set_error(@{$r{-error}});

   return $self->{-mdbh}->is_error();

   #return eMatrix::DB::set_error(@output);
}






#======================================================================
# NAME:  list_files() 
#
# DESC:  List files which are attachments to this Business Object
#
# ARGS:  self   - This Business Object
#        paths  - Reference to an Array which is a list of 
#                 full-path files
#        format - The format to use for the files (generic by default)
#        store  - The Store to check the files into (STORE by default)
#       
#
# RET:   Return code
#
# HIST:  
#
#======================================================================
sub list_files {
   my ($self) = @_;

   my %r     = ();
   my @files = ();

   my $mql = qq(print bus $self->{-id} select format.file);

   if($self->{-mdbh}->{-mql}) {
      print "MQL = " . scalar localtime() . "\n$mql\n" if $self->{-mdbh}->{-debug};

      %r = $self->{-mdbh}->{-mql}->execute($mql, 
                                           $self->{-mdbh}->{-context});
   }

   my $rc     = $r{-rc};
   my @output = @{$r{-output}};
   my @error  = @{$r{-error}};

   if ($rc) {
      return @files;
   }
   else {
      foreach (@output) {
         $_ =~ s/^\s+//;
         next unless $_ =~ /^format\.file/;
         chomp;
         push @files, (split(" = ", $_))[1];
      }
   }

   return @files;
}




#----------------------------------------------------------------------
# NAME:  promote
# DESC:  promotes current Business Object to next lifecycle state
# ARGS:  self	- this Business Object
# 	 
# RET:   return code from executed MQL command
# HIST:  2008-02-21 kkoskelin, created
#----------------------------------------------------------------------
sub promote {
   my ($self) = @_;

   my %r = (
       -rc => 0,
       -error => [],
       -output => []
       );

   if (! $self->{-mdbh}->{-mql} ) {
       $r{-rc} = 1;
       $r{-error} = ("MQL not available");
   } else {
       my $mql = qq(promote bus $self->{-id});
       %r = $self->{-mdbh}->{-mql}->execute($mql, $self->{-mdbh}->{-context});
   }

   return \%r;
}

#----------------------------------------------------------------------
# NAME:  demote
# DESC:  demotes current Business Object to previous lifecycle state
# ARGS:  self	- this Business Object
# 	 
# RET:   return code from executed MQL command
# HIST:  2008-02-21 kkoskelin, created
#----------------------------------------------------------------------
sub demote {
   my ($self) = @_;

   my %r = (
       -rc => 0,
       -error => [],
       -output => []
       );

   if (! $self->{-mdbh}->{-mql} ) {
       $r{-rc} = 1;
       $r{-error} = ("MQL not available");
   } else {
       my $mql = qq(demote bus $self->{-id});
       %r = $self->{-mdbh}->{-mql}->execute($mql, $self->{-mdbh}->{-context});
   }
   return \%r;
}

#----------------------------------------------------------------------
# NAME:  set_state
# DESC:  sets lifecycle state to $target state through a series of 
# 	 demote() or promote() calls
#
# ARGS:  self	- this Business Object
# 	 
# RET:   return code from executed MQL command
# HIST:  2008-02-21 kkoskelin, created
#----------------------------------------------------------------------
sub set_state {
   my ($self, $target_state) = @_;

   my $r = {
       -rc => 0,
       -error => '',
       -output => ''
       };
   my $current = $self->get_info("current")->{-output}->[0];
   my $policy_name = $self->get_info("policy")->{-output}->[0];
   my ($policy) = eMatrix::Policy::list_policy( $self->{-mdbh}, $policy_name );
   my (@states) = $policy->get_states();
   # seems like there could be a better way to do it
   my ($state_name, $curr_idx, $targ_idx) = (undef, undef, undef);
   for (my $i=0; 
	   ($i < scalar(@states)) && 
	   ($curr_idx==undef) && 
	   ($targ_idx==undef);
	   $i++ ) {
       if ($states[$i] eq $target_state) { $targ_idx = $i; }
       if ($states[$i] eq $current)      { $curr_idx = $i; }

   }

   if($targ_idx) {
       # clearly if current and target state are the same, no work is done.
       DEMOTE: while($curr_idx > $targ_idx) {
           $r = $self->demote();
           last DEMOTE if ($r->{-rc} != 0);
           $curr_idx--;
       }
       PROMOTE: while($curr_idx < $targ_idx) {
           $r = $self->promote();
           last PROMOTE if ($r->{-rc} != 0);
           $curr_idx++;
       }
   } else {
       $r = {
       -rc => 1,
       -error => sprintf(q(Unable to set state "%s" in policy "%s"), $target_state, $policy_name),
       -output => ''
       };
   }

   return $r;
}

#----------------------------------------------------------------------
# NAME:  get_info
# DESC:  retrieves value of $selectable on current Business Object
#
# ARGS:  self	- this Business Object
# 	 selectable - name of basic, attribute or other selectable
# 	 
# RET:   return code from executed MQL command
# HIST:  2008-02-21 kkoskelin, created
#----------------------------------------------------------------------
sub get_info {
    my ($self, $selectable) = @_;
   my %r = (
       -rc => 0,
       -error => '',
       -output => ''
       );

   if (! $self->{-mdbh}->{-mql} ) {
       $r{-rc} = 1;
       $r{-error} = "MQL not available";
   } else {
       my $mql = qq(print bus $self->{-id} select $selectable dump);
       %r = $self->{-mdbh}->{-mql}->execute($mql, $self->{-mdbh}->{-context});
   }
   return \%r;
}

#----------------------------------------------------------------------
# NAME:  remove
# DESC:  removes current Business Object
#
# ARGS:  self	- this Business Object
# 	 selectable - name of basic, attribute or other selectable
# 	 
# RET:   return code from executed MQL command
#----------------------------------------------------------------------
sub _UNTESTED_remove {
   my ($self) = @_;
   my %r = (
       -rc => 0,
       -error => '',
       -output => ''
       );

   if (! $self->{-mdbh}->{-mql} ) {
       $r{-rc} = 1;
       $r{-error} = "MQL not available";
   } else {
       my $mql = qq(delete bus $self->{-id});
       %r = $self->{-mdbh}->{-mql}->execute($mql, $self->{-mdbh}->{-context});
   }
   return \%r;
}
#======================================================================
# End of eMatrix::BizObj
#======================================================================
1;

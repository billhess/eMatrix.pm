#======================================================================
# NAME:  eMatrix::Expand
#
# DESC:  An Expand Object is a representation of a Relationship Star
#        in Matrix.  It is contructed by parsing output from the MQL
#        command "expand bus ..." (Usage statement in BizObj.pm).
#        An Expand Object has the capability of showing unlim
#
# VARS:  
#
#======================================================================
# Copyright 2002 - Technology Resource Group LLC as an unpublished work
#======================================================================
package eMatrix::Expand;


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

use Tie::RefHash;
use eMatrix::BizObj;
use eMatrix::Connection;




#------------------------------------------------------------
# This selectable Hash is for the print_businessobject
#------------------------------------------------------------
my $select = {
              -next                => 1,
              -first               => 1,
              -last                => 1,
              -originated          => 1,
              -modified            => 1,
              -description         => 1,
              -policy              => 1,
              -state               => 1,
              -current             => 1,
              -owner               => 1,
              -vault               => 1,
              -locked              => 1,
              -locker              => 1,
              -attribute           => "*",
              -files               => 1,
              -revisions           => 1,
              #-history             => 1,
           };



#======================================================================
# NAME:  new() 
#
# DESC:  Creates new eMatrix Expand Object
#
# ARGS:  start_bo - Starting Business Object
#        needy    - Need a new BizObj? (1|0)
#        data     - Output from an expand bus MQL Command
#        rel_name  - Something to match on when parsing MQL Output
#        my_select - Ref to a Hash of selectables for the print_bus
#
# RET:   Expand Object
#
# HIST:  
#
#======================================================================
sub new {
   my ($mdb, $start_bo, $needy, $rel_name, @data) = @_;

   print "\n\n*** eMatrix::Expand::new: -- ", join("\n", @_), "\n"
       if $mdb->{-debug};
   
   tie my %rel, "Tie::RefHash";

   my $rel = \%rel;

   my $obj = {-start   => $start_bo,
              -rel     => $rel };


   #---------------------------------------------------------------
   # $rel->{'Business Object'}->{ 'from' | 'to' } is a 3 element array:
   # [0] is the Business Object which is related to this BO  
   # [1] is the Relationship name
   # [2] is the Connection Object.
   #---------------------------------------------------------------
   my @parents        = ($start_bo);
   my $current_parent = $start_bo;
   my $previous_level = 1;
   my $previous_bo    = $start_bo;
   my $current_bo;
   my $current_conn;

   my $full_record  = 0;
   my $level        = "";
   my $relationship = "";
   my $to_from      = "";
   my $oid          = "";
   my $in_con       = 0;
   my $in_bo        = 0;
   my %hash         = ();


   foreach my $line (@data) {
      print "LINE = $line\n" if $mdb->{-debug};

      if ($line =~ 
          /^(\d+)\s\s($rel_name)\s\s(to|from)\s\s(\d+\.\d+\.\d+\.\d+)$/) {
         $level        = $1;
         $relationship = $2;
         $to_from      = $3;
         $oid          = $4;

         print "HEAD LINE: $level, $relationship, $to_from, $oid\n" if $mdb->{-debug};

         $current_conn = eMatrix::Connection->new(%hash) 
             if $hash{-id} ne "";

         if ($hash{-id} ne "") {
            if($mdb->{-debug}) {
               print "Creating new Connection using Hash:\n", Dumper(%hash)
                   if $hash{-id} ne "";
               print "New Connection:\n", Dumper($current_conn)
                   if $hash{-id} ne "";
            }
         }

         $in_con       = 0;
         $in_bo        = 1;
         %hash         = (-mdbh                => $mdb,
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
      }
      else {
         my $c   = index $line, " = ";
         my $key = substr $line, 0, $c;
         my $val = substr $line, $c+3;
         
         $key =~ s/^\s+/\-/;

         print "KEY = '$key', VALUE = '$val'\n" if $mdb->{-debug};

         # Make sure not to get into infinite recursion         
         if ($key eq "-id") {
            if ($val ne $oid) {
               $current_bo  = eMatrix::BizObj->new(%hash);
               $in_bo       = 0;
               $in_con      = 1;
               %hash        = (-id                  => $hash{-id},
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
               
               if($mdb->{-debug}) {
                  print "\nCreated Business Object\n";
                  print Dumper $current_bo, "\n";
               }
            }
         }
         

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
   

      if($mdb->{-debug}) {
         print "Ref Curr_BO   = '", ref $current_bo, "'\n";
         print "Ref Curr_Conn = '", ref $current_conn, "'\n";
      }


      #-------------------------------------------------------
      # When we have both a BizObj, and a Connection,
      # we can append to the Array Ref's 
      #-------------------------------------------------------
      if (ref $current_bo eq "eMatrix::BizObj" &&
          ref $current_conn eq "eMatrix::Connection") {

         if($mdb->{-debug}) {
            print "*** $current_bo->{-type}, $current_bo->{-name}, ";
            print "$current_bo->{-revision}\n";
         }
         
         #----------------------------------------------------------
         # Keep track of the previous parent.
         # If we go a level deeper, we need to push the previous
         # BO onto the Parents array.
         # If we go a level (or more) shallower, pop old parents
         # from the list.
         #----------------------------------------------------------
         if($level > $previous_level) {
            push @parents, $previous_bo;
         } 
         elsif($level < $previous_level) {
            for(my $i=$level; $i< $previous_level; $i++) {
               pop @parents;
            }
         }

         $current_parent = $parents[$#parents];
         
         if(!defined $rel->{$current_parent}->{'to'}) {
            $rel->{$current_parent}->{'to'} = [];
         }
         
         if(!defined $rel->{$current_parent}->{'from'}) {
            $rel->{$current_parent}->{'from'} = [];
         }
         
         push(@{$rel->{$current_parent}->{$to_from}}, 
              ($current_bo, $relationship, $current_conn)); 
         
         $previous_level = $level;
         $previous_bo    = $current_bo;

         $current_bo   = undef;
         $current_conn = undef;
      }
   }
      
   #-------------------------------------------------------
   # If, at the end of the data, we will have an unfinished
   # Connection to create, we can also append to -ref
   #-------------------------------------------------------
   $current_conn = eMatrix::Connection->new(%hash) 
       if $hash{-id} ne "";


   if (ref $current_bo eq "eMatrix::BizObj" &&
       ref $current_conn eq "eMatrix::Connection") {

      if($mdb->{-debug}) {
         print "*** $current_bo->{-type}, $current_bo->{-name}, ";
         print "$current_bo->{-revision}\n";
      }


      #----------------------------------------------------------
      # Keep track of the previous parent.
      # If we go a level deeper, we need to push the previous
      # BO onto the Parents array.
      # If we go a level (or more) shallower, pop old parents
      # from the list.
      #----------------------------------------------------------
      if($level > $previous_level) {
         push @parents, $previous_bo;
      } 
      elsif($level < $previous_level) {
         for(my $i=$level; $i< $previous_level; $i++) {
            pop @parents;
         }
      }

      $current_parent = $parents[$#parents];
      
      if(!defined $rel->{$current_parent}->{'to'}) {
         $rel->{$current_parent}->{'to'} = [];
      }

      if(!defined $rel->{$current_parent}->{'from'}) {
         $rel->{$current_parent}->{'from'} = [];
      }
      
      push(@{$rel->{$current_parent}->{$to_from}}, 
           ($current_bo, $relationship, $current_conn)); 

      $previous_level = $level;
      $previous_bo    = $current_bo;
      
      $current_bo   = undef;
      $current_conn = undef;
   }


   return bless $obj;
}






#======================================================================
# NAME:  get_to() 
#
# DESC:  Given a Business Object, get the immediate business objects on
#        the TO side of a relationship
#
# ARGS:  self   - eMatrix::Expand Object
#        obj    - Starting Business Object
#        rel    - Matrix Relation (Optional)
#
# RET:   List of BusinessObjects 
#
# HIST:  
#
#======================================================================
sub get_to {
   my $self = shift;
   my $obj  = shift;
   my $rel;
      
   if(ref $obj ne "eMatrix::BizObj") {
      $rel = $obj;
   } 
   else {
      $rel = shift;
   }

   return $self->get_related($obj, $rel, 'to');   
}





#======================================================================
# NAME:  get_from() 
#
# DESC:  Given a Business Object, get the immediate business objects on
#        the FROM side of a relationship
#
# ARGS:  self   - eMatrix::Expand Object
#        obj    - Starting Business Object
#        rel    - Matrix Relation (Optional)
#
# RET:   List of BusinessObjects 
#
# HIST:  
#
#======================================================================
sub get_from {
   my $self = shift;
   my $obj  = shift;
   my $rel;
      
   if(ref $obj ne "eMatrix::BizObj") {
      $rel = $obj;
   } 
   else {
      $rel = shift;
   }
   
   return $self->get_related($obj, $rel, 'from');
}





#======================================================================
# NAME:  get_related() 
#
# DESC:  Given a Business Object, get the immediate business objects on
#        either side of a relationship
#
# ARGS:  obj      - Starting Business Object
#        rel_name - The Relationship name wild cards allowed
#        to_from  - Which side of the relationship does the user want
#
# RET:   Hash ref with keys: Connection, and value BizObj object
#
# HIST:  
#
#======================================================================
sub get_related {
   my ($self, $obj, $rel_name, $to_from) = @_;

   tie my %list, "Tie::RefHash";

   my $list = \%list;

   $rel_name =  "*" if $rel_name =~ /^\*+$/;
   $rel_name =~ s/([^a-zA-Z0-9_*])/\\$1/g; 
   $rel_name =  "^" . $rel_name  if $rel_name !~ /^\*/;
   $rel_name =  $rel_name . "\$" if $rel_name !~ /\*$/;
   $rel_name =~ s/\*/\.\*/g;

   my $amt = 0;

   if (defined @{$self->{-rel}->{$obj}->{$to_from}}) {
      $amt = scalar @{$self->{-rel}->{$obj}->{$to_from}};
   }


   for(my $i = 0; $i < $amt; $i = $i + 3) {
      $list->{$self->{-rel}->{$obj}->{$to_from}->[$i]} =
          $self->{-rel}->{$obj}->{$to_from}->[$i+2];

      #$list->{$self->{-rel}->{$obj}->{$to_from}->[$i+2]} =
      #    $self->{-rel}->{$obj}->{$to_from}->[$i];

      #push @list, {-bizobj     => $self->{-rel}->{$obj}->{$to_from}->[$i],
      #             -connection => $self->{-rel}->{$obj}->{$to_from}->[$i+2]}
      #    if $self->{-rel}->{$obj}->{$to_from}->[$i+1] =~ /$rel_name/;

   }

   return $list;
}




#======================================================================
# NAME:  get_start() 
#
# DESC:  Gives back the Business Object stored in the -start property
#
# ARGS:  Nothing
#
# RET:   Business Object
#
# HIST:  
#
#======================================================================
sub get_start {
   return $_[0]->{-start};
}






#======================================================================
# End of eMatrix::Expand
#======================================================================
1;

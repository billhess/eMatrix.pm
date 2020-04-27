#======================================================================
# NAME:  eMatrix::Context
#
# DESC:  Top level abstraction to simulate eMatrix database
#        connection handle.  All other eMatrix:: modules will
#        depend on this connection before accessing the database
#        via the MQL.pm module
#
# VARS:  OPEN
#        LOG
#        ERROR
#        DEMLIM
#
#======================================================================
# Copyright 2002 - Technology Resource Group LLC as an unpublished work
#======================================================================
package eMatrix::Context;

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

use eMatrix::Person;
use eMatrix::Vault;

my $debug = 0;



#======================================================================
# NAME:  new() 
#
# DESC:  Creates new eMatrix::Context Object
#
# ARGS:  None
#
# RET:   eMatrix::Context Object
#
# HIST:  
#
#======================================================================
sub new {
   my ($class) = @_;

   my $self = bless { -mdbh     => undef,
                      -person   => eMatrix::Person->new(),
                      -vault    => eMatrix::Vault->new(),
                      -password => "",
                   }, $class;

   # $self->reread_context();

   return $self;
}




#======================================================================
# NAME:  set_context() 
#
# DESC:  Set context in a eMatrix Session
#        
#
# ARGS:  person   - The user name to become
#        password - A password for the user
#        vault    - The Vault to connect to
#
# RET:   1  - Failure
#        0  - Success
#
# HIST:  
#
#======================================================================
sub set_context {
   my ($self, $person, $password, $vault) = @_;

   my $mql = qq(set context );

   if ($person ne "") {
      $mql .= qq( person "$person");
   }

   if($password ne "") {
      $mql .= qq( password "$password");
   }
         
   if($vault ne "") {
      $mql .= qq( vault "$vault");
   }


   my $rc;
   my @output;
   my @error;

   if($self->{-mdbh}->{-mql}) {
      my %r = $self->{-mdbh}->{-mql}->
          set_context($mql, [$person, $password, $vault]);

      $rc     = $r{-rc};
      @output = @{$r{-output}};
      @error  = @{$r{-error}};
      
      $self->{-mdbh}->set_error(@{$r{-output}});

      if(! $rc) {
         $self->{-password} = $password;
         $rc = $self->reread_context();
      }
   }
   else {
      $rc = 1;
      push @error, "Error: #999: Not connected to MQL";
      $self->{-mdbh}->set_error("Error: #999: Not connected to MQL");
   }
   
   
   return ($rc, @output, @error);
}



#======================================================================
# NAME:  push_context() 
#
# DESC:  Pushes context to another Person in a eMatrix Session
#        
#
# ARGS:  person   - The user name to become
#        password - A password for the user
#        vault    - The Vault to connect to
#
# RET:   1  - Failure
#        0  - Success
#
# HIST:  
#
#======================================================================
sub push_context {
   my ($self, $person, $password, $vault, $uidlocal) = @_;

   print "Context push_context - ", @_, "\n" if $debug;
   my $mql = qq(push context );

   if ($person ne "") {
      $mql .= qq( person "$person" );
   }

   if ($password ne "") {
      $mql .= qq( password "$password");
   }

   if ($vault ne "") {
      $mql .= qq( vault "$vault");
   }

   print "MQL = $mql\n" if $self->{-mdbh}->{-debug};


   my $rc;
   my @output;
   my @error;

   if($self->{-mdbh}->{-mql}) {
      my %r = $self->{-mdbh}->{-mql}->
          push_context($mql, [$person, $password, $vault]);
      
      $rc     = $r{-rc};
      @output = @{$r{-output}};
      @error  = @{$r{-error}};
      
      $self->{-mdbh}->set_error(@{$r{-output}});


      if(! $rc) {
         $self->{-password}        = $password;
         $self->{-uidlocal}        = $uidlocal;
         $self->{-person}->{-name} = $person;
         $self->{-vault}->{-name}  = $vault;
      }
   }
   else {
      $rc = 1;
      push @error, "Error: #999: Not connected to MQL";
      $self->{-mdbh}->set_error("Error: #999: Not connected to MQL");
   }
      
   
   return ($rc, @output, @error);
}



#======================================================================
# NAME:  pop_context() 
#
# DESC:  Pops context to the previous Context
#        
#
# ARGS:  NONE
#
# RET:   1  - Not connected to database
#        0  - Success
#
# HIST:  
#
#======================================================================
sub pop_context {
   my ($self) = @_;

   my $rc;
   my @output;
   my @error;

   if($self->{-mdbh}->{-mql}) {
      my %r = $self->{-mdbh}->{-mql}->pop_context("pop context");
      
      $rc     = $r{-rc};
      @output = @{$r{-output}};
      @error  = @{$r{-error}};
      
      $self->{-mdbh}->set_error(@{$r{-output}});
   }
   else {
      $rc = 1;
      push @error, "Error: #999: Not connected to MQL";
      $self->{-mdbh}->set_error("Error: #999: Not connected to MQL");
   }
      
   
   return ($rc, @output, @error);
}



#======================================================================
# NAME:  reread_context() 
#
# DESC:  Read the context from MQL, and sets the Person and Vault
#        of this eMatrix::Context Object accordingly
#
# ARGS:  NONE
#
# RET:   Return Code (0|1)
#
# HIST:  
#
#======================================================================
sub reread_context {
   my ($self) = @_;

   my $rc;
   my @output;
   my @error;

   if($self->{-mdbh}->{-mql}) {
      my %r = $self->{-mdbh}->{-mql}->print_context("print context");
      
      $rc     = $r{-rc};
      @output = @{$r{-output}};
      @error  = @{$r{-error}};
      
      $self->{-mdbh}->set_error(@{$r{-output}});

      #------------------------------------------------------------
      # This splitting is kind of ugly, but it works.  Basically, 
      # the output from the MQL command: "print context" looks 
      # something like this:
      #
      # "context vault eService Sample person Test Everything"
      #
      # (There is no guarentee about the order of the Vault and Person)
      # The only things I can count on are the existance of the words
      # "vault" and "person".  So, everything after the word "vault", 
      # up until the word "person" will be the vault.  
      # Similarly, everything after the word "person" and before the 
      # word "vault" will be the person
      #------------------------------------------------------------
      if(! $rc) {
         my ($p_name, $v_name);
         
         $v_name = (split(/\s+vault\s+/, $output[0]))[1];
         $v_name = (split(/\s+person\s+/, $v_name))[0];
         
         ($self->{-vault}) = eMatrix::Vault::list_vault($self->{-mdbh},
                                                        $v_name);
         
         $p_name = (split(/\s+person\s+/, $output[0]))[1];
         $p_name = (split(/\s+vault\s+/, $p_name))[0];
         
         ($self->{-person}) = eMatrix::Person::list_person($self->{-mdbh},
                                                           $p_name);
      }      
   }
   else {
      $rc = 1;
      push @error, "Error: #999: Not connected to MQL";
      $self->{-mdbh}->set_error("Error: #999: Not connected to MQL");
   }
   
   
   return $rc;
}





#======================================================================
# NAME:  get_person() 
#
# DESC:  Gets the Person from Context, and returns it
#
# ARGS:  NONE
#
# RET:   eMatrix::Person Object
#
# HIST:  
#
#======================================================================
sub get_person {
   my ($self) = @_;

   return $self->{-person};
}





#======================================================================
# NAME:  get_vault
#
# DESC:  Gets the Vault from Context, and returns it
#
# ARGS:  NONE
#
# RET:   eMatrix::Vault Object
#
# HIST:  
#
#======================================================================
sub get_vault {
   my ($self) = @_;

   return $self->{-vault};
}





1;

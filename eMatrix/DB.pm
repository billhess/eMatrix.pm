#======================================================================
# NAME:  eMatrix::DB
#
# DESC:  Top level abstraction to simulate eMatrix database
#        connection handle.  All other eMatrix:: modules will
#        depend on this connection before accessing the database
#        via the MQL.pm module
#
# VARS:  OPEN
#        LOG
#        ERROR
#        MQL_ERROR
#
#======================================================================
# Copyright 2002 - Technology Resource Group LLC as an unpublished work
#======================================================================
package eMatrix::DB;

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


use eMatrix::Attribute;
use eMatrix::BizObj;
use eMatrix::Context;
use eMatrix::Format;
use eMatrix::Group;
use eMatrix::Relationship;
use eMatrix::Role;
use eMatrix::Person;
use eMatrix::Policy;
use eMatrix::Program;
use eMatrix::Store;
use eMatrix::Type;
use eMatrix::Vault;



use vars (qw(%bool %card));


#----------------------------------------------------------------------
# Define boolean hash to store eMatrix values as 0/1
#----------------------------------------------------------------------
%bool = (TRUE  => 1,
         True  => 1,
         true  => 1,
         1     => 1,
         FALSE => 0,
         False => 0,
         false => 0,
         0     => 0,
         );


#----------------------------------------------------------------------
# Define cardinality hash to store eMatrix values as 0/1
#----------------------------------------------------------------------
%card = (ONE  => 1,
         One  => 1,
         one  => 1,
         N    => 0,
         n    => 0,
         MANY => 0,
         Many => 0,
         many => 0);


#----------------------------------------------------------------------
# Define the variable for the MQL Module to use
#----------------------------------------------------------------------
my $use_soap = 0;
my $soap_host;
my $soap_port;

my $MQL_OPEN;

if($use_soap) {
   $MQL_OPEN = \&{"MQL::SOAP::open"};
}
else {
   $MQL_OPEN = \&{"MQL::open"};
}



#----------------------------------------------------------------------
# Some Errors from MQL should be ignored
#----------------------------------------------------------------------
my $ignore_errors = qq/(Occurred on line number|java\\.lang\\.NoClassDefFoundError)/;



#======================================================================
# NAME:  new() 
#
# DESC:  
#
# ARGS:  bootstrap - eMatrix bootstrap file
#        path      - Directory location where eMatrix Scripts can be found
#
# RET:   Initialized eMatrix::DB object
#
# HIST:  
#
#======================================================================
sub new {
   my ($bootstrap, $path) = @_;
   
   my $self = bless { -mql       => undef,
                      -debug     => 0,
                      -open      => 0,
                      -log       => 0,
                      -error     => 0,
                      -mql_error => [],
                      -bootstrap => $bootstrap,
                      -path      => $path,
                      -context   => eMatrix::Context->new(),
                      -ctx_stack => [],
                   }, "eMatrix::DB";
   
   return $self;
}




#======================================================================
# NAME:  connect() 
#
# DESC:  Connect to a eMatrix DATABASE
#        Only one connection is permitted per program since
#        this interface is based on MQLIO
#
# ARGS:  bootstrap - eMatrix bootstrap file
#        path      - Directory location where eMatrix Scripts can be found
#
# RET:   Return Code
#         0 - Connected
#        !0 - Error
#
# HIST:  
#
#======================================================================
sub connect {
   my ($self) = @_;
      
   my $rc = 0;

   if(! $self->{-open}) {
      $self->{-mql} = &{$MQL_OPEN}($self->{-bootstrap}, 
                                   $self->{-path},
                                   $soap_host, 
                                   $soap_port);
      
      if($self->{-mql}) {         
         $self->{-open} = 1;
         $self->{-context}->{-mdbh} = $self;
      }
      else {
         $rc = 1;
      }
   }

   
   return $rc;
}




#======================================================================
# NAME:  disconnect() 
#
# DESC:  Disconnect from a eMatrix DATABASE
#        This really just cleans up the connection
#
# ARGS:  NONE
#
# RET:   Return Code
#         1  - Not connected to database
#         0  - Success
#        -1  - Error disconnecting - returned from
#
# HIST:  
#
#======================================================================
sub disconnect {
   my ($self) = @_;

   my $rc = 1;

   if($self->{-open}) {
      if($self->{-log}) {
         $self->{-mql}->close_log();
         $self->{-log} = 0;
      }
      
      $rc = $self->{-mql}->close();
      $self->{-open} = 0;
   }
   
   return $rc;
}




#======================================================================
# NAME:  set_mql_buffer_size() 
#
# DESC:  Set the MQL output and error buffer sizes
#
# ARGS:  output_size
#        error_size
#
# RET:   Return Code
#         1  - No MQL object
#         0  - Success
#
# HIST:  
#
#======================================================================
sub set_mql_buffer_size {
   my ($self, $output_size, $error_size) = @_;

   my $rc = 1;

   if($self->{-mql}) {   
      $self->{-mql}->set_buffer_size($output_size, $error_size);
      $rc = 0;
   }
      
   return $rc;
}



#======================================================================
# NAME:  cancel() 
#
# DESC:  Stops an existing MQL query by closing and reopening the
#        Matrix connection
#
# ARGS:  NONE
#
# RET:   1  - Not connected to database
#        0  - Success
#        -1 - Error disconnecting - returned from
#
# HIST:  
#
#======================================================================
sub cancel {
   my ($self) = @_;

   my $rc = 1;

   print "Running Disconnect...\n" if $self->{-debug};
   $self->disconnect();

   my @context_stack = @{$self->{-ctx_stack}};
   
   print "Running Connect...\n" if $self->{-debug};
   my $mdb = eMatrix::DB::connect($self->{-bootstrap},
                                  $self->{-path});

   foreach (@context_stack) {
      print "Pushing Context...('", $_->{-person}->{-name}, "' '", 
            $_->{-password}, "' '", $_->{-vault}->{-name}, "')\n" 
                if $self->{-debug};

      $mdb->push_context($_->{-person}->{-name}, 
                         $_->{-password},
                         $_->{-vault}->{-name});
   }
   
   $self = undef;
   #$self = $mdb;
   return $mdb;
}



#======================================================================
# NAME:  openlog() 
#
# DESC:  Open a log file
#
# ARGS:  logfile - Path to the logfile
#
# RET:   1  - Not connected to database
#        0  - Success
#        -1 - Error disconnecting - returned from
#
# HIST:  
#
#======================================================================
sub open_log {
   my ($self, $log_file) = @_;

   my $rc = 1;
   
   if($self->{-open}) {
      if(! $self->{-log}) {
         $rc = $self->{-mql}->open_log($log_file);
      }

      $self->{-log} = 1;
   }
   
   return $rc;
}





#======================================================================
# NAME:  set_context() 
#
# DESC:  Set context in a eMatrix Session using eMatrix::Context
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
   my ($self, $user, $passwd, $vault) = @_;

   my $rc = 1;
   my (@output, @error);

   if ($self->{-open}) {
      ($rc, @output, @error) = 
          $self->{-context}->set_context($user, $passwd, $vault);

      push(@{$self->{-ctx_stack}}, $self->{-context});
      #$self->{-ctx_stack} = ();
   }

   return $self->set_error(@output);

   # return $rc;
}




#======================================================================
# NAME:  push_context() 
#
# DESC:  Pushes context to another Person using eMatrix::Context
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
   my ($self, $user, $passwd, $vault, $other) = @_;

   my $rc = 1;
   my (@output, @error);

   if($self->{-open}) {
      #my %current_context = %{$self->{-context}};

      ($rc, @output, @error) = 
          $self->{-context}->push_context($user, $passwd, $vault, $other);
     
      my $current_context = $self->{-context};

      #if (!$rc) {
         #push(@{$self->{-ctx_stack}}, \%current_context);
      #}

      push(@{$self->{-ctx_stack}}, $current_context);
   }
   
   # return $rc;

   return $self->set_error(@output);
}




#======================================================================
# NAME:  pop_context() 
#
# DESC:  Pops context using eMatrix::Context Object
#        
#
# ARGS:  NONE
#
# RET:   1  - Failure
#        0  - Success
#
# HIST:  
#
#======================================================================
sub pop_context {
   my ($self) = @_;

   my $rc = 1;
   my (@output, @error);
   
   if($self->{-open}) {      
      ($rc, @output, @error) = $self->{-context}->pop_context();

      if (!$rc) {
         $self->{-context} = pop(@{$self->{-ctx_stack}});
      }
   }
   
   # return $rc;

   return $self->set_error(@output);
}






#======================================================================
# NAME:  get_context() 
#
# DESC:  Returns eMatrix::Context contained with this eMatrix::DB Object
#
# ARGS:  NONE
#
# RET:   eMatrix::Context Object
#
# HIST:  
#
#======================================================================
sub get_context {
   my ($self) = @_;
   
   return $self->{-context};
}





#======================================================================
# NAME:  list_type() 
#
# DESC:  Gets a list of eMatrix TYPE Objects from the current
#        database matching a name using MQL wildcard rules
#
# ARGS:  Name of the TYPE to match - wildcards allowed
#        If a type is not supplied all will be returned
#
# RET:   List of Type Objects
#
# HIST:  
#
#======================================================================
sub list_type {
   my ($self, $type) = @_;

   if($self->{-open}) {
      return eMatrix::Type::list_type($self, $type);
   }
   else {
      my @empty = ();
      return @empty;
   }
}




#======================================================================
# NAME:  list_attribute() 
#
# DESC:  Gets a list of eMatrix ATTRIBUTE Objects from the current
#        database matching a name using MQL wildcard rules
#
# ARGS:  Name of the TATTRIBUTE to match - wildcards allowed
#        If an attribute is not supplied all will be returned
#
# RET:   List of Attribute Objects
#
# HIST:  
#
#======================================================================
sub list_attribute {
   my ($self, $attr) = @_;

   if($self->{-open}) {
      return eMatrix::Attribute::list_attribute($self, $attr);
   }
   else {
      my @empty = ();
      return @empty;
   }
}



#======================================================================
# NAME:  list_relationship() 
#
# DESC:  Gets a list of eMatrix RELATIONSHIP Objects from the current
#        database matching a name using MQL wildcard rules
#
# ARGS:  Name of the Relationship to match - wildcards allowed
#        If an relationship is not supplied all will be returned
#
# RET:   List of Relationship Objects
#
# HIST:  
#
#======================================================================
sub list_relationship {
   my ($self, $rel) = @_;

   if($self->{-open}) {
      return eMatrix::Relationship::list_relationship($self, $rel);
   }
   else {
      my @empty = ();
      return @empty;
   }
}



#======================================================================
# NAME:  list_person() 
#
# DESC:  Gets a list of eMatrix Person Objects from the current
#        database matching a name using MQL wildcard rules
#
# ARGS:  Name of the Person to match - wildcards allowed
#        If a person name is not supplied all will be returned
#
# RET:   List of Person Objects
#
# HIST:  
#
#======================================================================
sub list_person {
   my ($self, $person) = @_;

   if($self->{-open}) {
      return eMatrix::Person::list_person($self, $person);
   }
   else {
      my @empty = ();
      return @empty;
   }
}


#======================================================================
# NAME:  list_group() 
#
# DESC:  Gets a list of eMatrix Group Objects from the current
#        database matching a name using MQL wildcard rules
#
# ARGS:  Name of the Group to match - wildcards allowed
#        If a Group name is not supplied all will be returned
#
# RET:   List of Group Objects
#
# HIST:  
#
#======================================================================
sub list_group {
   my ($self, $group) = @_;

   if($self->{-open}) {
      return eMatrix::Group::list_group($self, $group);
   }
   else {
      my @empty = ();
      return @empty;
   }
}


#======================================================================
# NAME:  list_role() 
#
# DESC:  Gets a list of eMatrix Role Objects from the current
#        database matching a name using MQL wildcard rules
#
# ARGS:  Name of the Role to match - wildcards allowed
#        If a Role name is not supplied all will be returned
#
# RET:   List of Role Objects
#
# HIST:  
#
#======================================================================
sub list_role {
   my ($self, $role) = @_;

   if($self->{-open}) {
      return eMatrix::Role::list_role($self, $role);
   }
   else {
      my @empty = ();
      return @empty;
   }
}


#======================================================================
# NAME:  list_policy() 
#
# DESC:  Gets a list of eMatrix Policy Objects from the current
#        database matching a name using MQL wildcard rules
#
# ARGS:  Name of the Policy to match - wildcards allowed
#        If a Policy name is not supplied all will be returned
#
# RET:   List of Policy Objects
#
# HIST:  
#
#======================================================================
sub list_policy {
   my ($self, $policy) = @_;

   if($self->{-open}) {
      return eMatrix::Policy::list_policy($self, $policy);
   }
   else {
      my @empty = ();
      return @empty;
   }
}


#======================================================================
# NAME:  list_format() 
#
# DESC:  Gets a list of eMatrix Format Objects from the current
#        database matching a name using MQL wildcard rules
#
# ARGS:  Name of the Format to match - wildcards allowed
#        If a Format name is not supplied all will be returned
#
# RET:   List of Format Objects
#
# HIST:  
#
#======================================================================
sub list_format {
   my ($self, $format) = @_;

   if($self->{-open}) {
      return eMatrix::Format::list_format($self, $format);
   }
   else {
      my @empty = ();
      return @empty;
   }
}


#======================================================================
# NAME:  list_program() 
#
# DESC:  Gets a list of eMatrix Program Objects from the current
#        database matching a name using MQL wildcard rules
#
# ARGS:  Name of the Program to match - wildcards allowed
#        If a Program name is not supplied all will be returned
#
# RET:   List of Program Objects
#
# HIST:  
#
#======================================================================
sub list_program {
   my ($self, $program) = @_;

   if($self->{-open}) {
      return eMatrix::Program::list_program($self, $program);
   }
   else {
      my @empty = ();
      return @empty;
   }
}


#======================================================================
# NAME:  list_vault() 
#
# DESC:  Gets a list of eMatrix Vault Objects from the current
#        database matching a name using MQL wildcard rules
#
# ARGS:  Name of the Vault to match - wildcards allowed
#        If a Vault name is not supplied all will be returned
#
# RET:   List of Vault Objects
#
# HIST:  
#
#======================================================================
sub list_vault {
   my ($self, $vault) = @_;

   if($self->{-open}) {
      return eMatrix::Vault::list_vault($self, $vault);
   }
   else {
      my @empty = ();
      return @empty;
   }
}


#======================================================================
# NAME:  list_store() 
#
# DESC:  Gets a list of eMatrix Store Objects from the current
#        database matching a name using MQL wildcard rules
#
# ARGS:  Name of the Store to match - wildcards allowed
#        If a Store name is not supplied all will be returned
#
# RET:   List of Store Objects
#
# HIST:  
#
#======================================================================
sub list_store {
   my ($self, $store) = @_;

   if($self->{-open}) {
      return eMatrix::Store::list_store($self, $store);
   }
   else {
      my @empty = ();
      return @empty;
   }
}



#======================================================================
# NAME:  set_error() 
#
# DESC:  Parses the Output from an MQL command, looking for either
#        "Error:", "System Error:", or "Warning:".  If any are found
#        Sets the GLobal $ERROR to 1, and pushes Error messages onto
#        Global MQL_ERROR Array.
#
# ARGS:  Output  - Array of output from an MQL command
#
# RET:   Error code (0|1)
#
# HIST:  
#
#======================================================================
sub set_error {
   my $self = shift;

   my $code;

   foreach (@_) {
      chomp;
      next if $_ =~ /$ignore_errors/;
      
      if($_ =~ /^Error: \#(\d+)\: (.*)$/) {
         $code = $1;
         push @{$self->{-mql_error}}, qq(\# $code : $2);
         $self->{-error} = 1;
      }
      elsif($_ =~ /^System Error: \#(\d+)\: (.*)$/) {
         $code = $1;
         push @{$self->{-mql_error}}, qq(\# $code : $2);
         $self->{-error} = 1;
      }
      elsif($_ =~ /^Warning: \#(\d+)\: (.*)$/) {
         $code = $1;
         # push @{$self->{-mql_error}}, qq(\# $code : $2);
         # $self->{-error} = 1;
      }
   }
   
   return $self->{-error};
}



#======================================================================
# NAME:  is_error() 
#
# DESC:  If ERROR is set, return 1.  Otherwise, return 0.
#
# ARGS:  Nothing
#
# RET:   1 OR 0
#
# HIST:  
#
#======================================================================
sub is_error {
   my ($self) = @_;

   return $self->{-error};
}



#======================================================================
# NAME:  set_debug() 
#
# DESC:  Turns debugging on/off
#
# ARGS:  on  = 1
#        off = 0
#
# RET:   Nothing
#
# HIST:  
#
#======================================================================
sub set_debug {
   my ($self, $debug) = @_;

   $self->{-debug} = $debug;
}




#======================================================================
# NAME:  get_error() 
#
# DESC:  If ERROR is set, collect the MQL_ERROR messages, and reset the
#        Globals ERROR, and MQL_ERRORS
#
# ARGS:  Nothing
#
# RET:   List of Error Messages (if any exist)
#
# HIST:  
#
#======================================================================
sub get_error {
   my ($self) = @_;

   my @err_msg = ();

   if($self->{-error}) {
      $self->{-error} = 0;
      @err_msg = @{$self->{-mql_error}};
      @{$self->{-mql_error}} = ();
   }
   
   return @err_msg;
}





#======================================================================
# End of eMatrix::DB
#======================================================================
1;

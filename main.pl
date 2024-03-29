#!/dev/perl/bin/perl

use Thread;
use Thread::Queue;
use LWP::Simple;
use LWP::UserAgent;
#-------------------------
# Variables declaration
#-------------------------
 my $browser = LWP::UserAgent -> new();

# ------------------------
# Subroutine definitions
# ------------------------

# This subprogram intialize all global variables, assignes default values.
sub setup_environment {

  $pending_URLs = new Thread::Queue;

  %check_settings = ( anchor_href => 1,
                    link_href => 0,
                    img_src => 0,
                    frame_src => 0,
                    form_action => 0,
                    css_url => 0 );

  %global_settings = ( max_thread_count => 50,
                     request_interval => 0,
                     timeout => 180,
                     cookies => undef,
                     validation => 'none', # dalsi mozne hodnoty: 'well-formed', 'doctype'
                     check => \%check_settings ); # odkaz na hash %check_settings


}

# Applies passed parameters do global settings
sub apply_parameters {

}

# Configure properties of web agent
sub configure_client   {
  my $agent_string = 'Mozilla/5.0 (Windows NT 6.1; rv:2.0.1) Gecko/20100101 Firefox/4.0.1';
  $browser -> agent($agent_string);
  $browser -> timeout($global_settings{'timeout'});
  $browser -> cookies_jar(HTTP::Cookies -> new());

}

# Comment ...
sub get_URL_list {

}

# According to the settings subroutine makes validation of the page (URL).
sub validate {

}

# Checks whether given URL was already requested.
sub prevent_duplicate {

}


# Comment ...
sub do_request {
#       $browser -> get($url);

}

# This subroutine makes HTTP request
sub verify_URL {


}

# Comment ...
sub is_OK {

}

# Comment ...
sub get_output {


}

# Code of the worker thread
sub worker_thread {

}

# --------------------------
# Code of the main thread
# --------------------------

setup_environment();
apply_parameters();
# run 0. thread
get_output();

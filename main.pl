#!/dev/perl/bin/perl

use Thread;
use Thread::Queue;
use LWP::Simple;

#-------------------------
# Variables declaration
#-------------------------


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
                     validation => 'none', # dalsi mozne hodnoty: 'well-formed', 'doctype'
                     check => \%check_settings ); # odkaz na hash %check_settings


}

# Applies passed parameters do global settings
sub apply_parameters {

}

# Configure properties of web agent
sub configure_client {

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


}

# This subroutine makes HTTP request
sub verify_URL {


}

# Comment ...
sub is_OK() {

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

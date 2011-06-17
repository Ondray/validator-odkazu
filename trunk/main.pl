#!perl
# moje prostredi pouziva jen perl, tak si to kdyztak prosim zmente na /dev/perl/bin/perl

# Tohle si taky kdyztak smazte, delam s tim pres web server, vic mi to vyhovuje.
print "Content-type: text/html\n\n";

use threads; # Library Thread is deprecated use Threads instead.
use threads::shared;
use Thread::Queue;
use LWP::Simple;
use LWP::UserAgent;
use HTML::Parse;

# ------------------------
# Subroutine definitions
# ------------------------

# This subprogram intialize all global variables, assignes default values.
sub setup_environment {

  $links_waiting = new Thread::Queue; #array/buffer of links to be processed
  $results = new Thread::Queue; #array of links that have been processed with response codes.
  share(@processed_links); #shared array with all the links processed.
  $domain; # domain to be checking, the script should not check links outside of this domain.
  
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
sub configure_client   {
# is handled inside the get_URL_list
}

# Takes a URL in a parameter and extracts all URLs into the queue $links_waiting
sub get_URL_list {
  my $body= $_[0];
  # do some parsing:
  my $parsed_html = HTML::Parse::parse_html($body);
  for (@{ $parsed_html->extract_links(qw(a link img frame form)) }) { # HERE YOU CAN ADD WHICH TAGS ARE TO BE PROCESSED.
      my ($link) = @$_; # extract all links
      print "Zarazuji do fronty ".$link . "</br>\n"; # just a debugging print
      $links_waiting->enqueue($link); # adding links to the queue 
  }
}

# According to the settings subroutine makes validation of the page.
sub validate {

}


# Make a HTTP request for the URL in parameter.
sub do_request {
  my $url = $_[0]; # define a URL from parameter
  if (substr($url,0,1) eq "?") #shortened URL
    {
    $url = $domain."/".$url;
    print "Menim URL ze zkracene na ".$url."</br>\n";
    }
  # create UserAgent object
  my $ua = new LWP::UserAgent;
  # set a user agent (browser-id)
  # $ua->agent('Mozilla/5.5 (compatible; MSIE 5.5; Windows NT 5.1)'); # uncomment in case you want this, works without it too.
  # timeout:
  $ua->timeout(15);
  # proceed the request:
  my $request = HTTP::Request->new('GET');
  $request->url($url);  
  return $ua->request($request);
}

# Check if the URL in the parameter is valid (that it doesn't leave the specified domain etc.) and that it hasn't been checked before.
sub verify_URL {
  my $url = $_[0]; # define a URL from parameter
  my $is_OK = 1;
  foreach (@processed_links) {
   	    if ($url eq $_) # if the URL has been checked before
   	      {
   	      print "Odkaz ".$url." jiz byl kontrolovan.</br>\n"; # just a debugging print
          return 0;
          }
      }
  # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!PRIDAT KONTROLU ZDA URL NEOPOUSTI DOMENU.    
  return 1; 
}

# Insert the URL into $processed_links with the response code.
sub move_to_processed {
 my %record = ("URL" => $_[0], "status_code" => $_[1] );
 $results->enqueue($record);
 push(@processed_links, ($_[0]));
}

# Report results inside $processed_links
sub get_output {

}

# Code of the worker thread
sub worker_thread {
  if(verify_URL($_[0])==1) # check if the URL in the parameter is valid (that it doesn't leave the specified domain etc.) and that it hasn't been checked before.
    {  
    my $response = do_request($_[0]); 
    my $code = $response->code; # response code (like 200, 404, etc)
    # my $headers = $response->headers_as_string; # headers (Server: Apache, Content-Type: text/html, ...) - If you want it uncomment it.
    my $body =  $response->content;  # HTML body:
    get_URL_list($body); # loads all all the URLs from 1st parameter into the $links_waiting variable.
    move_to_processed($_[0], $code); # Insert the URL into $processed_links with the response code.
    my $next_url = $links_waiting->dequeue();
    print "Poustim dalsi vlakno pro ".$next_url."</br>\n";
    my $child_threads = threads->create('worker_thread', $next_url); # !!!!!!!!!!!!!!!!!ADD LIMITATION FOR NUMBER OF THREADS + CYCLE FOR RUNNING MORE THREADS.
    $child_threads->join();
    }
  else # case that URL has been checked before or goes outside of domain.
    {
    print "Vlakno pro  ".$_[0]." se neprovedlo</br>\n";
    return 0; # maybe child_thread->exit() should be here? Not sure.....
    }
  }

# --------------------------
# Code of the main thread
# --------------------------

setup_environment();
apply_parameters();
$domain = "http://www.skolkar.cz";
$threads = threads->create('worker_thread', $domain); # run 0. thread
$threads->join();
get_output();

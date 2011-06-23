#!/usr/bin/perl
# moje prostredi pouziva jen perl, tak si to kdyztak prosim zmente na /dev/perl/bin/perl

# Tohle si taky kdyztak smazte, delam s tim pres web server, vic mi to vyhovuje.
print "Content-type: text/html\n\n";

#------------------------
# Usings
#------------------------
use threads; # Library Thread is deprecated use Threads instead.
use threads::shared;
use threads qw(yield);
use Thread::Queue;
use Thread::Semaphore;
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
  $domain; # domain to be checking, the script should not check links outside of this domain. Zada uzivatel (diky tomu bude mozne provadet check v cele domene 2. radu a nebo jen napr. v nejake subdomene - dle toho, co se zada)
  $first_url; # prvni URL ke kontrole (zadava user) 
  
  %check_settings = ( a => 1,
                    link => 0,
                    img => 0,
                    frame => 0,
                  #  css_url => 0,   nevim jak by se resilo - je to naprosto odlisny od ostatnich odkazu
                    form => 0 );

  %global_settings = ( max_thread_count => 10,
                     request_interval => 0,
                     timeout => 180,
                     cookies => undef,
                     validation => 'none', # dalsi mozne hodnoty: 'well-formed', 'doctype'
                     check => \%check_settings ); # odkaz na hash %check_settings

  $pending_empty = Thread::Semaphore -> new(1);
  $barrier = Thread::Semaphore -> new(0);

}

# Applies passed parameters to global settings from user
sub apply_parameters {

  print "Zadejte link k provereni: \n";
  chomp  ($first_url = <STDIN>);
  
  print "Zadejte celou adresu domeny (subdomeny), v ramci ktere bude probihat kontrola odkazu: \n";
  chomp  ($domain = <STDIN>);
  
  print "Kontrolovat odkazy typu <a href=\"URL\"></a>? (1=ano, 0=ne) \n";
  chomp  ($check_settings{anchor_href} = <STDIN>); 
  
  print "Kontrolovat odkazy typu <link href=\"URL\" />? (1=ano, 0=ne) \n";
  chomp  ($check_settings{link_href} = <STDIN>);    

  print "Kontrolovat odkazy typu <img src=\"URL\" />? (1=ano, 0=ne) \n";
  chomp  ($check_settings{img_src} = <STDIN>); 

  print "Kontrolovat odkazy typu <frame src=\"URL\" >? (1=ano, 0=ne) \n";
  chomp  ($check_settings{frame_src} = <STDIN>);
  
  print "Kontrolovat odkazy typu <form action=\"URL\" >? (1=ano, 0=ne) \n";
  chomp  ($check_settings{form_action} = <STDIN>);
  
#  print "Kontrolovat odkazy v CSS? (1=ano, 0=ne) \n";
#  chomp  ($check_settings{css_url} = <STDIN>);
  
  print "Zadejte maximalni pocet vlaken: \n";
  chomp  (%global_settings{max_thread_count} = <STDIN>);
  
  print "Zadejte timeout pro vyprseni requestu: \n";
  chomp  (%global_settings{timeout} = <STDIN>); 

}

# Configure properties of web agent
sub configure_client   {
# is handled inside the get_URL_list
  my $agent_string = 'Mozilla/5.0 (Windows NT 6.1; rv:2.0.1) Gecko/20100101 Firefox/4.0.1';
  $browser -> agent($agent_string);
  $browser -> timeout($global_settings{'timeout'});
  $browser -> cookies_jar(HTTP::Cookies -> new());

}

# Takes a URL in a parameter and extracts all URLs into the queue $links_waiting
sub get_URL_list {
  my $body = $_[0];
  
  # do some parsing:
  my $parsed_html = HTML::Parse::parse_html($body);
  
  # extrahovani tagu, ktere se maji kontrolovat z %check_settings, do retezce
  my $tags = "";
  while (($key, $value) = each(%check_settings)){
    if ($value == 1) {
      $tags = $tags . " " . $key;
    }
  } 
  
  for ( @{ $parsed_html -> extract_links(qw($tags)) } ) # TAGS ARE TAKEN FROM SETTINGS!
  { 
      my ($link) = @$_; # extract all links
      print "Zarazuji do fronty " . $link . "</br>\n"; # just a debugging print
      $links_waiting -> enqueue($link); # adding links to the queue 
      $pending_empty -> up();
  }
}

# According to the settings subroutine makes validation of the page.
sub validate {

}


# Make a HTTP request for the URL in parameter.
sub do_request {
  my $url = $_[0]; # define a URL from parameter
  if ( (substr($url,0,1) eq "?") or (substr($url,0,1) eq "/") ) #shortened URL, muze byt i relativni zacinajici znakem /
  {
    $url = $domain."/".$url;
    print "Menim URL ze zkracene na ".$url."</br>\n";
  }
  # create UserAgent object
  my $ua = new LWP::UserAgent;
  # VOLAT MISTO TOHO configure_client!!!!
  # set a user agent (browser-id)
  # $ua->agent('Mozilla/5.5 (compatible; MSIE 5.5; Windows NT 5.1)'); # uncomment in case you want this, works without it too.
  # timeout:
  $ua->timeout(15); # IS TAKEN FROM SETTINGS
  
   
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
  # pokud to neni zkracena URL && domena neni obsazena v $url    
  if ( ((substr($url,0,1) ne "?") || (substr($url,0,1) eq "/")) && (index($domain,$url) == -1) ) {
    print "Odkaz ".$url." vede mimo zadanou domenu.</br>\n"; # just a debugging print
    return 0;
  }
  return 1; 
}

# Insert the URL into $processed_links with the response code.
sub move_to_processed {
 my %record = ("URL" => $_[0], "status_code" => $_[1] );
 $results->enqueue($record);
 push(@processed_links, ($_[0]));
}

# Report results inside $results
# Nyni alespon ve forme jednoducheho vypisu url a kodu
sub get_output {
  for my $i (0 .. $results->pending() - 1){
    my %record = $results->peek($i);
    print "Kontrolovany odkaz: " . $record{URL} . ", kod: " . $record{status_code} . " \n";
  }
}

# Code of the worker thread
sub worker_thread {
  
  print "Pending links: " . $links_waiting -> pending() . "\n";
  if ($links_waiting -> pending() == 1)
  {
    $pending_empty -> down();
  }
  
  my ($current_URL) = $links_waiting -> dequeue();
  
  print "Current URL: " . $current_URL . "\n";
  
  if ($current_URL && (verify_URL($current_URL) == 1)) # check if the URL in the parameter is valid (that it doesn't leave the specified domain etc.) and that it hasn't been checked before.
  {  
    my $response = do_request($current_URL); 
    my $code = $response->code; # response code (like 200, 404, etc)
    # my $headers = $response->headers_as_string; # headers (Server: Apache, Content-Type: text/html, ...) - If you want it uncomment it.
    my $html =  $response->content;  # HTML -- entire HTML code, not only Body section
    
    
    
    get_URL_list($html); # loads all all the URLs from 1st parameter into the $links_waiting variable.
    
    move_to_processed($_[0], $code); # Insert the URL into $processed_links with the response code.
    
    #my $next_url = $links_waiting->dequeue();
    
    #print "Poustim dalsi vlakno pro ".$next_url."</br>\n";    

    #my $child_threads = threads->create('worker_thread'); # !!!!!!!!!!!!!!!!!ADD LIMITATION FOR NUMBER OF THREADS + CYCLE FOR RUNNING MORE THREADS.
    #$child_threads->join();
    
    my $c = threads->list(threads::running);
    print "Prave bezi " . $c . " vlaken.\n";
    if ($c == 1)
    {
        #$barrier -> up();
        threads->self() -> join();
    }
    
  }
  else # case that URL has been checked before or goes outside of domain.
  {
    print "Vlakno pro  ". $current_URL ." se neprovedlo</br>\n";
    return 0; # maybe child_thread->exit() should be here? Not sure.....
  }
}

# --------------------------
# Code of the main thread
# --------------------------

setup_environment();
apply_parameters();

$links_waiting -> enqueue($first_url);
#$threads = threads->create('worker_thread'); # run 0. thread



for (my $i = 0; $i < $global_settings{'max_thread_count'}; $i ++) 
{
  my $th = threads->create('worker_thread');
  
}


# print "Vypis vlaken"
# foreach my $th (threads -> list()) 
# {
    # print "Vlakno " . $th -> tid() . ". \n";
# }


$barrier -> down();

#$threads->join();
get_output();

# Thread::Delay

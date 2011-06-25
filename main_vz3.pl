#!/perl/bin/perl
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
  share(%processed_links); #shared array with all the links processed.
  $domain; # domain to be checking, the script should not check links outside of this domain.
  
  %check_settings = ( anchor_href => 1,
                    link_href => 0,
                    img_src => 0,
                    frame_src => 0,
                    form_action => 0,
                    css_url => 0 );

  %global_settings = ( max_thread_count => 10,
                     request_interval => 0,
                     timeout => 180,
                     cookies => undef,
                     validation => 'none', # dalsi mozne hodnoty: 'well-formed', 'doctype'
                     check => \%check_settings ); # odkaz na hash %check_settings

  $pending_empty = Thread::Semaphore -> new(1);
  $barrier = Thread::Semaphore -> new(0);
  share ($barrier);
  our $waiting_thread_count :shared = 0 ;

}

# Applies passed parameters to global settings from user
sub apply_parameters {

}

# Configure properties of web agent
sub configure_client   {
# is handled inside the get_URL_list
  my $agent_string = 'Mozilla/5.0 (Windows NT 6.1; rv:2.0.1) Gecko/20100101 Firefox/4.0.1';
  $browser -> agent($agent_string);
  $browser -> timeout($global_settings{'timeout'});
  $browser -> cookies_jar(HTTP::Cookies -> new());

}


sub extract_content_links
{
  my $parsed_content = HTML::Parse::parse_html($_[0]);
  
  # TAGS ARE TAKEN FROM SETTINGS!
  return @{$parsed_content->extract_links(qw(a link img frame form))}; 
}

# Takes a URL in a parameter and extracts all URLs into the queue $links_waiting
sub get_URL_list {
  
  my @link_list = extract_content_links($_[0]);
  
  print threads->tid(). ": Naslo se ". scalar(@link_list) . " linku.";
  print " Fronta obsahuje ". $links_waiting->pending() . " polozek. <br />\n";
  
  if (scalar(@link_list) == 0)
  {
    
    print threads->tid() ."#$%^& naslo se 0 URL. <br />\n";  
      
    if ($links_waiting->pending() == 0)
    {
      #$waiting_thread_count++;
      print "#############"; 
    }
  }
  
  #print threads->tid() .": Vypis nalezenych URL\n";
  
  # flag - true when all URLs found in link_list are already visited; if the value stay equal 1 then all links were already visited
  $all_visited = 1;
  
  for ( @link_list ) 
  { 
      # extract all links
      my ($link) = @$_; 
      
      # just a debugging print
      #print threads->tid() .": Zarazuji do fronty " . $link . "</br>\n"; 
      
      if (substr($link, 0, 1) eq "?") #shortened URL
      {
        $link = $domain."/".$link;
        #print "Menim URL ze zkracene na ".$link."</br>\n";
      }
      
      if (verify_URL($link))
      {
        # adding links to the queue 
        $links_waiting -> enqueue($link); 
        print threads->tid() .": Signal pro pending_empty. <br />\n";
        $pending_empty -> up();
        $all_visited = 0;
      }
  }    


  if ($all_visited)
  {
    print threads->tid() . ": Vsechna nalezena URL uz byla navstivena.<br />\n";
    $waiting_thread_count++;
  }
  
}

# According to the settings subroutine makes validation of the page.
sub validate {

}


# Make a HTTP request for the URL in parameter.
sub do_request {
  my $url = $_[0]; # define a URL from parameter

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

# Method returns true if passed URL leaves the domain; 1 argument: URL
sub is_leaving_domain
{
  my $url = shift;
  
  # $1 ... protocol
  # $2 ... www part
  # $3 ... domain without www
  # $4 ... URL path beginning with slash

  $url =~ /^(http:\/\/)?(www.?\.)?((?:\w+\.)+\w{1,3})(\/$|\/.*|$)/;
 
  my $url_domain = $3;
  
  $domain =~ /^(http:\/\/)?(www.?\.)?((?:\w+\.)+\w{1,3})(\/$|\/.*|$)/;
  
  # Check if link routes out of the domain
  if ($url_domain ne $3)
  {
      print threads->tid().": IS_LEAVING_DOMAIN -- Odkaz vede mimo domenu. <br />\n";
      return 1;
  }
  
  return 0;
}

# Check if the URL in the parameter is valid (that it doesn't leave the specified domain etc.) and that it hasn't been checked before.
sub verify_URL {
  my $url = $_[0]; # define a URL from parameter
  
  if ($processed_links{$url})
  {  
    # URL uz byla navstivena
    print threads->tid().": VERIFY_URL -- Odkaz ".$url." jiz byl kontrolovan.</br>\n"; 
    return 0;
  }
  else 
  {
    # pridat URL
    $processed_links{$url} = 1;
    
    return (! is_leaving_domain($url));
  }
    
}

# Insert the URL into $processed_links with the response code.
sub move_to_processed {
 my %record = ("URL" => $_[0], "status_code" => $_[1] );
 $results->enqueue($record);
 #push(@processed_links, ($_[0]));
}

# Report results inside $processed_links
sub get_output {

}

sub print_threads 
{
  print "Vypis vlaken";
  foreach my $th (threads -> list()) 
  {
      print "Vlakno " . $th -> tid() . ". <br />\n";
  }  
}

sub threads_count
{
  my $c = threads->list(threads::running);
  
  return $c;
}

# Code of the worker thread
sub worker_thread {
  
  while (1)
  {
    
    print threads->tid() .": Pending links: " . $links_waiting -> pending() . "<br />\n";
    print threads->tid() .": Pocet cekajicich vlaken: $waiting_thread_count <br />\n";

    if ($links_waiting -> pending() == 0)
    {
      if ($waiting_thread_count + 1 == threads_count())
      {
         # posledni vlakno vzbudi hlavni proces
         print "Predavam rizeni";
         $bariera->up();
      }  
    }
    
    # tady se zastavi, kdyz bude fronta prazdna
    print threads->tid() .": Semafor - pending_empty<br />\n";
    $pending_empty->down();
    print threads->tid() .": Opustilo semafor pending_empty<br />\n";
      
    my $current_URL = $links_waiting -> dequeue();
    
    print threads->tid() . ": URL being visited: " . $current_URL . "<br />\n";
    
    if ($current_URL)
    {
      
      my $response = do_request($current_URL); 
      
      # response code (like 200, 404, etc)      
      my $code = $response->code; 
      
      # HTML -- entire HTML code, not only Body section
      my $html =  $response->content;  
      
      # loads all all the URLs from 1st parameter into the $links_waiting variable.
      get_URL_list($html); 
      
      # Insert the URL into $processed_links with the response code. 
      move_to_processed($_[0], $code); 
    }

  }
}


# --------------------------
# Code of the main thread
# --------------------------

setup_environment();
apply_parameters();
$domain = "http://www.skolkar.cz";
$links_waiting -> enqueue($domain);

for (my $i = 0; $i < $global_settings{'max_thread_count'}; $i ++) 
{
  my $th = threads->create('worker_thread');
}  

$barrier -> down();

print_threads();

foreach my $th (threads -> list()) 
{
      $th->kill(15)->join(); # nebo exit
}
  
get_output();

# Thread::Delay

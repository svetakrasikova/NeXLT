#!/usr/bin/perl -w

use Switch;
#use BerkeleyDB;
use utf8;
use Encode qw/encode decode/;
use IPC::Open2;
use NAT::Client;
use NAT::CGI;
use CGI qw/:standard :cgi-lib/ ;
#use Digest::MD5 qw(md5_hex);
use WebService::Solr;

# Create a new client
my $solr = WebService::Solr->new('http://ec2-54-227-78-139.compute-1.amazonaws.com:8983/solr');

# Current corpus if undefined, without a name
my $crp = undef;
my $name;

# Check if we got a corpus identifier
if (param("crp")) {
  $name = param("crp");
}

# Ok, we didn't get a corpus identifier, just a corpus name
if (param("corpus") && !param("crp")) {
  $crp = param("corpus");
}

# We didn't get a corpus identifier nor a corpus name, so get randomly one.
#($name) = keys %$corpora unless $name;

# Create JavaScript combo-box to change corpus being queried
#my $s = join("\n",
	     #join("\n", map {
	       #"source[\"$_\"]=\"$corpora->{$_}{source}\";"} keys %$corpora),
	     #join("\n", map {
	       #"target[\"$_\"]=\"$corpora->{$_}{target}\";"} keys %$corpora));

my $JSCRIPT = <<"EOS";

var source = new Array("\nEnglish");
var target = new Array("\nFrench", "\nJapanese");

function changeLanguages() {
  var corpus = document.getElementById('crp').value;
  document.getElementById('source').innerHTML = source[corpus];
  document.getElementById('target').innerHTML = target[corpus];
}

function go(l,c) {
  if (parseInt(navigator.appVersion)>=4)
    if (navigator.userAgent.indexOf("MSIE")>0) { //IE 4+
      var sel=document.selection.createRange();
      sel.expand("word");
      window.location="dictionary.cgi?corpus=" + c + "&" + l + "=" + sel.text
    } else // NS4+
      window.location="dictionary.cgi?corpus=" + c + "&" + l + "=" + document.getSelection()
}
EOS

print NAT::CGI::my_header(jscript => $JSCRIPT);
print "<style type=text/css>
 span.searched {
background: yellow;
   #font-weight: bold;
   #color: blue;
 }
a.uiref,a.uiref:hover {
   font-weight: bold;
   color: green;
   text-decoration: none;
}
 span.guessed30 {
background: yellow;
   #font-weight: bold;
   #color: green;
 }
 span.guessed60 {
background: yellow;
        #font-weight: bold;
        #color: green;
 }
 span.guessed100 {
background: yellow;
        #font-weight: bold;
        #color: green;
 }
</style>";
#<link rel='stylesheet' href='http://twitter.github.com/bootstrap/assets/css/bootstrap-1.2.0.min.css'> 
print "<link rel='stylesheet' href='http://langtech.autodesk.com/bootstrap-1.2.0.min.css'> 
<title>Machine Translation at Autodesk</title>
<!--[if lt IE 9]>
      <script src='http://html5shim.googlecode.com/svn/trunk/html5.js'></script>
<![endif]-->
<script type='text/javascript' src='http://code.jquery.com/jquery-1.5.2.min.js'></script>
<script type='text/javascript' src='http://langtech.autodesk.com/bootstrap-dropdown.js'></script>
<script type='text/javascript' src='http://langtech.autodesk.com/table.js'></script>
<section id='navigation'>
  <div class='page-header' style='padding-top:60px;'>
<table style='border:0px;'><tr style='border:0px;'><th style='border:0px;'>
    <h1>&nbsp;NeXLT &ndash; Autodesk Translation Corpus Search</h1>
</th><th style='border:0px;'>
	<a class=\"btn small\" onclick=\"window.open('http://langtech.autodesk.com/nexlthelp.html','NeXLTHelp','width=500,height=600,location=no,titlebar=no,menubar=no,statusbar=no,scrollbars=yes,resizable=yes'); return false;\">About</a></th></tr>
</table>
  </div>
  <div class='topbar-wrapper' style='z-index: 5;'>
    <div class='topbar' data-dropdown='dropdown' >
      <div class='topbar-inner'>
        <div class='container'>
   <h3><a href='/index.html'>Machine Translation at Autodesk</a></h3>
          <ul class='nav'>
     <li><a href='/index.html'>Overview</a></li>
     <li><a href='/productivity.html'>Productivity</a></li>
     <li><a href='/usability.html'>Usability</a></li>
     <li class='dropdown active'><a class='dropdown-toggle'>Corpus Search</a>
      <ul class='dropdown-menu'>
       <li><a href='corpus.cgi'>Bilingual&nbsp;Corpus&nbsp;Search</a></li>
       <!--li><a href='dictionary.cgi'>Probabilistic&nbsp;dictionary</a></li-->
       <li><a href='parallel.cgi'>Full&nbsp;Search&nbsp;Interface</a></li>
      </ul>
     </li>
    </ul>
          <ul class='nav secondary-nav'>
    <li><img src='http://langtech.autodesk.com/ADSK_logo_S_white_web.png'/></li>
          </ul>
        </div>
      </div><!-- /topbar-inner -->
    </div><!-- /topbar -->
  </div><!-- /topbar-wrapper -->
";

#my $x = Vars;
#print pre(Dumper($x));

print start_form();
print "<table>\n";
print Tr(td({-style=>"width:170px;border-bottom: 0px;"},[" ", textfield(-name=>"l1",-size=>160), ]),
	 td({-style=>"border-bottom: 0px;"},submit({-class=>'btn primary',-value=>"Search corpus",-onclick=>"document.getElementById('wait').innerHTML='<img src=wait.gif ></img>';"},"Search")));
print Tr(td({-style=>"border-bottom: 0px;"},[" ","Fields available for search: <em>enu, fra, ita, deu, esp, rus, hun. plk, csy, jpn, chs, cht, kor, product, resource (Software/Screenshot/Documentation), release</em>"]));
print Tr(td({-style=>"border-bottom: 0px;"},[" ","<a target='_blank' href='http://www.solrtutorial.com/solr-query-syntax.html'>Solr query syntax hints</a>"]));
print "</table>";
print "<div align=center id='wait'/>";
#print end_form;

#my %mdhash;
#open (F, "metadata.hash") || die "Could not open file: $!\n";
#while (<F>)
#{
   #chomp;
   #my ($val, $key) = split /\t/;
   #$mdhash{$key} = exists $mdhash{$key} ? "$val" : $val;
   ##$mdhash{$key} .= exists $mdhash{$key} ? "$val" : $val;
#}
#close F;
#my $db = new BerkeleyDB::Hash(-Filename => 'screens.dbm') or print "Cannot open file: $!";
                           #-Flags    => DB_CREATE ) or die "Cannot open file: $!";

my $count = 1000;

# If we have a corpus, and at least one word in one of the two
# languages, then query the server
my $pl1 = param("l1");

#$server = $server1;

if (param("l1")) {

  # variable to store the query results
  my $results;
my $solrr;

  # Check if we are looking for a pattern or a set of words
  $mod = "=";
  #$mod = (param("sequence") && param("sequence") eq "ON") ? "=" : "-";
my $q;


    #$solrq  = WebService::Solr::Query->new( { enu => $pl1 } );
    $solrr = $solr->search( param("l1"),{'rows' => '1000'});
    # We have just source language...
    #$results = $server->conc({count => $count,
			      #crp => $crp,
			      #direction => "$mod>"}, $pl1);
			      #direction => "$mod>"}, param("l1"));

    # get PTDs for all searched words
    #$ptds = get_ptds($server, $crp, "~>", $pl1);
    #$ptds = get_ptds($server, $crp, "~>", param("l1"));

    # We have just the target language
			      #direction => "<$mod"}, param("l2"));

    # get PTDs for all searched words
    #$ptds = get_ptds($server, $crp, "<~", $pl2);
    #$ptds = get_ptds($server, $crp, "<~", param("l2"));

#print $q;
#my $qq = param("l1") . " $tgtlocale:" . param("l2");
#print "$qq";

  # Start to print results
  
#print param("l1") . " -- " . param("l2");
  print "<table class='table-autofilter table-autosort:2 table-filtered-rowcount:resulttablefiltercount table-rowcount:resulttableallcount' id='resulttable' cellspacing='0'>";
print '<colgroup>
    <col width="35%">
    <col width="5%">
    <col width="35%">
    <col width="10%">
    <col width="10%">
    <col width="5%">
  </colgroup>';
print "<thead><tr><th/><th/><th><div id='emptyth'><img src=wait.gif /><p>&nbsp;</p></div></th><th/><th/><th/></tr></thead>";
print "<thead><tr><th>Source</th><th>Locale</th><th>Target</th><th>Product</th><th>Resource</th><th>Release</th></tr></thead>";

  my $i = 0;
	my @tgtlocales = ("deu", "fra", "ita", "esp", "ptb", "rus", "plk", "hun", "csy", "chs", "jpn", "cht", "kor");

  # print the results
for my $doc( $solrr->docs ) {
    $i++;

	#Process hashed product/resource information
        #my $segment = $doc->value_for('enu');
        my $segment = $doc->value_for('enu');
	my $srcscreen = lc($segment); 
	$segment =~ s/</&lt;/g;
	$segment =~ s/>/&gt;/g;
        $product = $doc->value_for('product');
        $resource = $doc->value_for('resource');
	$_->[0] = $segment;
	foreach (@tgtlocales) {
		if(!$doc->value_for($_) eq "") { 
        		$segment = encode("utf-8",$doc->value_for($_));
			$segment =~ s/</&lt;/g;
			$segment =~ s/>/&gt;/g;
			$segment = $_ . "</td><td>" . $segment;
			$tgtlocale = $_;
		}
	}
	$_->[1] = $segment;
        $release = $doc->value_for('release');

my $srccell = $_->[0];
my $tgtcell = $_->[1];
if($resource eq "Screenshot") {
my $srcscreenpath = "enu/$product/enu/" . substr($doc->value_for('path'),0,-4) . ".png";
my $tgtscreenpath = "$tgtlocale/$product/$tgtlocale/" . substr($doc->value_for('path'),0,-4) . ".png";
$srccell = $srccell . " <a class=\"btn small\" onclick=\"window.open('http://ec2-75-101-237-134.compute-1.amazonaws.com/screenshots/$srcscreenpath','SourceScreenshots','location=no,titlebar=no,menubar=no,statusbar=no,scrollbars=yes'); return false;\">&nbsp;<img src='glyphicons_011_camera.png' width=30% />&nbsp;Show</a>";
$tgtcell = $tgtcell . " <a class=\"btn small\" onclick=\"window.open('http://ec2-75-101-237-134.compute-1.amazonaws.com/screenshots/$tgtscreenpath','TargetScreenshots','location=no,titlebar=no,menubar=no,statusbar=no,scrollbars=yes,resizable=yes'); return false;\">&nbsp;<img src='glyphicons_011_camera.png' width=30% />&nbsp;Show</a>";
}

      print Tr(#td({-class=>$i%2?"entry1":"entry2"},
                  #$i),
	       #td({-class=>$i%2?"entry1":"entry2"},
                  #$_->[4]),
	       td({-class=>$i%2?"entry1":"entry2", -ondblclick=>"go('l1','$crp')"},
                  $srccell),
	       td({-class=>$i%2?"entry1":"entry2", -ondblclick=>"go('l2','$crp')"},
                  $tgtcell),
                  #$_->[1] . "<br/><a href=\"http://ec2-75-101-237-134.compute-1.amazonaws.com/screenshots/". gensub$product/$tgtscreen\"" . ".html>screenshot</a>"),
	       td({-class=>$i%2?"entry1":"entry2"},
		  $product),
	       td({-class=>$i%2?"entry1":"entry2"},
		  $resource),
	       td({-class=>$i%2?"entry1":"entry2"},
		  $release));
      print "\n";
    #}
  }
  print "</table>";
	print "<script>document.getElementById('emptyth').innerHTML = 'Total count: " . $i . "<br/><span id=\"resulttablefiltercount\"/>'; document.getElementById('emptyth').className = 'alert-message';</script>"; 
  if ($i == $count) { 
	print "<script>document.getElementById('emptyth').innerHTML += '<p>The query returned more than the maximum " . $count . " results. The below list is therefore incomplete. Consider restricting your search query.</p>';document.getElementById('emptyth').className = 'alert-message error';</script>"; 
  } 
} 
#$db->db_close();


print NAT::CGI::my_footer();

1;

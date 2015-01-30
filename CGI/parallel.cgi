#!/usr/bin/perl -wT
#####################
#
# © 2012–2014 Autodesk Development Sàrl
#
# Created by Mirko Plitt based on the NAT tool
#
# Changelog
# v2.0.1	Modified on 26 May 2014 by Ventsislav Zhechev
# Added Google Analytics code.
# Fixed some bugs that came up with ‘use strict’.
#
# v2			Modified on 22 May 2014 by Ventsislav Zhechev
# Massive clean up of dead code.
# Script now works with ‘use strict’.
# HTML clean up, including specification of character encoding.
# Implemented fixes necessary for the script to work in the new AWS environment.
#
# v1			Modified by Mirko Plitt
# Original production version.
#
#####################

use strict;
use utf8;
use Switch;
use Encode qw/encode decode/;
use CGI qw/:standard :cgi-lib/ ;
use WebService::Solr;

print '<html><head><meta http-equiv="content-type" content="text/html; charset=utf-8">';

# Create a new client
my $solr = WebService::Solr->new('http://aws.stg.solr:8983/solr');

# Current corpus if undefined, without a name
my $crp = "";
my $name = "";

# Check if we got a corpus identifier
if (param("crp")) {
  $name = param("crp");
}

# Ok, we didn't get a corpus identifier, just a corpus name
if (param("corpus") && !param("crp")) {
  $crp = param("corpus");
}


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
print "<link rel='stylesheet' href='/assets/css/bootstrap-1.2.0.min.css'>
<title>Autodesk NeXLT Full Search</title>
<!--[if lt IE 9]>
<script src='http://html5shim.googlecode.com/svn/trunk/html5.js'></script>
<![endif]-->
<script type='text/javascript' src='http://code.jquery.com/jquery-1.5.2.min.js'></script>
<script type='text/javascript' src='/assets/js/bootstrap-dropdown.js'></script>
<script type='text/javascript' src='/assets/js/table.js'></script>
<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

  ga('create', 'UA-51341692-1', 'autodesk.com');
  ga('send', 'pageview');

</script>
</head><body>
<section id='navigation'>
<div class='page-header' style='padding-top:60px;'>
<table style='border:0px;'><tr style='border:0px;'><th style='border:0px;'>
<h1>&nbsp;NeXLT &ndash; Autodesk Translation Corpus Search</h1>
</th><th style='border:0px;'>
<a class=\"btn small\" onclick=\"window.open('/nexlthelp.html','NeXLTHelp','width=500,height=600,location=no,titlebar=no,menubar=no,statusbar=no,scrollbars=yes,resizable=yes'); return false;\">About</a></th></tr>
</table>
</div>
<div class='topbar-wrapper' style='z-index: 5;'>
<div class='topbar' data-dropdown='dropdown' >
<div class='topbar-inner'>
<div class='container'>
<h3><a href='/'>Language Technology at Autodesk</a></h3>
<ul class='nav'>
<li><a href='/index.html'>Overview</a></li>
<li class='dropdown active'><a class='dropdown-toggle'>Corpus Search</a>
<ul class='dropdown-menu'>
<li><a href='/nexlt/corpus.cgi'>Bilingual&nbsp;Corpus&nbsp;Search</a></li>
<li><a href='/nexlt/parallel.cgi'>Full&nbsp;Search&nbsp;Interface</a></li>
</ul>
</li>
<li><a target='_blank' href='/ttc/'>Terminology</a></li>
<li><a href='/productivity.html'>Productivity</a></li>
</ul>
<ul class='nav secondary-nav'>
<li><img src='/images/ADSK_logo_S_white_web.png'/></li>
</ul>
</div>
</div><!-- /topbar-inner -->
</div><!-- /topbar -->
</div><!-- /topbar-wrapper -->
</section>
";

print start_form();
print "<table>\n";
print Tr(td({-style=>"width:170px;border-bottom: 0px;"},[" ", textfield(-name=>"l1",-size=>160), ]),
td({-style=>"border-bottom: 0px;"},submit({-class=>'btn primary',-value=>"Search corpus",-onclick=>"document.getElementById('wait').innerHTML='<img src=/images/wait.gif ></img>';"},"Search")));
print Tr(td({-style=>"border-bottom: 0px;"},[" ","Fields available for search: <em>enu, fra, ita, deu, esp, rus, hun. plk, csy, jpn, chs, cht, kor, product, resource (Software/Screenshot/Documentation), release</em>"]));
print Tr(td({-style=>"border-bottom: 0px;"},[" ","<a target='_blank' href='http://www.solrtutorial.com/solr-query-syntax.html'>Solr query syntax hints</a>"]));
print "</table>";
print "<div align=center id='wait'/>";

my $count = 1000;

# If we have a corpus, and at least one word in one of the two
# languages, then query the server
my $pl1 = param("l1");


if (param("l1")) {
	
  # variable to store the query results
  my $results;
	my $solrr;
	
  # Check if we are looking for a pattern or a set of words
	my $q;
	
	
	$solrr = $solr->search( param("l1"),{'rows' => '1000'});
	
  # Start to print results
  
  print "<table class='table-autofilter table-autosort:2 table-filtered-rowcount:resulttablefiltercount table-rowcount:resulttableallcount' id='resulttable' cellspacing='0'>";
	print '<colgroup>
	<col width="35%">
	<col width="5%">
	<col width="35%">
	<col width="10%">
	<col width="10%">
	<col width="5%">
  </colgroup>';
	print "<thead><tr><th/><th/><th><div id='emptyth'><img src=/images/wait.gif /><p>&nbsp;</p></div></th><th/><th/><th/></tr></thead>";
	print "<thead><tr><th>Source</th><th>Locale</th><th>Target</th><th>Product</th><th>Resource</th><th>Release</th></tr></thead>";
	
  my $i = 0;
	my @tgtlocales = ("deu", "fra", "ita", "esp", "ptb", "rus", "plk", "hun", "csy", "chs", "jpn", "cht", "kor");
	
  # print the results
	for my $doc( $solrr->docs ) {
    $i++;
		
		#Process hashed product/resource information
		my $segment = $doc->value_for('enu');
		my $srcscreen = lc($segment); 
		my $tgtlocale = "";
		$segment =~ s/</&lt;/g;
		$segment =~ s/>/&gt;/g;
		my $product = $doc->value_for('product');
		my $resource = $doc->value_for('resource');
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
		my $release = $doc->value_for('release');
		
		my $srccell = $_->[0];
		my $tgtcell = $_->[1];
		if($resource eq "Screenshot") {
			my $srcscreenpath = "enu/$product/enu/" . substr($doc->value_for('path'),0,-4) . ".png";
			my $tgtscreenpath = "$tgtlocale/$product/$tgtlocale/" . substr($doc->value_for('path'),0,-4) . ".png";
			$srccell = $srccell . " <a class=\"btn small\" onclick=\"window.open('http://ec2-75-101-237-134.compute-1.amazonaws.com/screenshots/$srcscreenpath','SourceScreenshots','location=no,titlebar=no,menubar=no,statusbar=no,scrollbars=yes'); return false;\">&nbsp;<img src='/images/glyphicons_011_camera.png' width=30% />&nbsp;Show</a>";
			$tgtcell = $tgtcell . " <a class=\"btn small\" onclick=\"window.open('http://ec2-75-101-237-134.compute-1.amazonaws.com/screenshots/$tgtscreenpath','TargetScreenshots','location=no,titlebar=no,menubar=no,statusbar=no,scrollbars=yes,resizable=yes'); return false;\">&nbsp;<img src='/images/glyphicons_011_camera.png' width=30% />&nbsp;Show</a>";
		}
		
		print Tr(
		td({-class=>$i%2?"entry1":"entry2", -ondblclick=>"go('l1','$crp')"},
		$srccell),
		td({-class=>$i%2?"entry1":"entry2", -ondblclick=>"go('l2','$crp')"},
		$tgtcell),
		td({-class=>$i%2?"entry1":"entry2"},
		$product),
		td({-class=>$i%2?"entry1":"entry2"},
		$resource),
		td({-class=>$i%2?"entry1":"entry2"},
		$release));
		print "\n";
  }
  print "</table>";
	print "<script>document.getElementById('emptyth').innerHTML = 'Total count: " . $i . "<br/><span id=\"resulttablefiltercount\"/>'; document.getElementById('emptyth').className = 'alert-message';</script>"; 
  if ($i == $count) { 
		print "<script>document.getElementById('emptyth').innerHTML += '<p>The query returned more than the maximum " . $count . " results. The below list is therefore incomplete. Consider restricting your search query.</p>';document.getElementById('emptyth').className = 'alert-message error';</script>"; 
  } 
} 

print '</body></html>';


1;

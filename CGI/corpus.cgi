#!/usr/bin/perl -w

use Switch;
#use BerkeleyDB;
use utf8;
use Encode qw/encode decode/;
use IPC::Open2;
use NAT::Client;
use NAT::CGI;
use CGI qw/:standard :cgi-lib/ ;
use HTTP::Request::Common;
#use LWP::UserAgent;
#use Digest::MD5 qw(md5_hex);
use WebService::Solr;

# Create a new client
my $solr = WebService::Solr->new('http://ec2-54-227-78-139.compute-1.amazonaws.com:8983/solr');
my $ua = new LWP::UserAgent();

# Current corpus if undefined, without a name
my $crp;
#my $crp = undef;
my $name;
my $corpus;

# Check if we got a corpus identifier
if (param("crp")) {
  $name = param("crp");
}

# Ok, we didn't get a corpus identifier, just a corpus name
if (param("corpus") && !param("crp")) {
  $crp = param("corpus");
  $corpus = param("corpus");
  $name = param("corpus");
}

# We didn't get a corpus identifier nor a corpus name, so get randomly one.
#($name) = keys %$corpora unless $name;
my $tgtlocale;
switch ($name) {
	case /Arabic/	{ $tgtlocale = "ara";}
	case /ara/	{ $corpus = "Arabic";}
	case /Chinese Simplified/	{ $tgtlocale = "chs";}
	case /chs/	{ $corpus = "Chinese Simplified";}
	case /Chinese Traditional/	{ $tgtlocale = "cht";}
	case /cht/	{ $corpus = "Chinese Traditional";}
	case /Czech/	{ $tgtlocale = "csy";}
	case /csy/	{ $corpus = "Czech";}
	case /Danish/	{ $tgtlocale = "dnk";}
	case /dnk/	{ $corpus = "Danish";}
	case /Dutch/	{ $tgtlocale = "nld";}
	case /nld/	{ $corpus = "Dutch";}
	case /English Australia/	{ $tgtlocale = "ena";}
	case /ena/	{ $corpus = "English Australia";}
	case /English UK/	{ $tgtlocale = "eng";}
	case /eng/	{ $corpus = "English UK";}
	case /Finnish/	{ $tgtlocale = "fin";}
	case /fin/	{ $corpus = "Finnish";}
	case /French France/	{ $tgtlocale = "fra";}
	case /fra/	{ $corpus = "French France";}
	case /French Belgium/	{ $tgtlocale = "frb";}
	case /frb/	{ $corpus = "French Belgium";}
	case /French Canada/	{ $tgtlocale = "frc";}
	case /frc/	{ $corpus = "French Canada";}
	case /German/	{ $tgtlocale = "deu";}
	case /deu/	{ $corpus = "German";}
	case /Greek/	{ $tgtlocale = "ell";}
	case /ell/	{ $corpus = "Greek";}
	case /Hebrew/	{ $tgtlocale = "heb";}
	case /heb/	{ $corpus = "Hebrew";}
	case /Hindi/	{ $tgtlocale = "hin";}
	case /hin/	{ $corpus = "Hindi";}
	case /Hungarian/	{ $tgtlocale = "hun";}
	case /hun/	{ $corpus = "Hungarian";}
	case /Indonesian/	{ $tgtlocale = "ind";}
	case /ind/	{ $corpus = "Indonesian";}
	case /Italian/	{ $tgtlocale = "ita";}
	case /ita/	{ $corpus = "Italian";}
	case /Japanese/	{ $tgtlocale = "jpn";}
	case /jpn/	{ $corpus = "Japanese";}
	case /Korean/	{ $tgtlocale = "kor";}
	case /kor/	{ $corpus = "Korean";}
	case /Norwegian/	{ $tgtlocale = "nor";}
	case /nor/	{ $corpus = "Norwegian";}
	case /Polish/	{ $tgtlocale = "plk";}
	case /plk/	{ $corpus = "Polish";}
	case /Portuguese Brazil/	{ $tgtlocale = "ptb";}
	case /ptb/	{ $corpus = "Portuguese Brazil";}
	case /Portuguese Portugal/	{ $tgtlocale = "ptg";}
	case /ptg/	{ $corpus = "Portuguese Portugal";}
	case /Romanian/	{ $tgtlocale = "rom";}
	case /rom/	{ $corpus = "Romanian";}
	case /Russian/	{ $tgtlocale = "rus";}
	case /rus/	{ $corpus = "Russian";}
	case /Slovak/	{ $tgtlocale = "slk";}
	case /slk/	{ $corpus = "Slovak";}
	case /Spanish Spain/	{ $tgtlocale = "esp";}
	case /esp/	{ $corpus = "Spanish Spain";}
	case /Spanish Mexico/	{ $tgtlocale = "las";}
	case /las/	{ $corpus = "Spanish Mexico";}
	case /Swedish/	{ $tgtlocale = "swe";}
	case /swe/	{ $corpus = "Swedish";}
	case /Thai/	{ $tgtlocale = "tha";}
	case /tha/	{ $corpus = "Slovak";}
	case /Turkish/	{ $tgtlocale = "tur";}
	case /tur/	{ $corpus = "Turkish";}
	case /Vietnamese/	{ $tgtlocale = "vit";}
	case /vit/	{ $corpus = "Vietnamese";}
	else	{ $tgtlocale = "enu";} 
}

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

# Get date of last refresh from Solr server
$ua = LWP::UserAgent->new;
my $r = $ua->head('http://ec2-54-227-78-139.compute-1.amazonaws.com:4000/lastrefresh');
my $lastrefresh = $r->header('Last-Modified');

print "<link rel='stylesheet' href='http://ec2-184-73-254-194.compute-1.amazonaws.com/bootstrap-1.2.0.min.css'> 
<title>Language Technology at Autodesk</title>
<!--[if lt IE 9]>
      <script src='http://html5shim.googlecode.com/svn/trunk/html5.js'></script>
<![endif]-->
<script type='text/javascript' src='http://code.jquery.com/jquery-1.5.2.min.js'></script>
<script type='text/javascript' src='http://ec2-184-73-254-194.compute-1.amazonaws.com/bootstrap-dropdown.js'></script>
<script type='text/javascript' src='http://ec2-184-73-254-194.compute-1.amazonaws.com/table.js'></script>
<section id='navigation'>
  <div class='page-header' style='padding-top:60px;'>
<table style='border:0px;'><tr style='border:0px;'><th style='border:0px;'>
    <h1>&nbsp;NeXLT &ndash; Autodesk Translation Corpus Search</h1>
</th><th style='border:0px;'>
	<a class=\"btn small\" onclick=\"window.open('http://ec2-184-73-254-194.compute-1.amazonaws.com/nexlthelp.html','NeXLTHelp','width=500,height=600,location=no,titlebar=no,menubar=no,statusbar=no,scrollbars=yes,resizable=yes'); return false;\">About</a></th></tr>
<tr>
<div align=right><span class=\"alert-message info\">Last refresh of software translations: $lastrefresh </span></div>
</table>
  </div>
  <div class='topbar-wrapper' style='z-index: 5;'>
    <div class='topbar' data-dropdown='dropdown' >
      <div class='topbar-inner'>
        <div class='container'>
   <h3><a href='/index.html'>Language Technology at Autodesk</a></h3>
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
    <li><img src='http://ec2-184-73-254-194.compute-1.amazonaws.com/ADSK_logo_S_white_web.png'/></li>
          </ul>
        </div>
      </div><!-- /topbar-inner -->
    </div><!-- /topbar -->
  </div><!-- /topbar-wrapper -->
";

#my $x = Vars;
#print pre(Dumper($x));

#if (param("l1")) {
	#$ua->agent('perlproc/1.0');
	#my $response = $ua->post(url(), "searchform");
#}
print start_form(-name=>"searchform");
print "<table>\n";
print Tr(td({-rowspan=>'3',-style=>"border-bottom: 0px;"}, "&nbsp;"),
	 td({-rowspan=>'3',-style=>"border-bottom: 0px;"}, "&nbsp;&nbsp;&nbsp;"),
	 td({-colspan=>6, -style=>"text-align: left;border-bottom: 0px;"},
	    "Target Language: ",popup_menu(-onchange=>"changeLanguages();",
				  -name=>'crp',
				  -id => 'crp',
				  -default=>"$corpus",
				  -values=>[
					"Arabic",
					"Chinese Simplified",
					"Chinese Traditional",
					"Czech",
					"Danish",
					"Dutch",
					"English Australia",
					"English UK",
					"Finnish",
					"French Belgium",
					"French Canada",
					"French France",
					"German",
					"Greek",
					"Hebrew",
					"Hindi",
					"Hungarian",
					"Indonesian",
					"Italian",
					"Japanese", 
					"Korean",
					"Norwegian",
					"Polish",
					"Portuguese Brazil",
					"Portuguese Portugal",
					"Romanian",
					"Russian",
					"Spanish Mexico",
					"Spanish Spain",
					"Slovak",
					"Swedish",
					"Thai",
					"Turkish",
					"Vietnamese"
					])));
print Tr(td({-style=>"border-bottom: 0px;"},["Search source language for:",
             textfield("l1"),
	    ]),
	 td({-style=>"border-bottom: 0px;"},submit({-class=>'btn primary',-value=>"Search corpus",-onclick=>"document.getElementById('wait').innerHTML='<img src=wait.gif ></img>';"},"Search")));
my $imgsearch;
if (param("l1")) { $imgsearch = "<a class='btn success' target=_blank href='http://www.google.com/search?tbm=isch&q=site:autodesk.com " . param("l1") . "'>Find related images on Autodesk websites</a>"; }
else { if (param("l2")) { $imgsearch = "<a class='btn success' target=_blank href='http://www.google.com/search?tbm=isch&q=site:autodesk.com " . param("l2") . "'>Find related images on Autodesk websites</a>"; }}
print Tr(td({-style=>"border-bottom: 0px;"},["Search target language for:",
             textfield("l2")]),
	 td({-style=>"text-align: left;border-bottom: 0px;"},
	$imgsearch
	   ));
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
$pl1 =~ s/:/ /g;
my $pl2 = param("l2");
$pl2 =~ s/:/ /g;

#$server = $server1;

if ((param("l1") || param("l2"))) {

  # variable to store the query results
  my $results;
my $solrr;
  my $ptds;

  # Check if we are looking for a pattern or a set of words
  #$mod = "=";
  #$mod = (param("sequence") && param("sequence") eq "ON") ? "=" : "-";
my $q;

  if (param("l1") && !param("l2")) {

    #$solrq  = WebService::Solr::Query->new( { enu => $pl1 } );
    $q = $tgtlocale . ":['' TO *] AND " . 'enu:' . $pl1;
    $solrr = $solr->search($q,{'rows' => '10000'});
    # We have just source language...
    #$results = $server->conc({count => $count,
			      #crp => $crp,
			      #direction => "$mod>"}, $pl1);
			      #direction => "$mod>"}, param("l1"));

    # get PTDs for all searched words
    #$ptds = get_ptds($server, $crp, "~>", $pl1);
    #$ptds = get_ptds($server, $crp, "~>", param("l1"));

  } elsif (param("l2") && !param("l1")) {
    $solrr = $solr->search( "enu:['' TO *] AND " . $tgtlocale . ':' . $pl2,{'rows' => '10000'});
    # We have just the target language
			      #direction => "<$mod"}, param("l2"));

    # get PTDs for all searched words
    #$ptds = get_ptds($server, $crp, "<~", $pl2);
    #$ptds = get_ptds($server, $crp, "<~", param("l2"));

  } else {
    $solrr = $solr->search( 'enu:' . $pl1 . ' AND ' . $tgtlocale . ':' . $pl2, {'rows' => '10000'});
  }
#print $q;
#my $qq = param("l1") . " $tgtlocale:" . param("l2");
#print "$qq";

  # Start to print results
  
#print param("l1") . " -- " . param("l2");
  print "<table class='table-autofilter table-autosort:2 table-filtered-rowcount:resulttablefiltercount table-rowcount:resulttableallcount' id='resulttable' cellspacing='0'>";
print '<colgroup>
    <col width="35%">
    <col width="35%">
    <col width="10%">
    <col width="10%">
    <col width="10%">
  </colgroup>';
print "<thead><tr><th class='table-sortable:length' style='vertical-align:bottom'><p>&nbsp;</p><span class='btn'><b>Sort source by length</b></span></th><th style='vertical-align:bottom' class='table-sortable:length'><div id='emptyth'><img src=wait.gif /><p>&nbsp;</p></div><span class='btn'>Sort target by length</span></th><th style='vertical-align:bottom' class='table-filterable table-sortable:alphanumeric'><span class='btn'>Sort by product</span></th><th style='vertical-align:bottom' class='filterable'><br/>

<select multiple='multiple' style='height:80px;' onchange='Table.filter(this,this)'><option value='function(){return true;}'>Filter: All</option><option value='function(val){return (val == \"Terminology\");}'>Terminology</option><option value='function(val){return (val == \"Software\") ;}'>Software</option><option value='function(val){return (val == \"Screenshot\");}'>Screenshots</option><option value='function(val){return (val == \"Documentation\");}'>Documentation</option></select>
<span class='btn' style='visibility:hidden'>DUMMY</span></th>
<th class='table-sortable:alphanumeric'style='vertical-align:bottom'><p>&nbsp;</p><span class='btn'>Sort by release</span></th>
</tr></thead>";
print "<thead><tr><th>Source</th><th>Target</th><th>Product</th><th>Resource</th><th>Release</th></tr></thead>";

  my $i = 0;

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
	#if($resource eq "Documentation") {
		#$_->[0] = taguirefs($segment,$product,$tgtlocale);
	#} else {
		$_->[0] = $segment;
	#}
        $segment = encode("utf-8",$doc->value_for($tgtlocale));
	my $tgtscreen = lc($segment); 
	$segment =~ s/</&lt;/g;
	$segment =~ s/>/&gt;/g;
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
	       #td({-class=>$i%2?"entry1":"entry2", -ondblclick=>"go('l1','$crp')"},
	       #td({-class=>$i%2?"entry1":"entry2", -ondblclick=>"go('l2','$crp')"},
	       td({-class=>$i%2?"entry1":"entry2"},
                  $srccell),
	       td({-class=>$i%2?"entry1":"entry2"},
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
	print "<script>document.getElementById('emptyth').innerHTML += '<p>The query returned more than the maximum " . $count . " results. The below list is therefore incomplete, even when filtered.</p>';document.getElementById('emptyth').className = 'alert-message error';</script>"; 
  } 
} 
#$db->db_close();


print NAT::CGI::my_footer();

sub highlite {
  my ($text, $keywords, $seq) = @_;
$text = " $text ";

  my $x = $keywords;
  $x =~ s/^\s*(.*?)\s*$/$1/;
  if ($seq) {
    $x =~ s/\*/\\S+/g;
    $text =~ s/ ($x) / <span class="searched">$1<\/span> /gi;
    #$text =~ s/\b($x)\b/<span class="searched">$1<\/span>/gi;
  } else {
    $x =~ s/\*//g;
    for my $y (split /\s+/, $x) {
      $text =~ s/ ($y) / <span class="searched">$1<\/span> /gi;
      #$text =~ s/\b($y)\b/<span class="searched">$1<\/span>/gi;
    }
  }
  return $text
}

sub highlite_translation {
  my ($changed, $text, $word, $perc) = (0, @_);
$text = " $text ";

  my $class = class_from_perc($perc);
  $changed = $text =~ s/ (\Q$word\E) / <span class="$class">$1<\/span> /gi;
  #$changed = $text =~ s/\b(\Q$word\E)\b/<span class="$class">$1<\/span>/gi;

  return ($text, $changed);
}

sub class_from_perc {
  my $perc = shift;
  if ($perc < .3) {
    return "guessed30"
  } elsif ($perc < .6) {
    return "guessed60"
  } else {
    return "guessed100"
  }
}

#sub get_ptds {
  #my ($server, $crp, $dir, $words) = @_;
  #return [ map { $server->ptd({crp => $crp,
                               #direction=>$dir},$_) }
           #grep { $_ !~ m"\*" } split /\s+/, $words ];
#}

sub highlite_translations {
  my ($text, $ptds) = @_;
  for my $word (@$ptds) {
    for my $t (@{$word->[1]{'**KEYS**'}}) {
      ($text, my $changed) = highlite_translation($text, $t, $word->[1]{$t});
      last if $changed;
    }
  }
  return $text
}

sub taguirefs {
	#my $blank = " ";
	my $blank = "(<\/span>|<span class=\"(searched|guessed(3|6|10)0)\">| )";
	my $first = "\\b([A-Z]\\w*)\\b";
	my $prep = "( \\& | from | with | by | for | to | in | as? | of |$blank)" ;
	my $second = "\\b([A-Z]\\w*|[23]D[A-Z]*|i-drop|eTransmit|dbconnect)\\b" ;
	my $sequencewob = "($first($prep$second)*|$second($prep$second)+)";
	my $sequence = "(?<seq>\\($sequencewob\\)|$sequencewob)";
	my $initial = "^(?<init>\\($second($prep$second)+\\)|$second($prep$second)+)";
	my $exclusions = "(Command|DIESEL|Any|Unicode|ENTER|Enter|Max|Autodesk (Vault|Inventor|Impression|Revit|Design Review|Navisworks)|Architecture|Civil 3D|Map 3D|Mechanical|Electrical|Buzzsaw|Plots|DWGs?|DWF[x6]?|DXF|UCSs?|PDFs?|DSD|DGN|ISD|PCG|Shift|F1|XSL|CSV|XLSX|BP3)";
	my $triggers = "\\b(submenu|drop[- ]?down|click|select|choose|pane|flyout|pull[- ]?down|panel|dialog|menu|button|toolbar|sets?|displays?|tab|\\&submenu;)\\b";
        my $notfirst = "(An?|For|Opens|Specify|Specifies|Under|The|This|Select|Add|In|If|Displays?|Plots|Choose|Click|Type|Enter|Press|You|Sets?|When|To)\\b";

	my $line = shift;
	my $product = shift;
	my $tgtlocale = shift;
        chomp $line;

	if($line =~ /($triggers)/i) {
		$line =~ s/^(\{\d+\} ?)*$blank?$sequence$blank?(?<colon>: | -+ |(\{\d+\} ?)+)(?<upper>[A-Z])/<a class="uiref">$+{seq}<\/a>$+{colon}i_i_i$+{upper}/;
        	$line =~ s/^($blank?|(\{\d+\}$blank?)+)*$notfirst/$1i_i_i$9/;
        	$line =~ s/$initial/i_i_i $+{init}/;
        	#$line =~ s/(.)$sequence/$1<a class=\"uiref\">$+{seq}<\/a>/g;
        	$line =~ s/(.)$sequence/$1<a class=\"uiref\">$+{seq}<\/a>/g;
        	#$line =~ s/(.)$sequence/$1<a class=\"uiref\" href=\"corpus.cgi?corpus=$tgtlocale&l1=$+{seq} AND product:$product AND (resource:Software OR resource:Screenshot)\">$+{seq}<\/a>/g;
        	$line =~ s/i_i_i ?//;
        	$line =~ s/<a class="uiref"[^>]*> *($exclusions|$notfirst) *<\/a>/$1/g;
	}

        return "$line";
}

sub tokenize {
	my $line = shift;
	return "$line";
}
sub detokenize {
	my $line = shift;
	return "$line";
}

1;

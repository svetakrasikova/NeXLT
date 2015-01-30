var Manager, prodToggle = true, releaseToggle = false, firstQuery = true;

function toggleProd() {
    //toggles ascending or descending prod sort
    prodToggle = !prodToggle;
    managerMaker("prod");
}

function toggleRelease() {
    //toggles ascending or descending release sort
    releaseToggle = !releaseToggle;
    managerMaker("release");
}

function startManager() {
    //keeps search from executing if people are trying to just set parameters
    if (($('#sLangSearch').val().length != 0) || ($('#tLangSearch').val().length != 0)){
        firstQuery = false;
        managerMaker();
    } else {
        //alert('please enter a value in the source language field');
        $('#alertBox').stop().show().css({opacity:1}).fadeOut(3000);
    }
}

function sanitize(tts) {
        var i, clean = "";
        for (i = 0; i < tts.length; i++) {
            if (tts[i].charCodeAt() != 34 && tts[i].charCodeAt() != 39) {
                clean += tts.charAt(i);
            }
        }
        return clean;
     }



function managerMaker(whichSort) {
	if (!(firstQuery)) {
        Manager.init();
	    var langVal = $('#langSelect').val(), langQ = langVal + ':[* TO *]', searchIn = sanitize($('#sLangSearch').val()), rowsReturned = $('#numItemsSelect').val();
	    
        var searchVal = 'enu:"' + searchIn + '"';
        
        Manager.store.addByValue('q', langQ);
        Manager.store.remove('fq');

        //done at two different times hence two different ways
        if ($('#sLangSearch').val() != "") {
	       Manager.store.addByValue('fq', searchVal);
        }
        if ($('#tLangSearch').val() != "") {
            Manager.store.addByValue('fq', langVal + ':"' + sanitize($('#tLangSearch').val()) + '"');
        }

        var prodSelect = 'product:', ps = $('#prodSelect').val();

        if (ps != "null") {
            if (ps.length == 1) {
                prodSelect += '"' + $('#prodSelect').val() + '"';
            
            } else {
                prodSelect += '(';
                for (i = 0; i < ps.length; i++) {
                    prodSelect += '"' + ps[i] + '"';
                    prodSelect += (i < ps.length - 1 ? ' OR ':'');
                }
                prodSelect += ')';
            }

            Manager.store.addByValue('fq', prodSelect);
        }
        
        

        //filter by resource
        if ($('#filterByResource').val() != "null") {
            var fbr = 'resource:' + $('#filterByResource').val();
            Manager.store.addByValue('fq', fbr);
        }

        //sort by product or release
	    switch (whichSort) {
            case "prod":
                var sortVar = "product " + (prodToggle ? "asc" : "desc") + ", srclc asc";
                break;
            case "release":
                var sortVar = "release " + (releaseToggle ? "asc" : "desc") + ", srclc asc";
                break;
            default:
                break;
        }
        if (whichSort == null) {
            sortVar = "srclc asc";
        }
        Manager.store.addByValue('sort', sortVar);

        Manager.store.addByValue('rows', rowsReturned);
	    Manager.store.addByValue('fl', 'product enu resource release productname restype ' + langVal);
	    Manager.doRequest(0);
    }
}

function prodChg() {
    Manager.doRequest(0);
    managerMaker();
}


(function ($) {

  $(function () {
    Manager = new AjaxSolr.Manager({
	    //Staging
// 		solrUrl: 'http://aws.stg.web/search/'
		//Production
		solrUrl: 'http://langtech.autodesk.com/search/'
    });

    Manager.addWidget(new AjaxSolr.ResultWidget({
    	id:'result',
    	target:'#docs'
    }));

    Manager.addWidget(new AjaxSolr.PagerWidget({
    	id: 'pager',
    	target: '#pager',
    	prevLabel: 'Previous',
    	nextLabel: 'Next',
    	innerWindow: 1,
    	renderHeader: function (perPage, offset, total) {
    		$('#pager-header').html($('<span></span>').text('displaying ' + Math.min(total, offset + 1) + ' to ' + Math.min(total, offset + perPage) + ' of ' + total));
    		$('#rResults').text("Total results: " + total);
            $('#rResults').show();
    	}

    }));
  });

})(jQuery);


var Manager;

function managerMaker() {
	//if ($('#sLangSearch').val() != "") {
	    //console.log($('#langSelect').val());
		Manager.init();
	    var langVal = $('#langSelect').val(), langQ = langVal + ':[* TO *]', searchVal = 'enu:' + $('#sLangSearch').val(), rowsReturned = $('#numItemsSelect').val();
	    Manager.store.addByValue('q', langQ);
	    //Manager.store.addByValue('fq', searchVal);
	    //Manager.store.addByValue('fq', 'searchVal');
	    Manager.store.addByValue('fq', searchVal);
	    console.log(rowsReturned);
	    Manager.store.addByValue('rows', rowsReturned);
	    Manager.store.addByValue('fl', 'product enu resource release ' + langVal);
	    /*var params = {
	    	facet: true,
	    	'facet.field': ['enu','id','product', 'resource'],
	    	'facet.limit': 20,
	    	'facet.mincount': 1,
	    	'f.topics.facet.limit': 50,
	    	'json.nl': 'map'
	    };
	    for (var name in params) {
	    	Manager.store.addByValue(name, params[name]);
	    }*/
	    //console.log("langVal: " + langVal + " langQ: " + langQ + " searchVal: " + searchVal);
	    Manager.doRequest();
//	} else {
		//console.log("Search aborted!");
//	}
}

(function ($) {

  $(function () {
    Manager = new AjaxSolr.Manager({
      //solrUrl: 'http://reuters-demo.tree.ewdev.ca:9090/reuters/'
      solrUrl: 'http://10.37.25.140:8983/solr/'
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
    	}

    }));

    //tag cloud addition
    /*var fields = ['enu','id','product', 'resource'];
    for (var i = 0, l = fields.length; i<l; i++) {
    	Manager.addWidget(new AjaxSolr.TagcloudWidget({
    		id:fields[i],
    		target: '#' + fields[i],
    		field: fields[i]
    	}));
    }*/


  });

})(jQuery);


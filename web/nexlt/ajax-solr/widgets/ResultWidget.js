//Every AJAX Solr widget inherits from AbstractTextWidget
(function ($) {
	AjaxSolr.ResultWidget = AjaxSolr.AbstractWidget.extend({
		start:0,
		langVal:9,
		beforeRequest: function () {
			$(this.target).html($('<img>').attr('src', 'images/ajax-loader.gif'));
			langVal = $('#langSelect').val();
		},

		facetLinks: function (facet_field, facet_values) {
			var links=[];
			if(facet_values) {
				for (var i = 0, l = facet_values.length; i < l; i++) {
					if (facet_values[i] !== undefined) {
						links.push(
							$('<a href="#" class="paginate_button"></a>')
							.text(facet_values[i])
							.click(this.facetHandler(facet_field, facet_values[i]))
						);
					} else {
						links.push('No items found in current selection');
					}
				}
			}

			return links;
		},

		facetHandler: function (facet_field, facet_value) {
			var self = this;
			return function() {
				self.manager.store.remove('fq');
				self.manager.store.addByValue('fq', facet_field + ':' + AjaxSolr.Parameter.escapeValue(facet_value));
				self.doRequest();
				return false;
			};
		},

		afterRequest: function() {
			

			$(this.target).empty();
			$(this.target).append('<div class="sOutputTable">');

			var resultsLength = this.manager.response.response.docs.length;

			if (resultsLength > 0) {

				$('.sOutputTable').append('<table id="mytable">');
				$('#mytable').append('<tr><td>Source</td><td>Target</td><td><a href="#" id="prodLink" onClick="toggleProd();">Product</a></td><td>Resource</td><td>Type</td><td><a href="#" id="releaseLink" class="downClass" onclick="toggleRelease();return false;">Release</a></td>');
				
				for (var i=0; i < resultsLength; i++) {
					var doc = this.manager.response.response.docs[i];
					
					
					//$(this.target).append(this.template(doc));
					$('#mytable').append(this.template(doc));
					

					var items = [];
					items = items.concat(this.facetLinks('product', doc.product));
					items = items.concat(this.facetLinks('product name', doc.productname));
					items = items.concat(this.facetLinks('enu', doc.enu));

					//not in use...yet
					var $links = $('#links_' + doc.id);
					$links.empty();
					for (var j = 0, m = items.length; j < m; j++) {
						$links.append($('<li></li>').append(items[j]));
					}
				} // end for
			} else {
				$('.sOutputTable').append('<table><tr><td>Sorry, no results found.  Try searching again.</td></tr></table>');
			}


			$(this.target).append('</div>');

			if (prodToggle) {
	            $('#prodLink').removeClass('upClass');
	            $('#prodLink').addClass('downClass');
	        } else {
	            $('#prodLink').removeClass('downClass');
	            $('#prodLink').addClass('upClass');
	        }

	        if (releaseToggle) {
				$('#releaseLink').removeClass('upClass');
	            $('#releaseLink').addClass('downClass');
	        } else {
	            $('#releaseLink').removeClass('downClass');
	            $('#releaseLink').addClass('upClass');
	        }
		},
		template: function(doc, lang) {
			//THIS IS WHERE TO FORMAT THE OUTPUT!!!
			var snippet = '';
			snippet += '<tr>';
			snippet += '<td>' + doc.enu.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;') + '</td>';			
			snippet += '<td>' + (doc[langVal] != null ? doc[langVal].replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;') : "No data found") + '</td>';
			snippet += '<td><a href="#" class="productA" title="' + productGenerator(doc.productname) + '">' + doc.product + '</a></td>';
			snippet += '<td>' + doc.resource + '</td>';
			snippet += '<td>' + (doc.restype != null ? doc.restype.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;') : '') + '</td>';
			snippet += '<td>' + (doc.release != null ? doc.release.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;') : '') + '</td>';
			snippet += '</tr>';
			return snippet;
		}
	});
})(jQuery);

function productGenerator(prdInput) {
	var outList = '';
	prdInput += '';
	 var inListArray = prdInput.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').split(',');
	 if (inListArray.length == 1) {
	 	outList = '•' + inListArray[0];
	 	return outList;
	 } 
	 for (i=0; i < inListArray.length; i++) {
	 	outList += (i == inListArray.length - 1 ? '•' + inListArray[i] : '•' + inListArray[i] + '<br>');
	 }
	 return outList;
} 


$(document).ready( function() {

    // Variables
    var $container = $('#container');
    var $urlInput = $('#urlInput');

    // jquery.masonry stuff
    var addImgToMasonry = function($imgItem, callback) {
        //$container.append($imgItem).masonry('appended', $imgItem);
        $container.prepend($imgItem).masonry('reload');
        callback();
    };

    // spin.js stuff
    var spinnerOptions = {
        lines: 13, // The number of lines to draw
        length: 7, // The length of each line
        width: 4, // The line thickness
        radius: 10, // The radius of the inner circle
        corners: 1, // Corner roundness (0..1)
        rotate: 0, // The rotation offset
        color: '#000', // #rgb or #rrggbb
        speed: 1, // Rounds per second
        trail: 60, // Afterglow percentage
        shadow: false, // Whether to render a shadow
        hwaccel: false, // Whether to use hardware acceleration
        className: 'spinner', // The CSS class to assign to the spinner
        zIndex: 2e9, // The z-index (defaults to 2000000000)
        top: 'auto', // Top position relative to parent in px
        left: 'auto' // Left position relative to parent in px
    };
    var spinnerTarget = document.getElementById('spinnerDiv');
    var spinner = new Spinner(spinnerOptions);

    // Poshytip stuff
	$urlInput.poshytip({
		content: 'Invalid Url please try again!',
        showOn: 'none',
        className: 'tip-yellow',
        alignTo: 'target',
        alignX: 'left',
        alignY: 'center',
        offsetX: 5
	});

    // Jquery Events
	$('#mainForm').submit(function(event) {
		event.preventDefault();
		var inputUrl = $urlInput.val();
        spinner.spin(spinnerTarget);

		$.post('/validate', {
			url: inputUrl
		}, function(callbackData) {
			var dataParsed = $.parseJSON(callbackData);
            spinner.stop();

			if(dataParsed.error !== undefined) { //Handle error
				$urlInput.poshytip('show');

				setTimeout(
					function() {
						$urlInput.poshytip('update', "Please use the full http:// url");
					}, 2000
				);
			} else { //Display Images
				$urlInput.poshytip('hide');
				$urlInput.poshytip('update', "Invalid Url please try again!");

				for(var index in dataParsed) {
					var $newItem = $("<div class='item'>" + dataParsed[index] + "</div>");

                    addImgToMasonry($newItem, function() {
                        $container.masonry({
                            itemSelector: '.item',
                            isAnimated: true,
                            animationOptions: {
                                duration: 1000,
                                easing: 'linear',
                                queue: false
                            }
                        }).imagesLoaded(function() {
                            $container.masonry('reload');
                        });
                    });
				}
			}
		});
	});
});

$(document).ready( function() {

    var $container = $('#container');

    var addImgToMasonry = function($imgItem, callback) {
        $container.append($imgItem).masonry('appended', $imgItem);
        callback();
    };

    var updateTip = function(code) {
        var message = {
            '404': "That url was not found!",
            '502': "There was a server side error on that page!"
        };

        setTimeout(
            function () {
                $('#urlInput').poshytip('update', message[code]);
            }, 2000
        );
    };

	$('#urlInput').poshytip({
		content: 'Invalid Url please try again!',
        showOn: 'none',
        className: 'tip-yellow',
        alignTo: 'target',
        alignX: 'left',
        alignY: 'center',
        offsetX: 5
	});

	$('#mainForm').submit(function(event) {
		event.preventDefault();
		var inputUrl = $('#urlInput').val();

		$.post('/validate', {
			url: inputUrl
		}, function(callbackData) {
			var dataParsed = $.parseJSON(callbackData);

			if(dataParsed.error !== undefined) { //Handle error
                console.log("code: " + dataParsed.code); // Debug

				$('#urlInput').poshytip('show');

				setTimeout(
					function() {
						$('#urlInput').poshytip('update', "Please use the full http:// url");
					}, 2000
				);
			} else { //Display Images
				$('#urlInput').poshytip('hide');
				$('#urlInput').poshytip('update', "Invalid Url please try again!");

                console.log("Images pulled from " + inputUrl);

				for(var index in dataParsed) {
					console.log(index + " => " + dataParsed[index]);

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

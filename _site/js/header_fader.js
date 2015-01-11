	$(window).on('scroll', function() {
    	if ($(this).scrollTop() > 400 && !$('.header').hasClass('fixed')) {
          $(".site-title").removeClass('white-logo');
          $(".site-title").addClass('black-logo');

          $("nav ul li a").removeClass('white');
          $("nav ul li a").addClass('black');

          $(".header").removeClass('absolute');
          $(".header").addClass('fixed');

          $("button").removeClass('white');
          $("button").addClass('black');

          $(".header").removeClass('transparent');

          $(".header").addClass('bottom-bordered');

          //$( '.header' ).switchClass( "absolute", "fixed", 1000, "easeInOutQuad" );
          //$('.naver').animate({opacity : 1}, 'fast', function() {
          // 	$(this).addClass('visible').removeAttr('style');
       	  //});
    	} else if ($(this).scrollTop() <= 400 && $('.header').hasClass('fixed')) {
          //$('.header').switchClass( "fixed", "absolute", 1000, "easeInOutQuad" );
          $(".header").removeClass('bottom-bordered');

          $("nav ul li a").removeClass('black');
          $("nav ul li a").addClass('white');

          $(".site-title").removeClass('black-logo');
          $(".site-title").addClass('white-logo');

          $("button").removeClass('black');
          $("button").addClass('white');

          $(".header").removeClass('fixed');
          $(".header").addClass('absolute');

          $(".header").addClass('transparent');
       		//$('.naver').animate({opacity : 0}, 'fast', function() {
          // 		$(this).removeClass('visible').removeAttr('style');
       		//});
    	}
	});

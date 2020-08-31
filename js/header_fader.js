  $(window).on('scroll', function() {
      if ($(this).scrollTop() > 400 && !$('header').hasClass('fixed') && $('header').hasClass('naver')) {

          $(".naver").removeClass('white-logo').addClass('black-logo');

          $("nav ul li a").removeClass('white').addClass('black');

          $(".site-title").removeClass('white-logo').addClass('black-logo');

          $(".header").removeClass('absolute').addClass('fixed');

          $("button").removeClass('white').addClass('black');

          $(".header").removeClass('transparent').addClass('bottom-bordered');

          //$( '.header' ).switchClass( "absolute", "fixed", 1000, "easeInOutQuad" );
          //$('.naver').animate({opacity : 1}, 'fast', function() {
          //  $(this).addClass('visible').removeAttr('style');
          //});
      } else if ($(this).scrollTop() <= 400 && $('header').hasClass('fixed') && $('header').hasClass('naver')) {
          //$('.header').switchClass( "fixed", "absolute", 1000, "easeInOutQuad" );
          $(".header").removeClass('bottom-bordered');

          $("nav ul li a").removeClass('black');
          $("nav ul li a").addClass('white');

          //if it's a default. defaultnolead should not swith this color
          $("button").removeClass('black').addClass('white');

          $(".site-title").removeClass('black-logo').addClass('white-logo');

          $(".naver").removeClass('white-logo');
          $(".naver").addClass('black-logo');

          $(".header").removeClass('fixed');
          $(".header").addClass('absolute');

          $(".header").addClass('transparent');
          //$('.naver').animate({opacity : 0}, 'fast', function() {
          //    $(this).removeClass('visible').removeAttr('style');
          //});
      }
  });

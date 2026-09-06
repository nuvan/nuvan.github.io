/* Switch the photographic header to its fixed light treatment after 400px. */
(function () {
  "use strict";

  var header = document.querySelector("header.naver");
  if (!header) {
    return;
  }

  var links = document.querySelectorAll("nav ul li a");
  var buttons = document.querySelectorAll("button");
  var siteTitles = document.querySelectorAll(".site-title");
  var scheduled = false;

  function toggleClasses(elements, removeClass, addClass) {
    Array.prototype.forEach.call(elements, function (element) {
      element.classList.remove(removeClass);
      element.classList.add(addClass);
    });
  }

  function paint() {
    scheduled = false;
    var fixed = window.scrollY > 400;
    if (fixed === header.classList.contains("fixed")) {
      return;
    }

    header.classList.toggle("absolute", !fixed);
    header.classList.toggle("fixed", fixed);
    header.classList.toggle("transparent", !fixed);
    header.classList.toggle("bottom-bordered", fixed);
    header.classList.remove("white-logo");
    header.classList.add("black-logo");

    toggleClasses(links, fixed ? "white" : "black", fixed ? "black" : "white");
    toggleClasses(buttons, fixed ? "white" : "black", fixed ? "black" : "white");
    toggleClasses(siteTitles, fixed ? "white-logo" : "black-logo", fixed ? "black-logo" : "white-logo");
  }

  function schedulePaint() {
    if (!scheduled) {
      scheduled = true;
      window.requestAnimationFrame(paint);
    }
  }

  window.addEventListener("scroll", schedulePaint, { passive: true });
  paint();
}());

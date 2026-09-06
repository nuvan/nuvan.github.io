/* Build and maintain the optional article table of contents without jQuery. */
(function () {
  "use strict";

  var toc = document.querySelector("nav.toc");
  var content = document.querySelector(".page-content");
  if (!toc || !content) {
    return;
  }

  var headings = Array.prototype.slice.call(content.querySelectorAll("h2"));
  if (headings.length === 0) {
    return;
  }

  var list = document.createElement("ul");
  var targets = [];
  var items = [];
  var suppressHighlight = false;
  var resumeTimer;

  function activate(index) {
    items.forEach(function (item, itemIndex) {
      item.classList.toggle("toc-active", itemIndex === index);
    });
  }

  headings.forEach(function (heading, index) {
    var target = document.createElement("span");
    target.id = "toc" + index;
    heading.parentNode.insertBefore(target, heading);
    targets.push(target);

    var link = document.createElement("a");
    link.href = "#" + target.id;
    link.textContent = heading.textContent;
    link.addEventListener("click", function (event) {
      event.preventDefault();
      suppressHighlight = true;
      clearTimeout(resumeTimer);
      target.scrollIntoView({ behavior: "smooth", block: "start" });
      history.pushState(null, "", link.hash);
      activate(index);
      resumeTimer = setTimeout(function () {
        suppressHighlight = false;
      }, 700);
    });

    var item = document.createElement("li");
    item.className = heading.tagName.toLowerCase();
    item.appendChild(link);
    items.push(item);
    list.appendChild(item);
  });

  toc.appendChild(list);

  var scheduled = false;
  function highlight() {
    scheduled = false;
    if (suppressHighlight) {
      return;
    }
    var closest = 0;
    var distance = Number.POSITIVE_INFINITY;
    targets.forEach(function (target, index) {
      var current = Math.abs(target.getBoundingClientRect().top - 100);
      if (current < distance) {
        distance = current;
        closest = index;
      }
    });
    activate(closest);
  }

  window.addEventListener("scroll", function () {
    if (!scheduled) {
      scheduled = true;
      window.requestAnimationFrame(highlight);
    }
  }, { passive: true });
  highlight();
}());

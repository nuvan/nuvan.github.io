---
layout: archive
permalink: /
title: "Latest Posts"
---

<div id="main " role="main" class="fadin-anim">
  <div class="wrap">
      <div class="rows-wrap">
        {% for post in site.posts %}
          {% cycle 'add rows': '<div class="grid-row">', nil, nil %}
            <div class="grid-cell-column">
              {% include post-grid.html %}
            </div>
          {% cycle 'close rows': nil, nil, '</div>' %}
        {% endfor %}
      </div>
  </div>
</div>

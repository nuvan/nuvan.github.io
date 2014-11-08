---
layout: default
title: "Programming"
ads: true
---
<div id="main " role="main" class="fadin-anim">
  <div class="wrap">
      <div class="page-title">
          <h1>{{ page.title }}</h1>
      </div>
      <div class="rows-wrap">
        {% for post in site.categories.programming %}
          {% cycle 'add rows': '<div class="grid-row">', nil, nil %}
            <div class="grid-cell-column">
              {% include post-grid.html %}
            </div>
          {% cycle 'close rows': nil, nil, '</div>' %}
        {% endfor %}
      </div>
  </div>
</div>

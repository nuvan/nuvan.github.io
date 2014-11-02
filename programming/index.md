---
date: 2013-02-01
layout: default
title: "Programming"
ads: true
---
<div id="main " role="main" class="fadin">
  <div class="wrap">
      <div class="page-title">
          <h1>{{ page.title }}</h1>
      </div>
      <div class="archive-wrap">
      <div class="tiles">
        {% for post in site.categories.programming %}
          {% include post-grid.html %}
        {% endfor %}
      </div><!-- /.tiles -->
    </div>
  </div>
</div>

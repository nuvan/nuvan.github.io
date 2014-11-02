---
date: 2013-02-01
layout: default
title: "Programming"
ads: true
---
<div id="page wrapper">
  <div id="main" role="main fadin">
    <div class="wrap">
        <div class="page-title">
            <H1>{{ page.title }}</H1>
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
</div>

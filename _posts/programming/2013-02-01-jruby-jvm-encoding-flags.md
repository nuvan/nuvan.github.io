---
layout: article
date: 2013-02-01
title: "JRuby / JVM encoding flags"
comments: true
category: programming
ads: true
---

Once upon a time, I was developing a couple of extensions for [Logstash](http://logstash.net/).

One of my input extensions connected to a SQLServer via JDBC driver and it all worked fine in my OSX machine. But then, an evil Red Hat Enterprise server appeared, took over the control of my processes and started to mess with all of my good JVM configurations (some of them, I didn't even know that they existed).

After some suffering, anger and hunger that all debugging processes bring, I've found an ancient JVM flag that my evil Red Hat server changed, just to see me cry, after several bad relationships with an assorted number of encodings.

sun.io.unicode.encoding=UnicodeBig (good OSX)

sun.io.unicode.encoding=UnicodeLittle ( evil Red Hat)

Loading up my JVM with -J-Dsun.io.unicode.encoding=UnicodeLittle saved the day.

By the way, if you ever want to check your encoding flags just add this to your JRuby script:

    require 'java'

    java_import java.util.Locale
    java_import java.util.Properties
    java_import java.util.Enumeration
    java_import java.lang.System

    {assorted code}

    p = System.getProperties();
    keys = p.keys();
    keys.each do |key|
      value = p.get(key);
      puts "#{key} : #{value}"
    end

With this script, you can print all of your JVM instance flags. Have fun!

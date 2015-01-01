---
layout: article
title: "PEG that data - Part 1"
date: 2014-11-16
category: programming
image:
  teaser:  peg_314x250.jpg
  feature: peg_1600x800.jpg
comments: true
ads: true
---

In simple (maybe simplistic) terms, Parsing Expression Grammars or just PEGs are formalisms that describe languages, in the form of a set of rules that can be converted to string recognition mechanisms to parse the aforementioned languages.

I could spend some paragraphs, poorly describing PEGs, but I'll leave this to a better-suited place for this subject: [Wikipedia - PEG](http://en.wikipedia.org/wiki/Parsing_expression_grammar). At the time of this article writing, Wikipedia holds a very well put description of PEGs and their nature.

If after reading that link you still feel a bit confuse with this matter maybe you should need to deepen your knowledge about programming languages but fear not. Don't invest in a Computer Science course right now and bear with me for a while. I'll want to begin by building the equivalent of the usual Hello World program as a PEG. Actually we can start by building a PEG that recognizes a "Hello World" string.

Complying with the rules that we've learned in the previously supplied link, let's build our PEG.

    ExpStart := "Hello World"

What a pointless exercise indeed. The start expression only waits for input that matches exactly "Hello World" and that's it.
At this point, you maybe thinking that I'm in an exercise of spending time of my innocent readers but don't get fooled by the simplicity of our first PEG.

Let's build up on this PEG and accept more subjects for our greeting.

    ExpStart := "Hello" Space Subject
    Space    := " "   
    Subject  := "World" | "Solar System" | "Galaxy" | "Universe"

While keeping this exercise very easy, we've introduced a rule that after a standard "Hello" greeting expects a white space and after that a Subject. This Subject can be one of the choices at right member of the Subject rule.

Our augmented PEG can recognize strings such as "Hello World", "Hello Solar System", "Hello Galaxy" or "Hello Universe". Far beyond from those boring Hello World programs don't you think?

Nevertheless if one wants to greet all the Subjects one needs four strings. What a waste of time and quotes. Let's improve our PEG so that it can accept all of the Hello greetings in a single string.

    ExpStart := "Hello" Space Subject "." (Space ExpStart)?
    Space    := " "
    Subject  := "World" | "Solar System" | "Galaxy" | "Universe"

A bit more complicated to read, but still we can follow easily the rules to build our greeting string.

The build path is the same one than our previous PEG. Our starting expression waits for a "Hello" string followed by a Space and after that for a Subject. Add a "." at the end of a string and our PEG would happily accept our saluting.
The difference now is that we've defined a group that may or may not exist afterward (No Schroedinger no...cho choooo. Out of here.).

This group `(Space ExpStart)?` means that one can add another Space and follow that by our ExpStart in a recursive fashion. Now we can accept well-articulated greetings such as: "Hello World. Hello Solar System", "Hello World. Hello Solar System. Hello Galaxy." or even "Hello World. Hello Solar System. Hello Galaxy. Hello Universe.". If one wants we can repeat this string as long our keyboard complies and our PEG will accept this expression until your RAM cannot swap more space to disk.

Of course, it would be interesting to see our expressions being actually validated somewhere instead of relying only in a theoretical example. At the time of writing this article the [PEG.js](http://pegjs.majda.cz) project page had a great online version of a [PEG parser](http://pegjs.majda.cz/online). 

The PEG library provided by this project page will be used in our following articles so we might as well test it right away with our Hello World samples.

Just copy our last grammar expressions, converted below to the requested syntax, to the box "1 - Write your PEG.js grammar".

    ExpStart = "Hello" Space Subject "." (Space ExpStart)?
    Space    = " "
    Subject  = "World" / "Solar System" / "Galaxy" / "Universe"

If all goes well you will receive a green "Parser built successfully" message below the grammar input box.

To test our grammar just copy one of our accepted test strings in to the box "2 - Test generated parser with some input". Let's jump to the biggest one, "Hello World. Hello Solar System. Hello Galaxy. Hello Universe." and once again we hope to be presented with a green "Input parsed successfully." box above. As a bonus, we can inspect the resulting syntax tree in a JSON array format provided in "Output".

Let's end our first PEG exercise. I'll recommend a thorough reading of the PEG.js library syntax and options for our next article where we will dive deep into a interesting problem while building more than a syntax validator.

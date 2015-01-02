---
layout: article
title: "PEG that data - Part 2"
date: 2014-10-26
category: programming
image:
  teaser:  peg_314x250.jpg
  feature: peg_1600x800.jpg
comments: true
ads: true
---

After [Part 1 of PEG that data](http://directionwithintent.com/programming/peg_that_data_1/), we've learned how to create a very basic parser to recognize simple "Hello World" type expressions. Although our exercise was quite unassuming, it demonstrated the basic principles of these formalisms and with PEG.js we've accomplished a concrete result with our first grammar.

To be honest, I'm not keen with this type of examples, but their value is undeniable to break entry barriers for matters that are a bit more exotic, in comparison with the typical programming tutorial. I usually rather prefer tutorials that are more close to real world problems. They spark creativity to build more interesting tools and to apply our newly gained knowledge to our day to day work.

In order to build something more tangible let's draw a more complex exercise to build a PEG that can be useful.

## Real Estate 'Search'

Let's consider a real estate website. Frequently, we are greeted with a multiple selection boxes and several range filters before our leading property results came in. This kind of interface is cumbersome and a nightmare of every UI/UX Engineer or web designer. If your mobile, then this multiple options menus are out of the question. This can be even harder if you are a real estate professional and need to do search queries every time a customer comes in your door with their dream house requirements.

A simple PEG could simplify the search process making use of a single search box with auto-complete options. One might think that no one would learn a new language just to search a web site but even without considering the money involved in a real estate transaction, the time investment in search the right houses to put on a "to visit list" plus the visit time, should be sufficient deterrents to make a poorly informed search.

Before spiking some code, take a bearing for our exercise. Our focus will be placed on building a very simple web application that takes input from a search box and delivers a result set of real estate properties that match our criteria. Instead of presenting this data in a simple list, we will take advantage of a map representation, to better pinpoint our home for the next seasons.

### Input

The fundamental question that has to be done is "How would I ask for it?". Instead of just thinking about the data, first and foremost one should start with the questions that the system should answer. A real estate investor would probably think to himself. "I want a property, near shore, with 2000 square meters at least, with an Olympic size pool, with a garage and with a luscious garden."
or maybe a new town arrival would say "I want to rent a house with 2 divisions and a bathroom for at most 500 a month.". There are some patterns in these sentences that can be carried into our grammar even though we are not going accept free input. To give the impression that we are processing free input, we are going to supply an unsuspecting user with robust auto-complete options and steer him to an expression that makes sense in plain English and that can be parsed by our grammar. In part 3 of this tutorial, we will dedicate our full attention to this issue and build upon those sentence types. Also, we are going to play with some quantifiers such as "near" and well-known size types such as "Olympic".

### Data

As exemplified in the above sentence examples, there is an immense variety of features that one can think while searching for a property. For our exercise, we are going to consider the possibility of a small subset of options that can make our application rich enough in variety.
Each real estate property will be represented with a [GeoJSON](http://http://geojson.org/) Object. I'll recommend a brief overview of the [GeoJSON spec](http://geojson.org/geojson-spec.html) but for now we are going to use a very simple property specification with the following fields:

- Position, to hold the property location coordinates;
- Type. We will accept "House", "Apartment" or "Hotel";
- Area, in square meters;
- Bedrooms, total count;
- Bathrooms, total count;
- Living rooms, total count;
- Garage, area if there is one;
- Garden, area if there is one;
- Pool, area if there is one;
- Rent, monthly rent price if available for rent;
- Buy, price if it's up for sale;

A GeoJSON sample for our description can be found below:

    {
        "type": "Feature",
        "properties": {
            "Type" : "Hotel",
            "Area" : 616.98,
            "Bedrooms" : 10,
            "Bathrooms" : 4,
            "Living rooms" : 4,
            "Garage" : 50,
            "Garden" : 1800.12,
            "Pool" : 5,
            "Buy" : 1000000
        },
        "geometry":{
            "type": "Point",
            "coordinates": [ 38.7041103,-9.3993705 ]
        }
    }

Tracing our bullet point list to this sample is fairly trivial. We've just followed the GeoJSON spec for a custom data element where 'properties' holds our home location characteristics and 'geometry' holds a GeoJSON element, that represents a point location, defined by a single latitude/longitude coordinate.

In Part 3, we commence building our application starting with a first grammar description for our assisted search input.



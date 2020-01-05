---
title: 'Exercise 1: simple analytics web service'
numbersections: true
---

# Context

Design a webservice to track visits to a generic content from anonymous users (think about Google Analytics used to track played songs as an example).
This service will be used in a website with 100 milions of users per day.
Before storing the visits to the database, you have to get the content name from the slow webservice http://api.slowservice.com/content/contentId/detail (it could take up to 60 seconds to respond), and store on a database a record consisting of:

* contentId
* contentName
* user information (user agent, origin ip address, etc...)

A report service queries the stored data to get insights about users. For example:

* get the top N content with a specific word in the name
* get the number of content views, in the last x minutes, with a specific word in the name

The service needs to scale as much as possibile, but you don’t want to create performance or stability issues on the slow service.

## What to do

Design the API and specify what information you can track from the user (and how) with this service.
Describe the architecture and reasoning behind architectural choices.

# Questions

* Any constraints on the API? Can it be a JSON-based REST service?

    Yes it can.

* What about authentication? Shall we design a form of authentication in the API? Can we assume the presence of an API gateway on top?

    No constraints. Will assume an existing authentication service.


# Analysis

Assuming we are tracking multimedia content, the tracking process can happen both browser-side and server-side.

The tracking call has to be fast on the caller side, but the contentName service is slow and can suffer under high load, so we cannot make synchronous calls every time we receive a tracking API call.

Once we store the data, we need a way to query it by splitting the words in the contentName.

Since the service can track anonymous users, the website or service that make the tracking call has to supply a form of identification, namely a clientId, which loosely identify the client.
The analytics API will be protected by a form of authentication, i.e. the user accessing the analytics data is not anonymous. We assume the authentication is done externally and the website/caller has access to an auth token.
In other words: on the tracking side we only need a client identification and no auth, on the analytics side we need auth (client id could still be used for auditing purposes).

Considering the variety of queries that the analytics service should support, we are better off using an off-the-shelf tool like Elasticsearch.
Elasticsearch provides a versatile query language that can extract insights regarding data. We can replace the DB and the analytics (query) API with instances of Elasticsearch. 
The analytics (query) service can be an exposed elastic service, with an optional gateway for authentication with the in-house authenticator. Elastic also supports custom authentication mechanisms, see [https://www.elastic.co/guide/en/elasticsearch/reference/7.5/custom-realms.html](https://www.elastic.co/guide/en/elasticsearch/reference/7.5/custom-realms.html).

If exposing Elasticsearch is too risky, we should implement an API for each query usecase (or create a generic-enough API for common use cases).

# Design

We assume we can gather data from both browsers and backend services. Browsers usually send a significant amount of data in the form of HTTP headers, see the example below.

```
GET / HTTP/1.1
Host: my.website.com:443
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:71.0) Gecko/20100101 Firefox/71.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: it-IT,it;q=0.8,en-US;q=0.5,en;q=0.3
Accept-Encoding: gzip, deflate
Connection: keep-alive
Upgrade-Insecure-Requests: 1
DNT: 1
```

Other kind of information can be implicitly sent or can be inferred: the caller IP is implicit, the timestamp of the "content view" or "impression" can be assumed equal to the current API call timestamp (minus the timezone).

Since the API will be authenticated/identified via some form of token, we assume we can identify the user (or client) by the authentication mechanism.

The rest is explicit, in this case:

* contentId
* contentName
* user information (user agent, origin ip address, etc...)

To be flexible, we should accept all implicit data as explicit in the API calls: this way we can use the API from both browsers and backend services.

To simplify the design, we don't mention monitoring features (readiness/liveness endpoints, prometheus metrics).

## What can we track and how


What we can track                     How
------------------------------------- ----------------------------------------------------------
contentID                             explicitly from the api call
contentName                           explicitly from the name webservice
client id/user id                     explicitly from the api call via the auth mechanism
user agent                            from browser: implicitly from HTTP headers,
                                      from server: explicitly
origin ip address                     from browser: implicitly
timestamp                             we use the request instant as timestamp
website where the content is used     from browser: we can get the current url
                                      via `window.location' javascript call
wiewport size                         javascript call
type of device (mobile, desktop)      from user agent
general location of the user          inferred from IP via geo database (e.g. https://ip-api.com/)
language of the user                  from user agent
general fingerprint                   we can record the unique headers (or all headers if we wish)
                                        that the user's browser send alongside the request
------------------------------------------------------------------------------------------------

# API

We define a REST API with JSON body type.

The API is composed of two parts: the tracking call and the report calls.

* the tracking call is protected by a client ID: calls from unknown client ids shall be rejected
* the report calls are protected by authentication via an `Thron-Auth-Token` header

Unless specified otherwise, we use OWASP recommendations for validating data.

## POST /track | Track impressions

Track impressions of a piece of content.

### Body
```json
{
    "contentID" : "4294512c-f018-42a9-b1e3-8ced965d141f",
    "clientID" : "8fdcafae-7d75-47ed-a6bb-53895654489a",
    "originIP" : "123.123.123.123",
    "url": "https://example.com/",
    "ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:71.0) Gecko/20100101 Firefox/71.0",
    "language" : "it",
    "width": 1440,
    "timestamp": "2020-01-05T15:19:17Z"
}
```

### Headers

```
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:71.0) Gecko/20100101 Firefox/71.0
Accept-Language: it-IT,it;q=0.8,en-US;q=0.5,en;q=0.3
```

### Status codes

HTTP status          Body            Meaning
-------------------- --------------- -----------------
201 Created          empty           success
400 Invalid Request  Error JSON      request format is invalid (see parameters description)
401 Unauthorized     Error JSON      unknown client id

### Responses

Error JSON:

```json
{
    "code": "VALIDATION_ERROR",
    "message": "error description"
}
```

### Error codes

* **VALIDATION_ERROR** validation error
* **AUTHENTICATION_ERROR** invalid or unknown client id

### Parameters description

Name                       Description              Mandatory  Validation       Notes
-------------------------- ----------------------- ----------- ---------------- ---------------------------------
contentID                  content ID                   x      regex            api validates actual value later
clientID                   id of the client             x      auth
originIP                   the IP of the user                  owasp            this overrides the IP from request
                           viewing the content
url                        the url of the website       x      owasp
                           that is showing the
                           content
ua                         User-Agent of the user              validation       this overrides User-Agent;
                                                               by parsing       validation error should not lead
                                                                                to error response: we should
                                                                                treat User-Agent as generic.
language                   language of the user                list             ISO 639-1;
                                                                                this overrides Accept-Language
width                      width of the browser's              positive integer
                           window
timestamp                  the impression timestamp            ISO 8601         if present, this overrides
                                                                                the request time as
                                                                                 impression timestamp
User-Agent                 User-Agent of the user              same as `ua`
Accept-Language            accepted languages as               validation       validation error should not
                           reported by the users'              by parsing       lead to error response, infer
                           browser                                              most probable language via IP
-----------------------------------------------------------------------------------------------------------------

All request headers are collected for later use.


## Query database for top content or view count by filter

Use the Elasticsearch's analytics API on the saved structured data (see Architecture)

# Architecture

The diagram below shows the proposed architecture, where the items to be created are grouped in a "To be" rectangle.
![Architecture](./exercise1/architecture.png)

## Components and participants

### Website

The website (i.e. the user's browser) which uses the content. It can also be another service.

### Collector service

A REST service that accepts tracking API calls.

Responsibilities:
* makes synchronous calls to the Authentication Service to validate the clientID
* enqueue the whole request in the Queue for later processing
* replies to the caller as soon as possible

### Queue

A queue to buffer requests between API calls and contentName retrieval.
Timestamp of requests is recorded on queue, so actual message order is not important.
Queue should be capable of handling 100s of millions of requests (read/write).
A good candidate may be a kafka installation.

### Authentication Service

The company authentication service. We assume it has an API to validate clientIDs and authentication tokens.

### Slow Service

The service that translates contentIDs to contentNames. We assume it is possible to cache the results of this API.
Depending on the nature of the data, it may make sense to store the replies in database rather than only caching them for brief periods.

### API Gateway

This component adds a layer of caching and rate limiting to the slow service: it prevents flooding the slow service with too many calls.

### Store Service

The store service consumes the queue, invokes the slow service for the contentName, and stores structured data to the database.
Since the queue may not guarantee exactly-once delivery, we should take precautions to avoid double writes to the database. E.g. we can hash the request in the collector service, save the hash as an indexed attribute in the database, and use the hash to avoid double inserts.

### Elasticsearch (Database)

Quoting its website:

> Elasticsearch is a distributed, RESTful search and analytics engine capable of addressing a growing number of use cases. As the heart of the Elastic Stack, it centrally stores your data so you can discover the expected and uncover the unexpected.

We store the impression records, after getting the contentName, to Elasticsearch. Elasticsearch exposes a rich API to query the necessary insights about data.

### Query Service

This is a placeholder component: we should expose Elasticsearch query api, and implement a custom auth plugin following the elastic search documentation.
Another option is for Query Service to be an authentication API gateway for elastic's own API.

If exposing Elasticsearch is too risky, this would be the component with the custom query API.

## Variants

### Authentication API gateway

To simplify the services, we can use an API gateway to verify clientIDs and `Thron-Auth-Token`s. Gateways should be placed right behind the exposed REST services.

### contentName cache

If contentName is on a 1-1 relation with contentID, and doesn't change with time, we can store it in a database.
That is, instead of using the API Gateway's caching features, or in-memory caching in general, we can cache contentName in a database as we go.

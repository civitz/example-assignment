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
    "width": 1440
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
201 Created          Ok JSON         success
400 Invalid Request  Error JSON      request format is invalid (see parameters description)
401 Unauthorized     Error JSON      unknown client id

### Responses

Ok JSON:

```json
{
    "success": true,
    "message": "optional note from the server"
}
```
Error JSON:

```json
{
    "success": false,
    "message": "error description"
}
```

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
User-Agent                 User-Agent of the user              same as `ua`
Accept-Language            accepted languages as               validation       validation error should not
                           reported by the users'              by parsing       lead to error response, infer
                           browser                                              most probable language via IP
----------------------------------------------------------------------------------------

All request headers are collected for later use.

# Architecture

The diagram below shows the proposed architecture, where the items to be created are grouped in a "To be" rectangle.

![Architecture](./exercise1/architecture.png)

## Parts

## Variations

DB - nosql/sql

DB => elastic => analytics service can be an exposed elastic service (auth ?)
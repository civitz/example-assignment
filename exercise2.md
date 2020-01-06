---
title: 'Exercise 2: organizing assets in folders with a tree structure'
numbersections: true
---

# Context

Consider a simple DAM product that maps assets and folders with these requirements:

Functional requirements:

* The system must allow navigating the folder tree and list the assets in each folder
* The system must allow displaying the detail of an asset, showing info such as name, description; it also must allow rendering the multimedia file itself
* The system must allow the creation of new folders and assets
* The system must allow inserting and removing assets from folders. One asset can be stored in different folders at the same time

Non-functional requirements:

* Max number of assets = no limit
* Max number of folders = no limit
* Max number of assets inside a folder = infinite

# What to do

* Design these entities and their relationships in a business object model
* Detail the services needed to present an UI that satisfies the functional requirements
* Detail a possible server-sided architecture describing:
    + REST webservice interfaces (with examples)
    + Persistence Layer Model (with examples)
    + Possible frameworks to use (explain your choice)
    + How would you host and scale this system

# Questions

* Authentication?

    No constraints. Will assume an existing authentication service.
* Can we assume we have an object storage/cdn for arbitrary files?

    Yes.

# Analysis

* Folders can contain other folders and also assets (files)
* Assets have metadata that need to be stored
* Assets are deduplicated: one asset can be stored in different folders
* No asset limit
* No folder limit
* No asset-per-folder limit
* The system may be used from desktops, mobiles, and other services. This means that not all media can be downloaded in full and may need streaming.
* Different systems may need different versions of the same asset. E.g. a lower resolution video may be necessary for little screens or devices with low power.
* User, asset, and folder permissions: there should be a way to limit access and actions on assets and folders.

# Design

A proper solution for permission would be to mimic UNIX permissions: users are part of groups, while files and folders (which are all filesystem nodes) have an assigned owner, an assigned group, and permissions for user, group, and others.
Above all that, there should be a clear separation between data of different clients, each composed of multiple users.
To simplify the design, we consider permissions on user side only: that is, a user can either have no access, read access, or read-write access to all assets of the client he/she is part of.

We assume we have a block storage available, and a CDN for geographically distributed content delivery.

We also assume asset immutability: assets can be created and removed, but not altered.

To simplify the design, we don't mention monitoring features (readiness/liveness endpoints, prometheus metrics).

# Data model

Here is a possible data model if we consider an SQL database.

![Entity-Relational model](exercise2/entities.png)

UUIDs are added to reference assets and folders directly without using keys (see OWASP's `Insecure Direct Object References`).

## Constraints

Constraints must be enforced so that:

* nested folders are all parts of the same client
* children folders of the same parent must have unique names
* every asset is referenced only in folders of the same client
* usernames are unique within the same client

## Notes on users

* The `is_admin` attribute is an indication that the user is an admin for the client: if `true`, it can create other users
* the `username` should be url-safe as it will be used to get info in the API
* the `display_name` is used to provide an alternative name for the UI (e.g. username can be an email, display name can be "Name Surname")

## Notes on assets

* We assume we have some form of object storage. The url in the `asset` entity represents the asset url inside the object storage.
* We did not account for assets in different formats (e.g. images in different sizes, videos in different resolutions). We can add this kind of information on a separate table.
* If we need to track each copy of an asset inside the CDN, we need another entity.
* Given the model, it is possible that assets are not referenced in any folder: we need an API to find and recover all assets regardless of that.

## Other enhancements

We may consider adding the following to each entity:

* a "deleted" flag if we want to preserve deleted assets or folders for later use
* created_at/updated_at(/deleted_at) dates
* created_by/updated_by(/deleted_by) for user making changes

We could also add some form of personalization for each client: e.g. a company logo for personalizing the DAM's website.

# API

The API is a REST endpoint with JSON body as default.

All requests are authenticated via `Thron-Auth-Token` (cookie or header based) so we can identify the user.

All requests returning lists should be paginated; We recommend using either query param-based pagination with `Link` headers (see [https://developer.github.com/v3/#pagination](https://developer.github.com/v3/#pagination)) or header-based pagination with `Range` and `Accept-Range`. Another option would be to use server side cursors.

To simplify the API we make the assumption that we can upload asset of any size without issues. In reality most browsers and application servers have theoretical limits: over certain sizes (tipically 2 GB), we should consider implementing an upload API that supports chunked files.

We assume default reponses for common events:

* HTTP 400 for validation errors
* HTTP 401 for authentication errors
* HTTP 403 for insufficient priviledges
* HTTP 404 for unavailable/absent content

## Folder and asset management

### List folder roots

`GET /client/{clientUuid}/folder/roots`


Returns only folders with no parents.

An alternative would be to maintain an immutable/invisible root directory, assign a fixed `"root"` pseudo-uuid, and use the next API to list all root content.

#### Result example

```json
{
    "results" : [
        {
            "name": "campagna2019",
            "type": "folder",
            "uuid": "d688d2a4-fef2-4f3a-a823-c90963969eb6",
            "parent": null
        },
        {
            "name": "Nuovi Arrivi",
            "type": "folder",
            "uuid": "e17ecbc3-b160-430b-b85b-1ddc862fde2c",
            "parent": null
        },
        ...
    ]
}
```

Pagination info could also be part of the json result.

### List folder content

`GET /client/{clientUuid}/folder/{folderUuid}`

Returns both folders and asset list

As an alternative we can separate the API to list folder's children from the API to list assets in folder. It may make sense depending on the use case.

#### Result example

```json
{
    "results" : [
        {
            "name": "North America",
            "type": "folder",
            "uuid": "d688d2a4-fef2-4f3a-a823-c90963969eb6",
            "parent": "43d3f26d-a7f2-4250-90af-b523ca8f2329"
        },
        {
            "name": "EMEA",
            "type": "folder",
            "uuid": "e17ecbc3-b160-430b-b85b-1ddc862fde2c",
            "parent": "43d3f26d-a7f2-4250-90af-b523ca8f2329"
        },
        {
            "name": "brochure.pdf",
            "type": "asset",
            "uuid": "46cd5945-cd95-4790-b892-8df3f64292e7",
            "mediatype" : "application/pdf",
            "size" : 123456
        },
        {
            "name": "campaign_logo.png",
            "type": "asset",
            "uuid": "e5a25353-597e-4e21-98da-a9d7f7c44cdf",
            "mediatype" : "image/png",
            "size" : 912356
        },
        ...
    ]
}
```

### Create folder

`POST /client/{clientUuid}/folder/`

#### Request example

```json
{
    "name": "roma2020",
    "parent": "e17ecbc3-b160-430b-b85b-1ddc862fde2c"
}
```

#### Result example

HTTP 201 Created, with body

```json
{
    "name": "roma2020",
    "parent": "e17ecbc3-b160-430b-b85b-1ddc862fde2c",
    "uuid": "af4d8335-6db1-446b-945a-916e2a9969ec"
}
```

### Rename folder

`PUT /client/{clientUuid}/folder/{folderUuid}`

#### Request example
```json
{
    "name": "romagna2020"
}
```

#### Result example

HTTP 200 Ok, with body
```json
{
    "name": "romagna2020",
    "parent": "e17ecbc3-b160-430b-b85b-1ddc862fde2c",
    "uuid": "af4d8335-6db1-446b-945a-916e2a9969ec"
}
```

### Delete folder

`DELETE /client/{clientUuid}/folder/{folderUuid}`

No request or response body.

HTTP 204: "No content" on success.

What about recursive deletion? We can choose to mimic `rmdir` behaviour or `rm -f` behaviour.
If we want to separate the two variants, we can use a "recursive" query param.

### Create asset

`POST /client/{clientUuid}/asset/`

Input: a multipart/form-data where
* part 1 or "info" is a json with asset name and optional metadata
* part 2 or "asset" is the binary asset

#### Example request

Without metadata
```json
{
    "name": "campaign_logo.png",
    "mediatype": "image/png",
    "description": "Customized company logo with pumpkins"
}
```

With metadata
```json
{
    "name": "campaign_logo.png",
    "mediatype": "image/png",
    "description": "Customized company logo with pumpkins",
    "metadata": {
        "theme": "pumpkin",
        "mainColour": "orange"
    }
}
```

For mandatory fields see the business entities.

#### Example response

```json
{
    "name": "campaign_logo.png",
    "mediatype": "image/png",
    "uuid": "37793898-6698-48c4-9a5b-d48254030756",
    "description": "Customized company logo with pumpkins",
    "size" : 912356,
    "url": "https://correct-horse-battery-staple.s3.eu-central-1.amazonaws.com/37793898-6698-48c4-9a5b-d48254030756/bf250e5ecadc6878d38e71fade15318081a5e2fb.png",
    "cdnurl": "http://d111111abcdef8.cloudfront.net/correct-horse-battery-staple/37793898-6698-48c4-9a5b-d48254030756/bf250e5ecadc6878d38e71fade15318081a5e2fb/campaign_logo.png",
    "metadata": {
        "theme": "pumpkin",
        "mainColour": "orange"
    }
}
```

### Remove asset

`DELETE /client/{clientUuid}/asset/{assetUuid}`

No request or response body.

HTTP 204: "No content" on success.

Asset deletion is more destructive than asset removal from folder: every reference to the asset is affected.

### Add asset(s) to folder

`POST /client/{clientUuid}/folder/{folderUuid}/asset/`

HTTP 201: "Created" on success, with empty body.

#### Example request

```json
{
    "uuids": [
        "37793898-6698-48c4-9a5b-d48254030756"
        ]
}
```

Array let you add more than one asset at once.

### Remove asset from folder

`DELETE /client/{clientUuid}/folder/{folderUuid}/asset/{assetUuid}`

No request or response body.

HTTP 204: "No content" on success.

### Find asset

`GET /client/{clientUuid}/asset/`

We need query params to lookup assets in folders / by metadata / by other attributes

TODO

### Add asset metadata

`PUT /client/{clientUuid}/asset/{assetUuid}/metadata`

Request contains metadata to add.

Response contains resulting metadata

#### Example request

```json
{
    "theme": "spice",
    "contains_animal": "true"
}
```

#### Example response

```json
{
    "theme": "spice",
    "mainColour": "orange",
    "contains_animal": "true"
}
```


### Remove asset metadata

`DELETE /client/{clientUuid}/asset/{assetUuid}/metadata?`

Query params:

Parameter   Value
----------- --------
`key`         the key to remove
`value`       the value to remove

If there is only one value per key, only key is needed.

Response contains modified metadata.

#### Example request

```
DELETE /client/9a60cb78-e66b-4e77-af77-6d2dda1f9129/
        asset/37793898-6698-48c4-9a5b-d48254030756/metadata?key=theme
```

#### Example response

```json
{
    "mainColour": "orange",
    "contains_animal": "true"
}
```

### Asset details

`GET /client/{clientUuid}/asset/{assetUuid}`

#### Example response

```json
{
    "name": "campaign_logo.png",
    "mediatype": "image/png",
    "uuid": "37793898-6698-48c4-9a5b-d48254030756",
    "description": "Customized company logo with pumpkins",
    "size" : 912356,
    "url": "https://correct-horse-battery-staple.s3.eu-central-1.amazonaws.com/37793898-6698-48c4-9a5b-d48254030756/bf250e5ecadc6878d38e71fade15318081a5e2fb.png",
    "cdnurl": "http://d111111abcdef8.cloudfront.net/correct-horse-battery-staple/37793898-6698-48c4-9a5b-d48254030756/bf250e5ecadc6878d38e71fade15318081a5e2fb/campaign_logo.png",
    "metadata": {
        "theme": "pumpkin",
        "mainColour": "orange"
    }
}
```

### Asset download

`GET /client/{clientUuid}/asset/{assetUuid}/download`

This API streams the asset content to the caller.
It will use name and media type headers to enhance the download.

### Get users

`GET /client/{clientUuid}/user/`

#### Example response

```json
{
    "users": [
    {
        "username": "deadbeef",
        "display_name": "David Gilmour",
        "can_read": true,
        "can_write": true,
        "is_admin": false
    },
    {
        "username": "imthebass",
        "display_name": "Roger Waters",
        "can_read": true,
        "can_write": true,
        "is_admin": true
    },
    {
        "username": "crazydiamond",
        "display_name": "Syd Barrett",
        "can_read": true,
        "can_write": false,
        "is_admin": false
    }
    ]
}
```

### Get user

`GET /client/{clientUuid}/user/{username}`


#### Example response

```json
{
    "username": "deadbeef",
    "display_name": "David Gilmour",
    "can_read": true,
    "can_write": true,
    "is_admin": false
}
```

## Client admin API

These APIs should be only accessible by the client's administrators (users with `is_admin=true`).

### Add user

`POST /client/{clientUuid}/user/`

#### Example request

```json
{
    "username": "deadbeef",
    "display_name": "David Gilmour",
    "can_read": true,
    "can_write": true,
    "is_admin": false
}
```

#### Example response

HTTP 201: "Created" on success, with empty body.

### Modify user

`PUT /client/{clientUuid}/user/{username}`

Response is 200 Ok with modified data.

#### Example request

```json
{
    "display_name": "Richard Wright",
    "can_read": true,
    "can_write": true,
    "is_admin": true
}
```

#### Example response

```json
{
    "username": "deadbeef",
    "display_name": "Richard Wright",
    "can_read": true,
    "can_write": true,
    "is_admin": true
}
```

### Delete user

`DELETE /client/{clientUuid}/user/{username}`

No request or response body.

HTTP 204: "No content" on success.

## Administrator API

These APIs should be only accessible by the application operators

### Get client

`GET /client/{clientUuid}`

#### Example response

```json
{
    "name": "Karl Lagerfeld",
    "uuid": "9a60cb78-e66b-4e77-af77-6d2dda1f9129",
    "default_bucket": "correct-horse-battery-staple"
}
```

### Add client

`POST /client/`

#### Example request

```json
{
    "name": "Karl Lagerfeld",
    "default_bucket": "correct-horse-battery-staple"
}
```

#### Example response

```json
{
    "name": "Karl Lagerfeld",
    "uuid": "9a60cb78-e66b-4e77-af77-6d2dda1f9129",
    "default_bucket": "correct-horse-battery-staple"
}
```

### Modify client

`PUT /client/{clientUuid}`

#### Example request

```json
{
    "default_bucket": "simple-clock-paradox-parmigiano"
}
```

#### Example response

```json
{
    "name": "Karl Lagerfeld",
    "uuid": "9a60cb78-e66b-4e77-af77-6d2dda1f9129",
    "default_bucket": "simple-clock-paradox-parmigiano"
}
```

### Delete client

`DELETE /client/{clientUuid}`

No request or response body.

HTTP 204: "No content" on success.

# Architecture

Given the design considerations, the system can be made with:

* a block storage
* an SQL database
* a web server for static content
* an application server for APIs
* an authentication service

If we take in account some scale and remove some of the simplifications, we may also need:

* a CDN
* a system to stream assets (it may be a feature of the CDN)
* a system to stream assets in different formats depending on the frution platform
* an intermediate system to convert assets on the fly if the device does not support the format and conversion is possible

## Persistence Layer Model

As stated before, we assume we have a block storage and a CDN available.

We store each asset (or variation of the asset) as a single file on a client-dedicated bucket.

## Possible frameworks

### Backend

We choose Jakarta standard (ex Java EE), with microprofile extension. The standard is mature and featureful and allows for very small deployable size.
If we choose to deploy on a function-as-a-service environment, we can quickly switch to the GraalVM-based quarkus project, which supports most of the Jakarta API and provides two interesting features a fast startup with a standard VM (less than 5 seconds).
Quarkus has an option, with GraalVM, to compile to native for even faster startup (startup in milliseconds) by sacrificing performances on the long term.

With an ORM we may have troubles with nested folders, so we should use custom SQL or light abstraction libraries like jOOQ.
The problem lies on how ORMs fetch data. If we map an entity with recursive fields, once we fetch a folder we face two alternatives:

* if we configure eager fetching of children, by fetching the root we automatically fetch the whole subtree every time, regardless if we want it or not
* if we configure lazy fetching of children, every time we need the subtree we trigger a new query

Hybrid approaches are also possible.

Alternatives to these frameworks are: Spring framework, or micronaut framework. I am not aware of better solutions for SQL mapping with tree-like data structures.

### Frontend

I am no expert in frontend framework, but given the task, I would choose a framework with these criterias:

* familiarity within the company
* stability of the release
* support for different device configurations (easy to build for both desktop and mobile devices)
* built-in internationalization support
* if a native app is desired, we may consider frameworks like react-native to ease the development of cross-platform solutions

## Hosting and scaling

Using access to an AWS account, a non-exaustive bill of materials is:

* a managed instance of Aurora DB - PostgreSQL; scaled to support the load
* one or more S3 buckets for asset storage; it may be a good choice to put each client's assets on a dedicated bucket
* a Cloudfront configuration for assets; we may also protect direct access with authentication
* S3 bucket and cloudfront configuration for website static content
* EC2 instances for the application server
* a load balancer for the application server instances
* DNS service like AWS's route 53

To scale this solution we may consider:

* measuring where the bottleneck is via monitoring (application monitoring and infrastructure monitoring) and act on the bottleneck
* whenever possible, scale horizontally:
  + add EC2 instances for application servers
  + shard the database or run clients on dedicated instances
* deploy EC2 instances on different zones and route requests on the nearest EC2 instance (this should be possible with route 53)
* set up the environment so that it scales up (and down) depending on the load. This can be custom made or managed via solutions like kubernetes' operators
* if database cannot be scaled otherwise, and transactions become the bottleneck, we should consider a redesign with a NoSQL solution where we handle errors later rather than enforce transactions on every call
* if searching through assets becomes slow, we should consider a search engine like Elasticsearch
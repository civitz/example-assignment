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
* every asset is referenced only in folders of the same client

## Notes on assets

* We assume we have some form of object storage. The url in the `asset` entity represents the object storage url.
* We did not account for assets in different formats (e.g. images in different sizes, videos in different resolutions). We can add this kind of information on a separate table.
* If we need to track each copy of an asset inside the CDN, we need another entity.
* Given the model, it is possible that assets are not referenced in any folder: it should be possible to find and recover all assets regardless of that.

## Other notes

We may consider adding the following to each entity:

* a "deleted" flag if we want to preserve deleted assets or folders for later use
* created_at/updated_at(/deleted_at) dates
* created_by/updated_by(/deleted_by) for user making changes

We could also add some form of personalization for each client: e.g. a company logo for personalizing the DAM's website.

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

## API
## Persistence Layer Model
## Possible frameworks
## Hosting and scaling
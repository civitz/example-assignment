# Excercise 2: organizing assets in folders with a tree structure

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

## What to do

* Design these entities and their relationships in a business object model
* Detail the services needed to present an UI that satisfies the functional requirements
* Detail a possible server-sided architecture describing:
    + REST webservice interfaces (with examples)
    + Persistence Layer Model (with examples)
    + Possible frameworks to use (explain your choice)
    + How would you host and scale this system


## Analysis

* Folders can contain other folders and also assets (files)
* Assets have metadata that need to be stored
* Assets are deduplicated: one asset can be stored in different folders
* No asset limit
* No folder limit
* No asset-per-folder limit

## Questions

* Auth?
    No constraints. Will assume an existing authentication service.
* Can we assume we have an object storage/cdn for arbitrary files?
    Yes.
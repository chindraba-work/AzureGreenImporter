# AzureGreenImporter

## Contents

- [Description](#description)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Version Numbers](#version-numbers)
- [Copyright and License](#copyright-and-license)
- [Notice](#notice)


## Description

A [Bash](https://www.gnu.org/software/bash/) and SQL script for processing the information and image files supplied by AzureGreen to their distributors so that the information can be imported into a [Zen-Cart](https://www.zen-cart.com/) store without having to retype the information for thousands of products, or monitor the stock levels and prices on each of those products.

[TOP](#contents)

## Requirements

### Zen-Cart store

On the server for the Zen-Cart store, you need to have:

- FTP access to the store’s admin directory
- Direct access to the store’s database. (**Not** using the in-store admin control Import SQL Patch tool.) Two options are:
   1. phpMyAdmin, supplied by the host, or
   2. Direct Command-line interface using the `mysql` client program.

### Local computer (by preference, a GNU/Linux system, or VM)

- The ability to execute `Bash` shell scripts
- A working version of `curl`
- Command-line access to a `Perl` interpreter
- Space to save, long-term, the files from AzureGreen
- An FTP client
- The ability to download files from AzureGreen’s wholesaler resource page (Internet access)

_[The shell script is written in Bash script and uses "Bashisms" which limits its operation in most other Unix, or non-Linux shells (such as Windows PowerShell).]_

[TOP](#contents)

## Installation

1.  Copy the 4 files, `ag_*`, to a directory of your choice
  -  Create a symbolic link to the `ag_update.sh` file in your path, if that file is not in your path
2.  Create a directory on the local machine where the commands and data will be kept
3.  Ensure that the live database has no products or categories added to it
4.  Import the install.sql into your empty database
5.  Copy the needed tables from the live database to the database where the work will be done. This can be done using phpMyAdmin, or any other tool of choice, so long as the entire set of data is copied. The tables to copy are:
  -  `categories`
  -  `categories_description`
  -  `meta_tags_categories_description`
  -  `meta_tags_products_description`
  -  `products`
  -  `products_description`
  -  `products_to_categories`

[TOP](#contents)

## Usage

Prior to running the script, it is necessary to make the database connection information available to the script. Two methods are available for doing this; environment variables and editing the script directly. The script contents are available as a default, and the environment variables will override them.

The environment variables used, and their purpose are:

- **AGIMPORT_DB_HOST**: The host for the database used in the processing. This is not the live database, or a clone of it, merely the tables given above which are copied from the live database. If the environment variable is not set, the script default will be used. If, however, the environment variable is set, and is blank, the host parameter will not be passed to the `MySQL` client. Typically when no host argument is supplied, the client will use 'localhost' as the host. That is subject to configuration, however, and to ensure that 'localhost' is in fact used, it is best to set that as the host in either the default or the environment.
- **AGIMPORT_DB_NAME**: The name of the database to be used in the import process. If the environment variable is not set, or blank, the script default will be used. If both are blank the script will exit with an error.
- **AGIMPORT_DB_USER**: The username which has all privileges to the above database. If the environment variable is not set, or blank, the script default will be used. If both are blank the script will exit with an error.
- **AGIMPORT_DB_PASS**: The password needed to access the database by the named user. If the environment variable is not set, the script default will be used. If, however, the environment variable is set, and is blank, the password parameter will be left blank on the call to the `MySQL` client. When a blank password is passed, the `MySQL` database client will prompt for the password on the command line for each segment of processing (3 total).

From a security standpoint it is, of course, best to leave the password blank in the script, and in the evironment variable. The importer should only need to be run, at most, once per day, and entering the password on the command line is not too much of an imposition.

The script will accept one or two arguments. The first argument is the directory to use, rather than the current directory, for processing the data, and storing the results. The second argument is the date-based directory to read historical data from. As is the nature of Bash, the first argument is required for the second to be used. When the current directory is needed while still using the historical data, a simple period, meaning the current directory, can be used as the directory to work in.

The process will create directories for storing the retrieved files with names in the style of `2018.10.31`, i.e.: _year.month.day_. It accepts the same format, only, as the second argument and will read the files from the same-named directory in the `source_record` directory.  In this case symbolic links are **NOT** acceptable, they must be actual directories. The use of this action is intended to allow the recreation of the data from some prior date, using the same steps used before. This could be, for example, to create a new database for a new store, to replace a corrupted version in the current store, or to recover from a database failure by the hosting provider.

Simplest usage is to change into the directory created above and run the script from there. With the script, or link to it, in your path, the script will run from anywhere, and will find the installed files it needs using self-detection.

Running the `ag_update.sh` script will generate a set of files for importing the changes to the live database. A `gzip`ed version of all the SQL commands necessary to import the latest changes into the live database. Using the "Import" tab in `phpMyAdmin` for the live database, this file can be uploaded as-is, and executed. Since the SQL is all text, the `gzip`ed version can save 90%, or more, of the bandwith, and upload time. If you have a direct command-line interface to the live database, there is also a "combined" version of all the changes, which can be imported with the client. For slower connections, there are also individual SQL files for the categories, products, and placement changes, which can be imported one at a time. If either of the command-line routes is used, it is best to do so during a low traffic time for the site. The changes are not locked into one commit, and it is possible for the applied changes to be in conflict with a customer browsing the store at the same time. The `gzip`ed version reduces, _without eliminating_, that risk by having the upload and processing separated. The file is uploaded, unarchived and then processed by `MySQL` all at once. All the data can then be processed at the speed of memory rather than the speed of disk and Internet combined.

In addition, one or two additional files are created for the images. In the case where AzureGreen has supplied an updated collection of images, the images which are new, or possibly better, are combined into a `gzip`ed file which can be uploaded to the `images` directory on the server. If unarchived there, the new images will be sorted into their properly-prefixed sub directories with no further work needed.

If there were products added to the database which AzureGreen has not supplied images for yet, the process attempts to retrieve their images from the live site for AzureGreen. All such images are also placed into a `gzip`ed file which is otherwise the same as the first. The searching for missing images is NOT done when processing historical data using the second command-line argument.

In all cases, the generated files are added to the source_records directory, with a current timestamp in the file name. The `SQL` files and image archives are placed in the data directoy without a timestamp and will be overwritten by the same-named files when next the process is run.

The collection of historical data from AzureGreen, and the generated `SQL` files and image archives can rapidly consume space on the local computer. The two are mutually redundant, and the user can select which one to maintain. If proper backups of the database are maintained, neither may be needed for long-term storage.

[TOP](#contents)

## Version Numbers

AzureGreenImporter uses [Semantic Versioning v2.0.0](https://semver.org/spec/v2.0.0.html) as created by [Tom Preston-Werner](http://tom.preston-werner.com/), inventor of Gravatars and cofounder of GitHub.

Version numbers take the form `X.Y.Z` where `X` is the major version, `Y` is the minor version and `Z` is the patch version. The meaning of the different levels are:

- Major version increases indicates that there is some kind of change in the API (how this program works as seen by the user) or the program features which is incompatible with previous version

- Minor version increases indicates that there is some kind of change in the API (how this program works as seen by the user) or the program features which might be new, while still being compatible with all other versions of the same major version

- Patch version increases indicate that there is some internal change, bug fixes, changes in logic, or other internal changes which do not create any incompatible changes within the same major version, and which do not add any features to the program operations or functionality

[TOP](#contents)

## Copyright and License

```
    AzureGreenImporter: Import AzureGreen data into a Zen-Cart store   
                                                                       
    This file is part of the AzureGreen data and image importing       
    system designed to semi-automatically import, and update, the      
    massive amount of information supplied by AzureGreen in a format   
    which fits within the standard Zen-Cart database system.           
                                                                       
    Copyright © 2019  Chindraba (Ronald Lamoreaux)                     
                      <plus_zen@chindraba.work>                        
    - All Rights Reserved                                              
                                                                       
    This software is free software; you can redistribute it and/or     
    modify it under the terms of the GNU General Public License,       
    version 2 only, as published by the Free Software Foundation.      
                                                                       
    This software is distributed in the hope that it will be useful,   
    but WITHOUT ANY WARRANTY; without even the implied warranty of     
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the      
    GNU General Public License for more details.                       
                                                                       
    You should have received a copy of the GNU General Public License  
    along with this program; if not, write to the                      
          Free Software Foundation, Inc.                               
          51 Franklin Street                                           
          Fifth Floor                                                  
          Boston, MA  02110-1301                                       
          USA.                                                         
```

[TOP](#contents)

---

## NOTICE:

### The system has been completely changed between v1 and v2 and the two versions are incompatible in all ways.

It was found that the data files and image names were significantly more "dirty" than originally thought. This required a reworking of how the data was processed and how the image files were sorted.

It was also discovered that the available options on some shared hosting platforms are significantly tighter than required for this system to work. One key, among many, is the inability to do 
    LOAD DATA LOCAL INFILE
commands in MySQL/MariaDB. Until such time as this system is converted to use fully native PHP code from within the Admin controls of the Zen-Cart store, this system will have to rely on command-line access to the database from a local machine. This can be the a local clone of the database, or just copies of selected tables from the live database. It should not, however, be used with the live database.

If switching from version 1 to version 2, the files installed on the local machine and the server can be removed, or ignored. Version 2 file names have nothing in common with version 1 files, and they will have no side effect, other than taking space, if left behind. The stored data files downloaded from AzureGreen, if any, can be used to recreate the existing catalog, if needed, but are not necessary. Version 2 needs to be installed into a clean database, including not having had the demo data installed.

Attempting to use the importer with a database with products and categories already present WILL result in collisions between imported AzureGreen categories and existing categories. Product data will also be subject to corruption. It is possible to "sanitize" an existing database, but it is not recommended.

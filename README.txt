AzureGreenImporter

**********************************************************************

NOTICE:

The system has been completely changed between v1 and v2 and the two
versions are incompatible in all ways.

It was found that the data files and image names were significantly
more "dirty" than originally thought. This required a reworking of how
the data was processed and how the image files were sorted.

It was also discovered that the available options on some shared
hosting platforms are significantly tighter than required for this
system to work. One key, among many, is the inability to do 
    LOAD DATA LOCAL INFILE
commands in MySQL/MariaDB. Until such time as this system is converted
to use fully native PHP code from within the Admin controls of the
Zen-Cart store, this system will have to rely on command-line access
to the database from a local machine. This can be the a local clone of
the database, or just copies of selected tables from the live
database. It should not, however, be used with the live database.

If switching from version 1 to version 2, the files installed on the
local machine and the server can be removed, or ignored. Version 2
file names have nothing in common with version 1 files, and they will
have no side effect, other than taking space, if left behind. The
stored data files downloaded from AzureGreen, if any, can be used to
recreate the existing catalog, if needed, but are not necessary.
Version 2 needs to be installed into a clean database, including not
having had the demo data installed.

Attempting to use the importer with a database with products and
categories already present WILL result in collisions between imported
AzureGreen categories and existing categories. Product data will also
be subject to corruption. It is possible to "sanitize" an existing
database, but it is not recommended.

**********************************************************************

Contents

 *  Description
 *  Requirements
 *  Installation
 *  Usage
 *  Version Numbers
 *  Copyright and License

Description:

A Bash and SQL script for processing the information and image files
supplied by AzureGreen to their distributors so that the information
can be imported into a Zen-Cart store without having to retype the
information for thousands of products, or monitor the stock levels and
prices on each of those products.

Requirements:

Zen-Cart store

On the server for the Zen-Cart store, you need to have:

 *  FTP access to the store’s admin directory
 *  Access to the store’s admin control panel, specifically
    Admin -> Tools -> Install SQL Patches
 *  Direct access to the store’s database. (Not using the in-store
    controls above.) Two options are:
      1.  phpMyAdmin, supplied by the host
      2.  Direct Command-line interface using the mysql client program

Local computer (by preference, a GNU/Linux system, or VM)

 *  The ability to execute Bash shell scripts
 *  A working version of wget
 *  Command-line access to a Perl interpreter
 *  Space to save, long-term, the files from AzureGreen
 *  An FTP client
 *  The ability to download files from AzureGreen’s wholesaler
    resources page

[The shell script is written in Bash script and uses "Bashisms" which
limits its operation in most other Unix, or non-Linux shells (such as
Windows PowerShell).]

Installation:

1.  Create a directory on the local machine where the commands and
    data will be kept
2.  Ensure that the live database has no products or categories added
    to it
3.  Using the Import SQL Patch tool for the store, import the
    `install.sql` file
4.  Copy the needed tables from the live database to the database
    where the work will be done. This can be done using phpMyAdmin, or
    any other tool of choice, so long as the entire set of data is
    copied. The tables to copy are:
      *  `categories`
      *  `categories_description`
      *  `meta_tags_categories_description`
      *  `meta_tags_products_description`
      *  `products`
      *  `products_description`
      *  `products_to_categories`
5.  Copy the contents of the ag_importer directory to the directory
    created in step 1.

Usage:

Simplest usage is to execute the script from within the directory
created for that purpose, no arguments needed. It is also possible to
execute the script with a directory as the first argument. Doing so
allows the script to handle importing into several instances without
data migration between servers. A second argument may be used to load
files stored locally under a dated directory. A single dot (period)
can be used as the first argument if the current directory is the
directory to work within and a second argument is needed for the dated
file import.

Running the `ag_update.sh` script will generate a pair of files for
uploading the changes to the live database. A regular SQL script,
suitable to copy/paste or import into the proper tools, and a
`gzip`ed version, acceptable to `phpMyAdmin` on the database's import
tab.

Version Numbers:

AzureGreenImporter uses Semantic Versioning v2.0.0 as created by Tom
Preston-Werner, inventor of Gravatars and cofounder of GitHub.

Version numbers take the form X.Y.Z where X is the major version, Y is
the minor version and Z is the patch version. The meaning of the
different levels are:

 *  Major version increases indicates that there is some kind of
    change in the API (how this program works as seen by the user) or
    the program features which is incompatible with previous version

 *  Minor version increases indicates that there is some kind of
    change in the API (how this program works as seen by the user) or
    the program features which might be new, while still being
    compatible with all other versions of the same major version

 *  Patch version increases indicate that there is some internal
    change, bug fixes, changes in logic, or other internal changes
    which do not create any incompatible changes within the same major
    version, and which do not add any features to the program
    operations or functionality

Copyright and License:

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


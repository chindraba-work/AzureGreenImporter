AzureGreenImporter

**********************************************************************

NOTICE

Version 1, the current version, will soon be replaced by version 2.

This change was required by discoveries about the "dirtyness" of
AzureGreen's data, and the restrictions imposed by some shared hosting
 platforms.

**********************************************************************

Contents

 *  Description
 *  Requirements
 *  Version Numbers
 *  Copyright and License

Description

A collection of Bash and SQL scripts for processing the information and
image files supplied by AzureGreen to their distributors so that the
information can be imported into a Zen-Cart store without having to
retype the information for thousands of products, or monitor the stock
levels and prices on each of those products.

Requirements

Zen-Cart store

On the server for the Zen-Cart store, you need to have:

 *  FTP access to the store’s admin directory
 *  Access to the store’s admin control panel, specifically
    Admin -> Tools -> Install SQL Patches
 *  Direct access to the store’s database. (Not using the in-store
    controls above.) Two options are:
      1.  phpMyAdmin, supplied by the host
      2.  Direct Command-line interface using the mysql client program.

Local computer (by preference, a GNU/Linux system, or VM)

 *  The ability to execute Bash shell scripts
 *  A working version of wget
 *  Command-line access to a Perl interpreter
 *  Space to save, long-term, the files from AzureGreen
 *  An FTP client
 *  The ability to download files from AzureGreen’s wholesaler resources
    page

[The shell scripts are written in Bash script and use "Bashisms" which
 limit their operation in most other Unix, or non-Linux shells (such as
 Windows PowerShell).]

Version Numbers

AzureGreenImporter uses Semantic Versioning v2.0.0 as created by Tom
Preston-Werner, inventor of Gravatars and cofounder of GitHub.

Version numbers take the form X.Y.Z where X is the major version, Y is
the minor version and Z is the patch version. The meaning of the
 different levels are:

 *  Major version increases indicates that there is some kind of change
 in the API (how this program works as seen by the user) or the program
 features which is incompatible with previous version

 *  Minor version increases indicates that there is some kind of change
 in the API (how this program works as seen by the user) or the program
 features which might be new, while still being compatible with all
other versions of the same major version

 *  Patch version increases indicate that there is some internal change,
 bug fixes, changes in logic, or other internal changes which do not
 create any incompatible changes within the same major version, and
 which do not add any features to the program operations or
functionality

Copyright and License

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


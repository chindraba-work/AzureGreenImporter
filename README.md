# AzureGreenImporter

## Contents

- [Description](#description)
- [Requirements](#requirements)
- [Version Numbers](#version-numbers)
- [Copyright and License](#copyright-and-license)


## Description

A collection of [Bash](https://www.gnu.org/software/bash/) and SQL scripts for processing the information and image files supplied by AzureGreen to their distributors so that the information can be imported into a [Zen-Cart](https://www.zen-cart.com/) store without having to retype the information for thousands of products, or monitor the stock levels and prices on each of those products.

[TOP](#contents)

## Requirements

### Zen-Cart store

On the server for the Zen-Cart store, you need to have:

- FTP access to the store’s admin directory
- Access to the store’s admin control panel, specifically `Admin -> Tools -> Install SQL Patches`
- Direct access to the store’s database. (**Not** using the in-store controls above.) Two options are:
   1. phpMyAdmin, supplied by the host
   2. Direct Command-line interface using the `mysql` client program.

### Local computer (by preference, a GNU/Linux system, or VM)

- The ability to execute `Bash` shell scripts
- A working version of `wget`
- Command-line access to a `Perl` interpreter
- Space to save, long-term, the files from AzureGreen
- An FTP client
- The ability to download files from AzureGreen’s wholesaler resource page

_[The shell scripts are written in Bash script and use "Bashisms" which limit their operation in most other Unix, or non-Linux shells (such as Windows PowerShell).]_

[TOP](#contents)

## Version Numbers

AzureGreenImporter uses [Semantic Versioning v2.0.0](https://semver.org/spec/v2.0.0.html) as created by [Tom Preston-Werner](http://tom.preston-werner.com/), inventor of Gravatars and cofounder of GitHub.

Version numbers take the form `X.Y.Z` where `X` is the major version, `Y` is the minor version and `Z` is the patch version. The meaning of the different levels are:

- Major version increases indicates that there is some kind of change in the API (how this program works as seen by the user) or the program features which is incompatible with previous version

- Minor version increases indicates that there is some kind of change in the API (how this program works as seen by the user) or the program features which might be new, while still being compatible with all other versions of the same major version

- Patch version increases indicate that there is some internal change, bug fixes, changes in logic, or other internal changes which do not create any incompatible changes within the same major version, and which do not add any features to the program operations or functionality

[TOP](#contents)

# Copyright and License

    Copyright © 2018, 2019 Chindraba (Ronald Lamoreaux)
                           <zenning@chindraba.work>
    - All Rights Reserved

    AzureGreenImporter is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License,
    version 2 only, as published by the Free Software Foundation.

    AzureGreenImporter is distributed in the hope that it will be
    useful, but WITHOUT ANY WARRANTY; without even the implied warranty
    of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the
          Free Software Foundation, Inc.
          51 Franklin Street
          Fifth Floor
          Boston, MA  02110-1301
          USA.

[TOP](#contents)

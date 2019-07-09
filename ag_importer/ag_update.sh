#!/bin/bash
 # {{{
########################################################################
#                                                                      #
#  AzureGreenImporter: Import AzureGreen data into a Zen-Cart store    #
#                                                                      #
#  This file is part of the AzureGreen data and image importing        #
#  system designed to semi-automatically import, and update, the       #
#  massive amount of information supplied by AzureGreen in a format    #
#  which fits within the standard Zen-Cart database system.            #
#                                                                      #
#  Copyright © 2019  Chindraba (Ronald Lamoreaux)                      #
#                    <plus_zen@chindraba.work>                         #
#  - All Rights Reserved                                               #
#                                                                      #
#  This software is free software; you can redistribute it and/or      #
#  modify it under the terms of the GNU General Public License,        #
#  version 2 only, as published by the Free Software Foundation.       #
#                                                                      #
#  This software is distributed in the hope that it will be useful,    #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of      #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the       #
#  GNU General Public License for more details.                        #
#                                                                      #
#  You should have received a copy of the GNU General Public License   #
#  along with this program; if not, write to the                       #
#        Free Software Foundation, Inc.                                #
#        51 Franklin Street                                            #
#        Fifth Floor                                                   #
#        Boston, MA  02110-1301                                        #
#        USA.                                                          #
#                                                                      #
########################################################################

########################################################################
#                                                                      #
# The expected, and created, directory tree used for importations      #
# The directories, other than 'working' and its subs, are expected to  #
# remain between runs of the importation script. Removing them, or the #
# use of a different "root" will create a new tree and cause the data  #
# to be treated as if it was a new installation, with corruption of    #
# the existing database entries, if any.                               #
#                                                                      #
#  *  The working root directory, either the current directory, or the #
#  │   directory given on the command line as the first argument       #
#  │                                                                   #
#  │    [$dir_data]                                                    #
#  ├──  data_current        The current versions of the cleaned and    #
#  │    └──  <files>        imported CSV files                         #
#  │                                                                   #
#  │    [$dir_orphan]                                                  #
#  ├──  _orphan             Images from extracts which did not get     #
#  │                        sorted into a directory or deleted, should #
#  │                        always be empty                            #
#  │    [$dir_pics]                                                    #
#  ├──  pics_current        The current versions of the sorted images, #
#  │    ├──  aa             stored in a directory structure where the  #
#  │    │    └──  <files>   name of the directory is the first two     #
#  │    ├──  ch             characters of the file name                #
#  │    │    └──  <files>                                              #
#  │    └──  ga                                                        #
#  │         └──  <files>                                              #
#  │                                                                   #
#  │    [$dir_active]                                                  #
#  ├──  source_latest       The latest version of the resources        #
#  │    └──  <files>        downloaded from AzureGreen                 #
#  │                                                                   #
#  │    [$dir_stores]                                                  #
#  ├──  source_record       The copy of AzureGreen resources which     #
#  │    ├──  2019.03.13     were downloaded on the given date. The     #
#  │    │    └──  <files>   files in a directory are not the ones      #
#  │    ├──  2019.03.14     which are current as of that date, but     #
#  │    │    └──  <files>   only the ones downloaded as new then       #
#  │    └──  2019.03.30                                                #
#  │         └──  <files>                                              #
#  │                                                                   #
#  └──  working             Temporary directory to hold files as they  #
#       │                   are processed, removed upon completion     #
#       │    [$dir_import]                                             #
#       ├──  data_next                                                 #
#       │    └──  <files>   Newest data files, cleaned and converted   #
#       │                   ready to import, moved into data_current   #
#       │                                                              #
#       ├──  pics_next      Image processing subdirectories            #
#       │    │    [$dir_extract]                                       #
#       │    ├──  extracts      The images extracted from the files    #
#       │    │    └──  <files>  downloaded from AzureGreen             #
#       │    │                                                         #
#       │    │                                                         #
#       │    │    [$dir_found]                                         #
#       │    ├──  found         Images from the sorted directory which #
#       │    │    └──  <files>  have been detected as new copied into  #
#       │    │                  pics_current                           #
#       │    │                                                         #
#       │    │    [$dir_sorted]                                        #
#       │    └──  sorted        Images sorted into their proper place  #
#       │         └──  <files>  with duplicates removed and the        #
#       │                       largest/best one kept                  #
#       │                                                              #
#       │    [$dir_new]                                                #
#       ├──  source_next    AzureGreen resources which have been found #
#       │    └──  <files>   to be new relative to what is our current  #
#       │                   "latest" version, moved to source_latest   #
#       │                                                              #
#       │    [$dir_test]                                               #
#       └──  source_test    The current resources, subject to being    #
#            └──  <files>   overwritten by newer downloads, copied to  #
#                           source_next if new                         #
########################################################################
# }}}

function main {
    # set/switch to the working directory
    # allow for loading old data
    # process the images
    # process the data files
    # import the data into the tables
    # clean up
}

main


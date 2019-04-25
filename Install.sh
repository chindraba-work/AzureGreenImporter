#!/bin/bash

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
#                    <zenning@chindraba.work>                          #
#  - All Rights Reserved                                               #
#                                                                      #
#  FixVid is free software; you can redistribute it and/or             #
#  modify it under the terms of the GNU General Public License,        #
#  version 2 only, as published by the Free Software Foundation.       #
#                                                                      #
#  FixVid is distributed in the hope that it will be useful,           #
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
#######################################################################/

[[ $1 ]] || { echo "Usage $0 <database_prefix> <admin_folder_name>"; exit; }
[[ $2 ]] || { echo "Usage $0 <database_prefix> <admin_folder_name>"; exit; }
perl -pi -e "s/PFX_/$1/g" Install.sql;
mv "public_html/YOUR_ADMIN" "public_html/$2"
echo ""
echo "Next steps:"
echo "   Upload the public_html folder to your server"
echo "   Use phpMyAdmin to 'import' Install.sql into your database"
echo ""


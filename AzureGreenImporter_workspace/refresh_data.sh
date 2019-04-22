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

data_list='AG_Complete_Files Departments Descriptions Product-Department StockInfo'
pushd ag_data >/dev/null
wget -N --no-if-modified-since -i ../wget_list_ag_data
for x in $data_list; do
  perl -CO -pe 'BEGIN{binmode STDIN,":encoding(cp1252)"}' <"$x.csv" >"utf8-${x,,}.csv";
  perl -pi -e 's/(\x0D|\x0A)+/\n/g;s/(^|\n)[\n\s]*/$1/g;s/,"""/,"”/g;s/""",/”",/g;s/"""\n/”"\n/g;s/([^,])""([^,\n])/$1”$2/g;s/\n([^"])/ $1/g;s/[^\S\n]{1,}([^\S]|")/$1/g' utf8-${x,,}.csv;
  if [[ 'Descriptions' == $x ]]; then
    perl -pi -e 's/([^"])\n/$1 /g' utf8-${x,,}.csv;
  fi
  mv utf8-${x,,}.csv ../import_files;
done
popd >/dev/null

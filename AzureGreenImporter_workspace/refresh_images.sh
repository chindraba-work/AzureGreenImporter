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

rm -rf import_images/images
pushd ag_images >/dev/null
mkdir -p processed
wget -N --no-if-modified-since -i ../wget_list_ag_images
for top in *.zip; do
  prefix=${top%%.zip};
  dir=${prefix,,};
  mkdir -p "temp/$dir";
  unzip -LL -d temp/$dir $top >/dev/null;
  pushd "temp/$dir" >/dev/null;
  rm -f thumbs.db;
  for pic in *; do
    [[ -f $pic ]] && {
      dest_dir=${pic::2}
      mkdir -p "../../processed/$dest_dir";
      mv "$pic" "../../processed/$dest_dir/$pic";
    }
  done
  [[ -d "$dir t" ]] && {
    pushd "$dir t" >/dev/null;
    rm -f thumbs.db;
    [[ -s "thumb $dir.zip" ]] && unzip -LL -j -o "thumb $dir.zip" >/dev/null;
    rm -f "thumb $dir.zip";
    for thumb in *; do
      thumb_ext="${thumb##*.}";
      thumb_name="${thumb%.*}";
      thumb_base="${thumb_name%_?}";
      [[ "$thumb_base" == "$thumb_name" ]] && {
        thumb_base="${thumb_name%?}";
        thumb_type="${thumb_name##$thumb_base}";
        [[ 't' != "$thumb_type" ]] && {
          thumb_name="${thumb%.*}";
          thumb_base="${thumb_name%_?}";
        };
      }
      dest_dir=${thumb_base::2};
      mkdir -p "../../../processed/$dest_dir";
      [[ ! -s "../../../processed/$dest_dir/$thumb_base.$thumb_ext" ]] && {
        mv -f "$thumb" "../../../processed/$dest_dir/$thumb_base.$thumb_ext";
      }|| {
        thumb_size=$(du --bytes "$thumb" | cut -f1);
        main_size=$(du --bytes "../../../processed/$dest_dir/$thumb_base.$thumb_ext" | cut -f1);
        (( $main_size < $thumb_size )) && {
            mv -f "$thumb" "../../../processed/$dest_dir/$thumb_base.$thumb_ext";
          } || rm -f "$thumb";
      };
    done
    popd >/dev/null;
    rm -rf "$dir t";
  }
  [[ -d "$dir z" ]] && {
    pushd "$dir z" >/dev/null;
    rm -f thumbs.db;
    for zoom in *; do
      zoom_ext="${zoom##*.}";
      zoom_name="${zoom%.*}";
      zoom_base="${zoom_name%_?}";
      [[ "$zoom_base" == "$zoom_name" ]] && {
        zoom_base="${zoom_name%?}";
        zoom_type="${zoom_name##$zoom_base}";
        [[ 'z' != "$zoom_type" ]] && {
          zoom_name="${zoom%.*}";
          zoom_base="${zoom_name%_?}";
        };
      }
      dest_dir=${zoom_base::2};
      mkdir -p "../../../processed/$dest_dir";
      [[ ! -s "../../../processed/$dest_dir/$zoom_base.$zoom_ext" ]] && {
        mv -f "$zoom" "../../../processed/$dest_dir/$zoom_base.$zoom_ext";
        } || {
          zoom_size=$(du --bytes "$zoom" | cut -f1);
          main_size=$(du --bytes "../../../processed/$dest_dir/$zoom_base.$zoom_ext" | cut -f1);
          (( $main_size < $zoom_size )) && {
            mv -f "$zoom" "../../../processed/$dest_dir/$zoom_base.$zoom_ext";
          } || rm -f "$zoom";
        }
    done
    popd >/dev/null;
    rm -rf "$dir z";
  }
  popd >/dev/null;
  rm -rf "temp/$dir"
done
rm -rf "temp";
mkdir -p public_html
mv processed public_html/images;
tar --recursive --no-acls --no-selinux --no-xattrs --gzip --create --file new_images.tar.gz public_html

mv public_html ../import_images
mv new_images.tar.gz ../import_images
popd >/dev/null

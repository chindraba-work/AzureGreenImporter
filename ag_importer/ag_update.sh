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

# The web resource to download from
SOURCE_URL="http://www.azuregreenw.com/filesForDownload"
# The zip files of images
ARCHIVE_LIST="A B C D EB EP ES F G H I J L M N O R S U V W"

function check_name { # {{{
    # Attempt to remove a size suffix. On success save the renamed image in the
    # sorted collection and return true. Return false otherwise
    source_name="$1"
    target_ext="$2"
    target_dir="$3"
    [[ -n $4 ]] || return 1
    trial_suffix="$4"
    target_name="${source_name%$trial_suffix}"
    [[ "$source_name" = "$target_name" ]] && return 1
    mv -f "$source_name.$target_ext" "$target_dir/$target_name.$target_ext"
    return 0
} # }}}

function dir_is_empty { # {{{
    # Returns true for an empty directory, false otherwise
    [ -n "$(find "$1" -maxdepth 0 -type d -empty 2>/dev/null)" ]
} # }}}

function extract_images { # {{{
    # Extract the images from the archive and flatten the directories, keeping
    # only the largest files (presuming largest dimensioned version of the image)
    mkdir -p "$dir_extract"
    arc_name="$1"
    unzip -LL -a -o -d $dir_extract "$dir_new/$arc_name.zip" >/dev/null
    # Attempt to merge the extracted files
    flatten_image_dir $dir_extract
    dir_is_empty $dir_extract || cp -rT $dir_extract $dir_orphan
    rm -rf "$dir_extract"
} # }}}

function filter_images {
    echo "filter_images";
}

function freshen { # {{{
    # Optionally retrieve the newest file from AzureGreen, compare it to the active version
    # If it is changed (presumably newer) copy it to the collection of new sources, return true
    # Return false otherwise
    src_name="$1"
    src_url="$2"
    [[ $pre_loaded ]] || wgetter "$src_url/$src_name"
    [ -e "$dir_test/$src_name" ] || return 1 
    [ -e "$dir_active/$src_name" ] && {
        last_sum="$(md5sum "$dir_active/$src_name" | awk -e '{print $1 }')"
        test_sum="$(md5sum "$dir_test/$src_name" | awk -e '{print $1}')"
        [ $test_sum = $last_sum ] && return 1
    }
    cp -p "$dir_test/$src_name" "$dir_new/"
    return 0;
} # }}}

function freshen_images { # {{{
    # Update and process the image archive files
    for data_file in $ARCHIVE_LIST; do
      freshen "$data_file.zip" "$SOURCE_URL" && extract_images $data_file
    done
} # }}}

function flatten_image_dir { # {{{
    # Find all the files, including in zip files and subdirectories
    # and attempt to merge each one into a sorted directory tree
    source_dir="$1"
    dir_trap='.+[[:space:]][tz]$'
    [[ -n $2 ]] && merge_suffix="$2" || merge_suffix="";
    mkdir -p "$dir_sorted"
    pushd "$source_dir" >/dev/null
    # Search for, and extract, any zip files included in the archive
    find . -maxdepth 1 -type f -name "*.zip" | while read zip_path; do
        zip_file="${zip_path##*/}"
        zip_name="${zip_file%.zip}"
        unzip -a -o -j -LL "$zip_name" >/dev/null
        rm -f "$zip_file"
    done
    # Remove Window thumbnail cache files
    find . -iname thumbs.db -delete
    # Process remaining files, hopefully all images
    for pic_path in *; do
        [[ -f $pic_path ]] || continue
        pic_file="${pic_path##*/}"
        pic_ext="${pic_file##*.}"
        pic_name="${pic_file%.$pic_ext}"
        sort_image "$pic_name" $pic_ext "$merge_suffix"
    done
    # Check into any subdirectories, apply the same process again
    find . -type d | while read dir_path; do
        dir="${dir_path##*/}"
        # Only process directories named like "* z" or "* t"
        [[ "$dir" =~ $dir_trap ]] || continue
        flatten_image_dir "$dir" "${dir: -1}"
        dir_is_empty "$dir" && { rmdir "$dir" || : ; } || mv "$dir" "$dir_orphan";
    done
    popd >/dev/null
} # }}}

function keep_larger {
    echo "keep_larger"
}

function pre_fetch { # {{{
    # Loads files from a directory, as if they had been downloaded
    # The source directory name is presumed to be a date: YYYY.MM.DD
    # The date format will also be used when saving active downloads
    # and image upload archives (with a time-stamp affixed).
    src_dir="$1";
    [[ -d "$dir_stores/$src_dir/" ]] || return
    cp -rpT "$dir_stores/$src_dir" "$dir_test"
    pre_load_id="$src_dir"
    pre_loaded=0;
}# }}}

function process_images { # {{{
    freshen_images
    filter_images
    save_images
} # }}}

function save_images {
    echo "save_images";
}

function setup { # {{{
    # The root of the directory tree used in the processing and importing of data from AzureGreen
    # This is the current directory unless a path is given as an argument
    [[ -z $1 ]] \
        && $dir_root="/srv/arow-dev/importer/importing_tree" \
        || dir_root="$1"
    # Create the standing directories, if they do not already exist
    # Will also force the population of all other directories based on current
    # AzureGreen resource files
    mkdir -p $dir_root/{source_{record,latest},{data,pics}_current,_orphans}

    # The most recent version of each file downloaded from AzureGreen
    dir_active="$dir_root/source_latest"

    # The by-date record of files downloaded from AzureGreen
    dir_stores="$dir_root/source_record"

    # The utf8 files to load into the database (always kept current)
    dir_data="$dir_root/data_current"

    # The sorted collection of images on the server
    dir_pics="$dir_root/pics_current"

    # Images found in zip files that somehow didn't get processed
    dir_orphan="$dir_root/_orphans"

    # Create the temporary directories used in processing.
    # These will be deleted when the process ends

    # Initially the last download files, potentially replaced by a new version
    dir_test="$dir_root/working/source_test"
    mkdir -p "$dir_test"
    # If there is a set of files already in use, copy them as the starting point
    dir_is_empty $dir_active || cp -rpT $dir_active $dir_test
    # Temporary directory to hold downloads detected as new (md5sum)
    dir_new="$dir_root/working/source_next"
    mkdir -p "$dir_new"

    # New versions of the utf8 import files to copy into $dir_data
    dir_import="$dir_root/working/data_next"
    mkdir -p "$dir_import"

    # Temporary directory to hold unzipped images
    dir_extract="$dir_root/working/pics_next/extracts"
    mkdir -p "$dir_extract"
    # Temporary directory to hold renamed and sorted images
    dir_sorted="$dir_root/working/pics_next/sorted"
    mkdir -p "$dir_sorted"
    # Temporary directory to hold images detected as new (md5sum)
    dir_found="$dir_root/working/pics_next/found"
    mkdir -p "$dir_found"
} # }}}

function sort_image { # {{{
    # Attempt to match the name of this image with one that already exists. If found, keep the larger
    # of the two, remove the other.
    # If no match is found, attempt to create a name without any size suffix and save the image under
    # that name. The last resort is to save the image under its original name
    source_name="$1"
    merge_ext="$2"
    merge_suffix=${3:-""} # May not exist. Ensure it's at least an empty string
    merge_prefix="${source_name::2}"
    mkdir -p "$dir_sorted/$merge_prefix"
    # Best choice is a direct filename match
    keep_larger "$source_name" $merge_ext "$dir_sorted/$merge_prefix" '' && return
    # If there is suppposed to be no suffix, test it anyway
    [[ -z $merge_suffix ]] && {
        # Remove the _? pattern suffix from the name if it exists
        trial_name="${source_name%_?}"
        # Use that name if it is different, otherwise keep the original name
        [[ "x$trial_name" = "x" ]] && merge_name="$source_name" || merge_name="$trial_name"
        # Move the file to the storage area
        mv -f "$source_name.$merge_ext" "$dir_sorted/$merge_prefix/$merge_name.$merge_ext";
        return; 
    }
    # Next choice is to strip the suffix itself
    keep_larger "$source_name" $merge_ext "$dir_sorted/$merge_prefix" $merge_suffix && return
    # Last chance for a suffix is with an underscore leader
    keep_larger "$source_name" $merge_ext "$dir_sorted/$merge_prefix" "_$merge_suffix" && return
    # Safest choice for a new name is if there is an underscore leader to the suffix
    check_name "$source_name" $merge_ext "$dir_sorted/$merge_prefix" "_$merge_suffix" && return
    # Not so safe, but common in the source archives is the suffix directly on the name
    # Hopefully, in the cases where this is the case, there will already be an image of that name
    # without the suffix, and the keep_larger calls above will have deleted or used the image
    check_name "$source_name" $merge_ext "$dir_sorted/$merge_prefix" "$merge_suffix" && return
    # Last test is to remove the _? pattern suffix from the name if it exists
    trial_name="${source_name%_$merge_suffix}"
    # Use that name if it is different, otherwise keep the original name
    [[ "x$trial_name" = "x" ]] && merge_name="$source_name" || merge_name="$trial_name"
    # All else fails, just use the original name and save the image
    mv -f "$source_name.$merge_ext" "$dir_sorted/$merge_prefix/$merge_name.$merge_ext"
    return 
} # }}}

function wgetter { # {{{
    # Retrieves a file from AzureGreen, if it is newer than the local copy
    target="$1"
    wget --directory-prefix=$dir_test --timestamping --no-if-modified-since $target
} # }}}

function main {
    realpath $1 > /dev/null 2>&1 \
        && setup "$(realpath $1)" \
        || setup "$PWD"
    pre_loaded=0
    [[ -n $2 ]] && \
        pre_fetch $2
    process_images
    # process the data files
    # import the data into the tables
    # clean up
}

main $1 $2


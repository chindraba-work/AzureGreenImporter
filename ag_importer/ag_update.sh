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
#       │    │    [$dir_scrape]                                        #
#       │    ├──  scrape        Images scraped from the website which  #
#       │    │    └──  <files>  have been sorted and copied into the   #
#       │    │                  pics_current folder                    #
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

# Dates for the database items
#  The base date for "pre-existing" products and categories when pre-loading
DB_ADD_DATE='2018-10-31 21:13:08'
#  The date available, presumed to be now, changed when pre-loading
DB_NEW_DATE="$(date --utc +%F%_9T)"

# Database access information 
WORK_DB_HOST=''
WORK_DB_NAME=''
WORK_DB_USER=''
WORK_DB_PASS=''
# If WORK_DB_PASS is left blank, the password will be prompted from on the command line

# Find the current date, for when creating a record of new downloads
NOW_DATE="$(date --utc +%Y.%m.%d)"
# Find the timestamp for database patch file names
PATCH_DATE="$(date --utc +%Y.%m.%d-%H.%M.%s)"

# The web resources to download from
SOURCE_URL="http://www.azuregreenw.com/filesForDownload"
IMAGE_URL="http://www.azuregreen.net/Images"

# The zip files of images
ARCHIVE_LIST="A B C D EB EP ES F G H I J L M N O R S U V W"
# The range of years for which complete Excel sheets are available
YEAR_FIRST="2018"
YEAR_LAST="$(date --utc +%Y)"
# The Excel sheets showing cummulative data, useful for user intervention
CHANGE_LIST="changes isbn"
# The regularly updated CSV files, most of the data comes from here
PRODUCT_DATA_LIST="Descriptions StockInfo Departments Product-Department AG_Complete_Files"
# The prioritized list of preferred master categories
MASTER_CAT_LIST="56 234 115 18 318 200 201 505 376 243 238 198 308 128 21 71 520 551 100 484 104 133 95 61 86 134 544 62 475 533 177 263 326 440 527 528 460 459 432 504 447 83 34 286 472 16 464 538 374 471 506 494 546 474 473 333 142 103 147 389 293 347 363 47 336 351 40 516 530 448 296 337 352 387 379 138 97 332 340 84 67 468 322 55 343 208 205 206 248 265 207 482 481 209 321 280 418 164 539 167 96 373 346 217 549 526 349 362 388 461 232 542 287 181 532 540 218 199 466 264 269 281 541 552 2 442 223 174 390 537 141 203 204 242 75 469 175 323 430 496 545 117 226 339 353 501 146 297 341 355 342 277 114 105 487 152 399 249 35 329 436 236 508 169 182 20 525 113 499 283 193 89 457 483 498 495 180 369 497 550 514 513 515 259 52 51 384 53 54 268 111 325 143 403 76 394 503 302 398 480 140 345 359 368 455 465 502 48 380 307 510 375 486 386 395 68 179 324 500 479 112 304 441 121 118 156 155 162 151 63 31 377 300 275 224 334 306 225 523 295 77 521 299 49 511 512 78 79 168 518 294 65 298 517 305 522 303 519 64 66 69 407 535 547 534 548 415 485 94 126 311 370 137 536 144 88 330 60 543 122 125 282 101 157 364 274"

# Find the directory of this script. Needed to access the SQL script.
code_path="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

function check_name {
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
}

function convert_data_file {
    # Convert the file from DOS to UTF-8 character set.
    src_file="$1"
    perl -CO -pe 'BEGIN{binmode STDIN,":encoding(cp1252)"}' <"$dir_new/$src_file.csv" >"$dir_import/db_import-${src_file,,}.csv"
    # Attempt to "clean" the data auto generated by Excel
    perl -pi -e 's/(\x0D|\x0A)+/\n/g;s/(^|\n)[\n\s]*/$1/g;s/""""/”/g;s/,"""/,"”/g;s/""",/”",/g;s/"""\n/”"\n/g;s/""([^\n])/”$1/g;s/\n([^"])/ $1/g;s/[^\S\n]{1,}([^\S]|")/$1/g' "$dir_import/db_import-${src_file,,}.csv";
    if [[ 'Descriptions' == $src_file ]]; then
        perl -pi -e 's/([^"])\n/$1 /g' "$dir_import/db_import-${src_file,,}.csv";
    fi
}

function dir_is_empty {
    # Returns true for an empty directory, false otherwise
    [ -n "$(find "$1" -maxdepth 0 -type d -empty 2>/dev/null)" ]
}

function extract_images {
    # Extract the images from the archive and flatten the directories, keeping
    # only the largest files (presuming largest dimensioned version of the image)
    mkdir -p "$dir_extract"
    arc_name="$1"
    unzip -LL -a -o -d $dir_extract "$dir_new/$arc_name.zip" >/dev/null
    # Attempt to merge the extracted files
    flatten_image_dir $dir_extract
    dir_is_empty $dir_extract || cp -rT $dir_extract $dir_orphan
    rm -rf "$dir_extract"
}

function filter_new_images {
    # Compare all the newly sorted images with same-named ones from the active set
    # A different hash is presumed to mean it is a new image, hopefully better than
    # the older one
    # All images found to be new, or presumed new, are moved to a staging area
    # All remaining images are discarded
    mkdir -p "$dir_found"
    pushd $dir_sorted > /dev/null
    find . -type d -name "??"| while read prefix_path; do
        prefix="${prefix_path##*/}"
        [[ "$prefix" = "." ]] && continue
        pushd "$prefix" > /dev/null
        find . -type f | while read pic_path; do
            pic="${pic_path##*/}"
            [[ -s "$dir_pics/$prefix/$pic" ]] && {
                test_sum="$(md5sum "$pic" | awk -e '{print $1}')"
                last_sum="$(md5sum "$dir_pics/$prefix/$pic" | awk -e '{print $1 }')"
                [[ $test_sum = $last_sum ]];
            } || { mkdir -p "$dir_found/$prefix"; mv -f "$pic" "$dir_found/$prefix/$pic"; }
        done
        popd > /dev/null
        rm -rf "$prefix"
    done
    popd > /dev/null
}

function freshen {
    # Optionally retrieve the newest file from AzureGreen, compare it to the active version
    # If it is changed (presumably newer) copy it to the collection of new sources, return true
    # Return false otherwise
    src_name="$1"
    uri_name="${src_name// /%20}"
    src_url="$2"
    [ $pre_loaded ] || retrieve_file "$src_url/$uri_name"
    [ -e "$dir_test/$src_name" ] || return 1 
    [ -e "$dir_active/$src_name" ] && {
        last_sum="$(md5sum "$dir_active/$src_name" | awk -e '{print $1 }')"
        test_sum="$(md5sum "$dir_test/$src_name" | awk -e '{print $1}')"
        [ $test_sum = $last_sum ] && return 1
    }
    cp -p "$dir_test/$src_name" "$dir_new/"
    return 0;
}

function freshen_annual_sheets {
    # Update the annual master change files, for human comsumption only
    for annual_file in $(seq $YEAR_FIRST $YEAR_LAST); do
        freshen "$annual_file master updates.xlsx" "$SOURCE_URL"
    done
}

function freshen_change_sheets {
    # Update to current change files, for human consumption only
    for change_file in $CHANGE_LIST; do
      freshen "$change_file.xls" "$SOURCE_URL"
    done
}

function freshen_images {
    # Update and process the image archive files
    echo "Processing image archives."
    for data_file in $ARCHIVE_LIST; do
      freshen "$data_file.zip" "$SOURCE_URL/imageZipFiles" && extract_images $data_file
    done
    filter_new_images
    store_new_images 
    echo "Image archives processed."
}

function freshen_product_data {
    # Update and convert the stock information files
    mkdir -p "$dir_import"
    for data_file in $PRODUCT_DATA_LIST; do
        freshen "$data_file.csv" "$SOURCE_URL/dailyFiles" && convert_data_file $data_file
    done
}

function freshen_spreadsheets {
    freshen_annual_sheets
    freshen_change_sheets
}

function flatten_image_dir {
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
}

function generate_categories_sql {
    # Create the SQL file to assign master categories to new products
    rm "db_import-master_categories.sql" 2>/dev/null
    for category_id in $MASTER_CAT_LIST; do
        cat <<FIXER >>"db_import-master_categories.sql"
UPDATE \`products\`
JOIN \`products_to_categories\`
    ON \`products_to_categories\`.\`products_id\`
        = \`products\`.\`products_id\`
SET \`master_categories_id\`=$category_id
WHERE
    \`master_categories_id\`=@IMPORT_CATEGORY AND
    \`categories_id\`=$category_id;

FIXER

    done;
}

function get_image_list {
    touch "$dir_root/img_list"
    image_query='SELECT DISTINCT `products_image` FROM `products` ORDER BY `products_image`;'
    mysql -h $WORK_DB_HOST -u $WORK_DB_USER -p$WORK_DB_PASS -s -D $WORK_DB_NAME -e "$image_query" >"$dir_root/img_list"
}

function get_images {
    rm -f "$dir_root/img_missing" 2>/dev/null
    echo "Searching for missing images."
    while read model_path; do
        model_file="${model_path##*/}"
        model_dir="${model_path%/$model_file}"
        model_ext="${model_file##*.}"
        model_name="${model_file%.$model_ext}"
        model="${model_name^^}"
        [[ -s "$dir_pics/$model_path" ]] || \
        [[ -s "$dir_scrape/$model_path" ]] || \
        retrieve_image $model $model_dir $model_path || \
            echo "$model_path" >> "$dir_root/img_missing"
    done < "$dir_root/img_list"
}

function keep_larger {
    # Keep the larger of the two files: one currently saved and one under examination
    # Allows for the possibility that the one being tested has a suffix for its size
    # when attempting to find the file to compare with.
    # If there is no comparison file return false
    # It there is a comparison file, replace it if the new file is larger, delete the 
    # new file if it is not larger, return true in either case.
    source_name="$1"
    target_ext="$2"
    target_dir="$3"
    trial_suffix="$4"
    target_name="${source_name%$trial_suffix}"
    [[ -e $target_dir/$target_name.$target_ext ]] || return 1
    target_size=$(du --bytes "$target_dir/$target_name.$target_ext" | cut -f1)
    source_size=$(du --bytes "$source_name.$target_ext" | cut -f1)
    if (( target_size < source_size )); then
        mv -f "$source_name.$target_ext" "$target_dir/$target_name.$target_ext"
    else
        rm -f "$source_name.$target_ext"
    fi
    return 0
}

function pre_fetch {
    # Loads files from a directory, as if they had been downloaded
    # The source directory name is presumed to be a date: YYYY.MM.DD
    # The date format will also be used when saving active downloads
    # and image upload archives (with a time-stamp affixed).
    src_dir="$1";
    [[ -d "$dir_stores/$src_dir/" ]] || return
    cp -rpT "$dir_stores/$src_dir" "$dir_test"
    pre_load_id="$src_dir"
    pre_loaded=0;
}

function retrieve_file {
    # Retrieves a file from AzureGreen, if it is newer than the local copy
    target="$1"
    wget --directory-prefix=$dir_test --timestamping --no-if-modified-since $target
}

function retrieve_image {
    # Tries to retrieve the named file, with various suffixes, saving the first one found
    target_base="$1" && target_dir="$2" && target_path="$3" || return 1
    target="${target_base}_Z.jpg"
    retrieve_new_image $target $target_dir $target_path && return 0
    target="${target_base}_Z.jpeg"
    retrieve_new_image $target $target_dir $target_path && return 0
    target="${target_base}.jpg"
    retrieve_new_image $target $target_dir $target_path && return 0
    target="${target_base}.jpeg"
    retrieve_new_image $target $target_dir $target_path && return 0
    return 1;
}

function retrieve_new_image {
    # Retrieves an image file from AzureGreen, if it is newer than the local copy
    target="$1" && target_dir=$2 && image_path="$3" || return 1
    wget --directory-prefix="$dir_scrape" --timestamping --no-if-modified-since $IMAGE_URL/$target >/dev/null 2>&1 && {
        mkdir -p "$dir_scrape/$target_dir"
        mv "$dir_scrape/$target" "$dir_scrape/$image_path";
    }
}

function save_imports {
    # Copy created UTF-8 data files into the active collection
    dir_is_empty $dir_import && return 1
    find "$dir_import" -maxdepth 1 -name "db_import*.csv" | while read import_file; do
        mv -f "$import_file" "$dir_data"
    done
    rm -rf "$dir_import"
    return 0
}

function save_sources {
    # Copy new source files to the active set and
    # Save new files in the storage under the current date
    dir_is_empty $dir_new && return
    cp -fp "$dir_new"/* "$dir_active"
    [ $pre_loaded ] || {
      mkdir -p "$dir_stores/$NOW_DATE"
      cp -p "$dir_new"/* "$dir_stores/$NOW_DATE"
    }
    rm -rf "$dir_new"
    rm -rf "$dir_test"
}

function setup {
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
    # Temporary directory to scaped images
    dir_scrape="$dir_root/working/pics_next/scrape"
    mkdir -p "$dir_scrape"
}

function sort_image {
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
}

function store_new_images {
    dir_is_empty $dir_found && return
    cp -rpT "$dir_found" "$dir_pics"
    pushd $dir_found > /dev/null
    [ $pre_loaded ] && arc_date="$pre_load_id" || arc_date="$NOW_DATE"
    tar --create --recursive --gzip --no-acls --no-selinux --no-xattrs --file="$dir_stores/new_images_$arc_date.tar.gz" *
    popd >/dev/null
    rm -rf "$dir_found"
}

function store_scraped_images {
    dir_is_empty $dir_scrape && return
    cp -rpT "$dir_scrape" "$dir_pics"
    pushd "$dir_scrape" > /dev/null
    [ $pre_loaded ] && arc_date="$pre_load_id" || arc_date="$NOW_DATE"
    tar --create --recursive --gzip --no-acls --no-selinux --no-xattrs --file="$dir_stores/new_images_${arc_date}s.tar.gz" *
    popd >/dev/null
    rm -rf "$dir_scrape"
}

function update_database {
    for import_file in $PRODUCT_DATA_LIST; do
        check_name="db_import-${import_file,,}.csv"
        [ -e $dir_data/$check_name ] || return
    done
    echo "Importing data into the database."
    pushd $dir_data > /dev/null
    [ $pre_loaded ] && DB_NEW_DATE="$(echo $pre_load_id | perl -pe 's/\./-/g')"' 21:13:08'
    [ $pre_loaded ] && PATCH_DATE="$pre_load_id-21.13.0807136905"
    [ $pre_loaded ] || DB_ADD_DATE="$DB_NEW_DATE"
    echo '"'$DB_ADD_DATE'","'$DB_NEW_DATE'"' > db_import-control_dates.csv
    generate_categories_sql 
    echo " ... Categories"
    mysql -s -h $WORK_DB_HOST -u $WORK_DB_USER -p$WORK_DB_PASS -D $WORK_DB_NAME < "$code_path/ag_import_departments.sql" > "$dir_active/inventory_patch-departments.sql"
    echo " ... Products"
    mysql -s -h $WORK_DB_HOST -u $WORK_DB_USER -p$WORK_DB_PASS -D $WORK_DB_NAME < "$code_path/ag_import_products.sql" > "$dir_active/inventory_patch-products.sql"
    echo " ... Product placements"
    mysql -s -h $WORK_DB_HOST -u $WORK_DB_USER -p$WORK_DB_PASS -D $WORK_DB_NAME < "$code_path/ag_import_placements.sql" > "$dir_active/inventory_patch-placements.sql"
    popd > /dev/null
    cat "$dir_active/inventory_patch-{departments,products,placements}.sql" "$dir_active/inventory_patch-combined.sql"
    cp "$dir_active/inventory_patch-combined.sql" "$dir_stores/inventory_patch-combined-$PATCH_DATE.sql"
    gzip "$dir_stores/inventory_patch-combined-$PATCH_DATE.sql"
    cp -p $dir_stores/inventory_patch-combined-$PATCH_DATE.sql.gz "$dir_active/current_patch-combined.sql.gz"
    echo "Importing of data complete."
}

function main {
    realpath $1 > /dev/null 2>&1 \
        && setup "$(realpath $1)" \
        || setup "$PWD"
    [[ -n $2 ]] && \
        pre_fetch $2
    [[ -n $3 ]] && \
        DB_ADD_DATE="${3} 21:13:08"
    freshen_product_data 
    freshen_spreadsheets
    freshen_images
    save_sources
    save_imports && update_database
    get_image_list
    get_images
    store_scraped_images 
    [[ -s "$dir_root/img_missing" ]] && {
        echo ""
        echo "Unable to locate the following images:"
        echo ""
        cat "$dir_root/img_missing";
    }
    rm -r "$dir_root/img_missing" 2>/dev/null
    rm -r "$dir_root/img_list" 2>/dev/null
    rm -rf "$dir_root/working"
}

[[ -n $2 ]] && echo "... Processing date: '$2' files into '$1' directory"
main $1 $2


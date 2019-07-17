-- Comment block {{{
/* #####################################################################
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
##################################################################### */
-- }}}

-- Instructions {{{
-- To use this it is necessary to have a copy/backup from the live server
-- of the following tables:
--     categories
--     categories_descriptions
--     meta_tags_categories_descriptions
--     meta_tags_products_descriptions
--     products
--     products_descriptions
--     products_to_categories
-- The rest of the database is not significant for the process.
-- The process should NEVER be run against the active database!
-- The generated patch script should be imported from the store's admin
--    Admin -> Tools -> Import SQL Patch.
-- The site may have a prefix on the table names, that is not handled
-- here. The Import SQL Patch expects table names to NOT have that on
-- the table names and will add it to them when it executes the script.
-- }}}

-- Setup the work area {{{
-- Table for control dates {{{
DROP TEMPORARY TABLE IF EXISTS `staging_control_dates`;
CREATE TEMPORARY TABLE `staging_control_dates` (
    `add_date` DATETIME NOT NULL DEFAULT '2018-10-31 21:13:08',
    `new_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP 
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4;
-- }}}

-- Read the control dates in control_dates.csv {{{
LOAD DATA LOCAL
    INFILE './db_import-control_dates.csv'
INTO TABLE `staging_control_dates`
    FIELDS TERMINATED BY ',' 
    OPTIONALLY ENCLOSED BY '"' 
    LINES TERMINATED BY '\n';
-- }}}

-- Set the global control dates for later use {{{
-- add_date will be used for the 'created' type fields in the tables
-- new_date will be used for data_available on new products.
--   if all cases, the 'modified' type fields will be untouched, allowing
--   the store to create/update those as normal. Will serve as a flag here
--   indicating that the store (under admin control) made changes to the 
--   data, making that record 'untouchable' for updates to names and other
--   description-type information. 
SELECT
    @SCRIPT_ADD_DATE:=`add_date`,
    @SCRIPT_NEW_DATE:=`new_date`
FROM `staging_control_dates`;
-- }}}

-- TODO: Add the creation of db_import-control_dates.csv to the Bash script.
--       Only needed if there is a pre-load happening, so that the date on
--       the pre-load will match the "new" date for new entries in the data
--       Could be useful, as well, to customize the "add" date for entries.
-- }}}

-- Import category data
--    clone existing data [staging_categories_current]
-- Convenience view for current data {{{
CREATE OR REPLACE VIEW `staging_categories_live` AS
SELECT
    `categories_id`,
    `categories_image`,
    `parent_id`,
    `date_added`,
    `last_modified`,
    `categories_status`,
    `categories_name`,
    `categories_description`,
    `metatags_title`,
    `metatags_keywords`,
    `metatags_description`
FROM `categories`
LEFT OUTER JOIN `categories_description`
    USING (`categories_id`)
LEFT OUTER JOIN `meta_tags_categories_description`
    USING (`categories_id`,`language_id`)
WHERE `language_id`=1
ORDER BY `parent_id`,`categories_name`;
-- }}}
--    read raw data from CSV file [staging_categories_ag {db_import-departments.csv}]
-- The table to read the CSV into {{{
DROP TABLE IF EXISTS `staging_categories_ag`;
CREATE TEMPORARY TABLE `staging_categories_ag` (
    `dept_name`  VARCHAR(255) NOT NULL,
    `dept_code`  INT(11) NOT NULL,
    `dept_deep`  INT(11) NOT NULL,
    `dept_show`  TINYINT(1) NOT NULL DEFAULT 1,
    `parent_id`  INT(11) NOT NULL DEFAULT 0,
    INDEX (`dept_code`),
    INDEX (`parent_id`)
) Engine=MyISAM DEFAULT CHARSET=utf8mb4;
-- }}}
-- Read the AzureGreen data file {{{
LOAD DATA LOCAL
    INFILE 'db_import-departments.csv'
INTO TABLE `staging_categories_ag`
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES;
-- Do some cleanup of AzureGreen data
DELETE FROM `staging_categories_ag`
WHERE `dept_code` < 0;
-- }}}
--    convert data to Zen-Cart standards [staging_categories_import]
-- Table for applying Zen-Cart rules to the categories data {{{
DROP TABLE IF EXISTS `staging_categories_import`;
CREATE TEMPORARY TABLE `staging_categories_import` (
    `categories_id`           INT(11) NOT NULL,
    `parent_id`               INT(11) NOT NULL,
    `categories_name`         VARCHAR(32),
    `categories_description`  TEXT,
    `categories_status`       TINYINT(1) NOT NULL DEFAULT 1,
    `metatags_title`          VARCHAR(255) NOT NULL DEFAULT '',
    `metatags_keywords`       TEXT DEFAULT NULL,
    `metatags_description`    TEXT DEFAULT NULL
) Engine=MyISAM DEFAULT CHARSET=utf8mb4;
-- }}}
-- Convert the data to Zen-Cart rules {{{
INSERT INTO `staging_categories_import` (
    `categories_id`,
    `parent_id`,
    `categories_name`,
    `categories_description`,
    `categories_status`,
    `metatags_title`,
    `metatags_keywords`,
    `metatags_description`
) SELECT
    `dept_code`,
    `parent_id`,
    LEFT(`dept_name`,32),
    `dept_name`,
    `dept_show`,
    `dept_name`,
    `dept_name`,
    `dept_name`
FROM `staging_categories_ag`
ORDER BY `dept_deep`,`parent_id`,`dept_code`;
-- }}}
--    mark dropped categories as inactive
-- Missing categories become inactive {{{
DROP TABLE IF EXISTS `staging_categories_dropped`;
CREATE TEMPORARY TABLE `staging_categories_dropped` (
    `categories_id` INT(11) NOT NULL
)Engine=MyISAM AS
SELECT
    `staging_categories_live`.`categories_id`
FROM `staging_categories_live`
LEFT OUTER JOIN `staging_categories_import`
    ON `staging_categories_live`.`categories_id`=`staging_categories_import`.`categories_id`
WHERE `staging_categories_import`.`categories_id` IS NULL;
-- }}}
--    remove unchanged categories from _import
-- Drop unchanged categories from further processin {{{
DELETE `staging_categories_import`
FROM `staging_categories_import`
JOIN `staging_categories_live`
    ON `staging_categories_import`.`categories_id`=`staging_categories_live`.`categories_id`
WHERE
    `staging_categories_import`.`categories_name`=`staging_categories_live`.`categories_name` AND
    `staging_categories_import`.`parent_id`=`staging_categories_live`.`parent_id` AND
    `staging_categories_import`.`categories_status`=`staging_categories_live`.`categories_status`;
-- }}}
--    filter new categories from _import [staging_categories_new]
-- Move new categories to their own table {{{
DROP TABLE IF EXISTS `staging_categories_new`;
CREATE TEMPORARY TABLE `staging_categories_new` (
    `categories_id`           INT(11) NOT NULL,
    `parent_id`               INT(11) NOT NULL,
    `categories_name`         VARCHAR(32),
    `categories_description`  TEXT,
    `categories_status`       TINYINT(1) NOT NULL DEFAULT 1,
    `metatags_title`          VARCHAR(255) NOT NULL DEFAULT '',
    `metatags_keywords`       TEXT DEFAULT NULL,
    `metatags_description`    TEXT DEFAULT NULL
) Engine=MyISAM DEFAULT CHARSET=utf8mb4 AS
SELECT
    `staging_categories_import`.`categories_id`,
    `staging_categories_import`.`parent_id`,
    `staging_categories_import`.`categories_name`,
    `staging_categories_import`.`categories_description`,
    `staging_categories_import`.`categories_status`,
    `staging_categories_import`.`metatags_title`,
    `staging_categories_import`.`metatags_keywords`,
    `staging_categories_import`.`metatags_description`
FROM `staging_categories_import`
LEFT OUTER JOIN `staging_categories_live`
    ON `staging_categories_import`.`categories_id`=`staging_categories_live`.`categories_id`;
DELETE `staging_categories_import`
FROM `staging_categories_import`
JOIN `staging_categories_new`
    ON `staging_categories_import`.`categories_id`=`staging_categories_new`.`categories_id`;
-- }}}
--    find and update parent category changes
-- Update changes in parent_id {{{
DROP TABLE IF EXISTS `staging_categories_parent`;
CREATE TEMPORARY TABLE `staging_categories_parent` (
    `categories_id` INT(11) NOT NULL,
    `parent_id`     INT(11) NOT NULL
)Engine=MyISAM AS
SELECT
    `staging_categories_import`.`categories_id`,
    `staging_categories_import`.`parent_id`
FROM `staging_categories_import`
JOIN `staging_categories_live`
    ON `staging_categories_import`.`categories_id`=`staging_categories_live`.`categories_id`
WHERE NOT `staging_categories_import`.`parent_id`=`staging_categories_live`.`parent_id`;
-- }}}
--    update category names, unless current name was manually adjusted
-- Update changes in category names {{{
DROP TABLE IF EXISTS `staging_categories_rename`;
CREATE TEMPORARY TABLE `staging_categories_rename` (
    `categories_id`         INT(11) NOT NULL,
    `categories_name        VARCHAR(32) NOT NULL DEFAULT '',
    `categories_description TEXT NOT NULL DEFAULT ''
)Engine=MEMORY DEFAULT CHARSET=utf8mb4 AS
SELECT
    `staging_categories_import`.`categories_id`,
    LEFT(`staging_categories_import`.`categories_name`,32),
    `staging_categories_import`.`categories_name`
FROM `staging_categories_import`
JOIN `staging_categories_live`
    ON `staging_categories_live`.`categories_id`=`staging_categories_import`.`categories_id`
WHERE NOT
    `staging_categories_live`.`categories_description`=`staging_categories_import`.`categories_description` AND
    `staging_categories_live`.`last_modified` IS NULL;
-- }}}
--    verify status of categories
--    collect list of anomolies (name too long, missing parent, active child-inactive parent, etc.) [staging_categories_errors]
--    insert new categories into database
--    force inactive status for unwanted categories


-- Import product data
--    clone existing data [staging_products_current]
--    read raw data from CSV file [staging_products_complete_ag {db_import-ag_complete_files.csv},
--                                 staging_products_stockinfo_ag {db_import-stockinfo.csv},
--                                 staging_products_description_ag {db_import-descriptions.csv}]
--    convert data to Zen-Cart standards [staging_products_import]
--    filter new products from _import [staging_products_new]
--    mark dropped products as inactive
--    update quantity, weight and price, where available, from import data
--    remove unchanged products from _import, ignoring changes in qty, price and weight
--    update product name and description where different, unless manually changed in database
--    update product status based on import status or quantity
--    collect anomolies (name/desc too long, missing data, etc.) [staging_products_errors]
--    insert new products into database

-- Import product-category links
--    clone existing data [staging_products_categories_current]
--    read raw data from CSV file [staging_products_categories_ag {db_import-product-department.csv}]
--    convert data to Zen-Cart standards [staging_products_categories_import]
--    correct AzureGreen error, changing cat-202 to cat-552 across the board
--    remove unchanged links from _import
--    filter new links from _import [staging_products_categories_new]
--    collect anomolies (product in non-leaf category) [staging_products_categories_errors] 
--    insert new links into database
--    verify master of all products is still in link table
--       for dropped categories: set master to "missing", and add to anomolies
--       for existing categories: re-add to link table, and add to anomolies


-- Generate script to use in the admin area Install SQL Patch page
--    INSERT for products
--               products_descriptions
--               meta_tags_products_descriptions
--               categories
--               categories_descriptions
--               meta_tags_categories_descriptions
--               products_to_categories
--    UPDATE for products
--               products_descriptions
--               meta_tags_products_descriptions
--               categories
--               categories_descriptions
--               meta_tags_categories_descriptions
--               products_to_categories
--    DELETE FROM products_to_categories

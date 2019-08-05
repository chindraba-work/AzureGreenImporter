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
) ENGINE=MEMORY DEFAULT CHARSET=utf8mb4;
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
CONCAT('@SCRIPT_ADD_DATE="',@SCRIPT_ADD_DATE:=`add_date`,'";')
FROM `staging_control_dates`;
SELECT
CONCAT('@SCRIPT_NEW_DATE="',@SCRIPT_NEW_DATE:=`new_date`,'";')
FROM `staging_control_dates`;
-- }}}

-- Set the AUTO_INCREMENT values for the category and product tables {{{
-- AzureGreen provides numeric values for categories and any new ones
-- added to the database need to leave room for them to add more.
-- Setting a baseline of 100,000 allows for more categories to be added
-- by AzureGreen than is concievable.
-- Using the same division point for products will segregate the items
-- added in this process from those added using the normal process.
-- Setting the AUTO_INCREMENT value for both tables on the live site
-- will cause new products and categories to be assigned ID values 
-- over that value, leaving plenty of room for adding values below
-- that limit here without fear of collisions between the two. It also
-- can serve as a limit of what to check. No point in making a category
-- inactive that's not in the AzureGreen data, when it wasn't one of
-- their categories to begin with.

-- The remote system needs to be set to follow this limit, the local 
-- tables actually have to NOT have the value set, as the values added
-- need to be BELOW that limit 
SET @INCREMENT_BASE=100001;

-- Apply the limit to the remote categories table {{{
SELECT CONCAT(
    'ALTER TABLE `categories` AUTO_INCREMENT=',
    @INCREMENT_BASE,
    ';'
);
-- }}}
-- Apply the limit to the remote products table {{{
SELECT CONCAT(
    'ALTER TABLE `products` AUTO_INCREMENT=',
    @INCREMENT_BASE,
    ';'
);
-- }}}
-- }}}

-- Set the categories_id for some control categories {{{
-- A category to place all new products into until they can be sorted out
SELECT 
    @IMPORT_CATEGORY:=`categories_id`
FROM `categories_description`
WHERE
    `language_id`=1 AND
    `categories_name`='AzureGreen Imports';
-- A category to place products into if a problem is found with the imported data
SELECT 
    @ISSUE_CATEGORY:=`categories_id`
FROM `categories_description`
WHERE
    `language_id`=1 AND
    `categories_name`='AzureGreen Issues';
-- }}}

-- The `manufacturers_id` to be used for AzureGreen products {{{
-- This requires that AzureGreen has been added to the database as a
-- manufacturer. For stores which will only ever carry AzureGreen
-- products this could be set to NULL. It is safer, at very little
-- cost in admin time, to add them to the database anyway.
SET @AZUREGREEN_ID=1;
-- }}}

-- Tables to hold discovered errors in the imported data {{{
-- Table to hold the errors in categories data {{{
CREATE TABLE IF NOT EXISTS `staging_categories_errors` (
    `categories_id`  INT(11) NOT NULL,
    `issue`          VARCHAR(32) NOT NULL DEFAULT '',
    `note_1`         TEXT DEFAULT NULL,
    `note_2`         TEXT DEFAULT NULL,
    PRIMARY KEY (`categories_id`,`issue`),
    KEY `idx_staging_categories_errors` (`categories_id`),
    KEY `idx_staging_categories_issues` (`issue`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;
-- }}}
-- Table to hold the errors {{{
CREATE TABLE IF NOT EXISTS `staging_products_errors` (
    `products_model` VARCHAR(32) NOT NULL DEFAULT '',
    `issue`          VARCHAR(32) NOT NULL DEFAULT '',
    `note_1`         TEXT DEFAULT NULL,
    `note_2`         TEXT DEFAULT NULL,
    PRIMARY KEY (`products_model`,`issue`),
    KEY `idx_staging_products_errors` (`products_model`),
    KEY `idx_staging_products_issues` (`issue`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;
-- }}}
-- Table for collecting the errors in the placement data {{{
CREATE TABLE IF NOT EXISTS `staging_placement_errors` (
    `categories_id`  INT(11) NOT NULL,
    `products_id`    INT(11) NOT NULL,
    `issue`          VARCHAR(32) NOT NULL DEFAULT 'Placement ERROR',
    `products_model` VARCHAR(32) NOT NULL DEFAULT '',
    `note_1`         TEXT DEFAULT NULL,
    `note_2`         TEXT DEFAULT NULL,
    PRIMARY KEY (`categories_id`,`products_id`,`issue`),
    INDEX (`categories_id`,`products_id`),
    INDEX (`categories_id`,`products_model`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;
-- }}}
-- }}}
-- }}}

-- Import category data {{{
--    clone existing data [staging_categories_current]
-- Convenience view for current data {{{
DROP TABLE IF EXISTS `staging_categories_live`;
CREATE TEMPORARY TABLE `staging_categories_live` (
    `categories_id`     INT(11) NOT NULL AUTO_INCREMENT,
    `categories_image`  VARCHAR(255) DEFAULT NULL,
    `parent_id`         INT(11) NOT NULL DEFAULT 0,
    `date_added`        DATETIME DEFAULT NULL,
    `last_modified`     DATETIME DEFAULT NULL,
    `categories_status` TINYINT(1) NOT NULL DEFAULT 1,
    `categories_description` TEXT NOT NULL,
    PRIMARY KEY (`categories_id`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;
INSERT INTO `staging_categories_live` (
    `categories_id`,
    `categories_image`,
    `parent_id`,
    `date_added`,
    `last_modified`,
    `categories_status`,
    `categories_description`
)
SELECT
    `categories_id`,
    `categories_image`,
    `parent_id`,
    `date_added`,
    `last_modified`,
    `categories_status`,
    IFNULL(`categories_description`,'')
FROM `categories`
LEFT OUTER JOIN `categories_description`
    USING (`categories_id`)
WHERE
    `categories`.`categories_id` < @INCREMENT_BASE AND
    (
        `language_id`=1 OR
        `language_id` IS NULL
    )
ORDER BY `parent_id`,`categories_description`;
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
) Engine=MEMORY DEFAULT CHARSET=utf8mb4;
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
    `categories_description`  VARCHAR(255),
    `categories_status`       TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`categories_id`),
    KEY `idx_staging_categories_name_import` (`categories_description`),
    UNIQUE `idx_staging_categories_by_parent_import` (`parent_id`,`categories_description`)
) Engine=MEMORY DEFAULT CHARSET=utf8mb4;
-- }}}
-- Convert the data to Zen-Cart rules {{{
INSERT INTO `staging_categories_import` (
    `categories_id`,
    `parent_id`,
    `categories_description`,
    `categories_status`
) SELECT
    `dept_code`,
    `parent_id`,
    `dept_name`,
    `dept_show`
FROM `staging_categories_ag`
ORDER BY `dept_deep`,`parent_id`,`dept_code`;
-- }}}
--    mark dropped categories as inactive
-- Missing categories become inactive {{{
DROP TABLE IF EXISTS `staging_categories_dropped`;
CREATE TEMPORARY TABLE `staging_categories_dropped` (
    `categories_id` INT(11) NOT NULL
)Engine=MEMORY AS
SELECT
    `staging_categories_live`.`categories_id`
FROM `staging_categories_live`
LEFT OUTER JOIN `staging_categories_import`
    ON `staging_categories_live`.`categories_id`
        = `staging_categories_import`.`categories_id`
WHERE `staging_categories_import`.`categories_id` IS NULL;
-- }}}
--    remove unchanged categories from _import
-- Drop unchanged categories from further processing {{{
DELETE `staging_categories_import`
FROM `staging_categories_import`
JOIN `staging_categories_live`
    ON `staging_categories_import`.`categories_id`
        = `staging_categories_live`.`categories_id`
WHERE
    `staging_categories_import`.`categories_description`
        = `staging_categories_live`.`categories_description` AND
    `staging_categories_import`.`parent_id`
        = `staging_categories_live`.`parent_id` AND
    `staging_categories_import`.`categories_status`
        = `staging_categories_live`.`categories_status`;
-- }}}
--    filter new categories from _import [staging_categories_new]
-- Move new categories to their own table {{{
DROP TABLE IF EXISTS `staging_categories_new`;
CREATE TEMPORARY TABLE `staging_categories_new` (
    `categories_id`           INT(11) NOT NULL,
    `parent_id`               INT(11) NOT NULL,
    `categories_name`         VARCHAR(32),
    `categories_description`  VARCHAR(255),
    `categories_status`       TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`categories_id`),
    KEY `idx_staging_categories_name_new` (`categories_name`),
    UNIQUE `idx_staging_categories_by_parent_new` (`parent_id`,`categories_description`)
) Engine=MEMORY DEFAULT CHARSET=utf8mb4 AS
SELECT
    `staging_categories_import`.`categories_id` AS 'categories_id',
    `staging_categories_import`.`parent_id` AS 'parent_id',
    LEFT(`staging_categories_import`.`categories_description`,32) AS 'categories_name',
    `staging_categories_import`.`categories_description` AS 'categories_description',
    `staging_categories_import`.`categories_status` AS 'categories_status'
FROM `staging_categories_import`
LEFT OUTER JOIN `staging_categories_live`
    ON `staging_categories_import`.`categories_id`
        = `staging_categories_live`.`categories_id`
WHERE `staging_categories_live`.`categories_id` IS NULL;

DELETE `staging_categories_import`
FROM `staging_categories_import`
JOIN `staging_categories_new`
    ON `staging_categories_import`.`categories_id`
        = `staging_categories_new`.`categories_id`;
-- }}}
--    find and update parent category changes
-- Update changes in parent_id {{{
DROP TABLE IF EXISTS `staging_categories_parent`;
CREATE TEMPORARY TABLE `staging_categories_parent` (
    `categories_id` INT(11) NOT NULL,
    `parent_id`     INT(11) NOT NULL,
    PRIMARY KEY (`categories_id`)
)Engine=MEMORY AS
SELECT
    `staging_categories_import`.`categories_id`,
    `staging_categories_import`.`parent_id`
FROM `staging_categories_import`
JOIN `staging_categories_live`
    ON `staging_categories_import`.`categories_id`
        = `staging_categories_live`.`categories_id`
WHERE NOT `staging_categories_import`.`parent_id`
    = `staging_categories_live`.`parent_id`;
-- }}}
--    update category names, unless current name was manually adjusted
-- Update changes in category names {{{
DROP TABLE IF EXISTS `staging_categories_rename`;
CREATE TEMPORARY TABLE `staging_categories_rename` (
    `categories_id`          INT(11) NOT NULL,
    `categories_name`        VARCHAR(32) NOT NULL DEFAULT '',
    `categories_description` VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (`categories_id`)
)Engine=MEMORY DEFAULT CHARSET=utf8mb4 AS
SELECT
    `staging_categories_import`.`categories_id`,
    LEFT(`staging_categories_import`.`categories_description`,32),
    `staging_categories_import`.`categories_description`
FROM `staging_categories_import`
JOIN `staging_categories_live`
    ON `staging_categories_live`.`categories_id`
        = `staging_categories_import`.`categories_id`
WHERE NOT
    `staging_categories_live`.`categories_description`
        = `staging_categories_import`.`categories_description` AND
    `staging_categories_live`.`last_modified` IS NULL;
-- }}}
--    verify status of categories
-- Set status of categories to match the data from AzureGreen {{{
DROP TABLE IF EXISTS `staging_categories_status`;
CREATE TEMPORARY TABLE `staging_categories_status` (
    `categories_id`     INT(11) NOT NULL,
    `categories_status` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`categories_id`)
)Engine=MEMORY AS
SELECT
    `staging_categories_import`.`categories_id`,
    `staging_categories_import`.`categories_status`
FROM `staging_categories_import`
JOIN `staging_categories_live`
    ON `staging_categories_import`.`categories_id`
        = `staging_categories_live`.`categories_id`
WHERE NOT `staging_categories_import`.`categories_status`
    = `staging_categories_live`.`categories_status`;
-- }}}
-- Merge in, and override, the status set because of being dropped by AzureGreen {{{
INSERT INTO `staging_categories_status` (
    `categories_id`,
    `categories_status`
)
SELECT `categories_id`,0
FROM `staging_categories_dropped`
ON DUPLICATE KEY UPDATE `categories_status`=0;
-- }}}
--    collect list of anomolies (name too long, missing parent, active child-inactive parent, etc.) [staging_categories_errors]
-- Record problems encountered in the data {{{
-- Report new categories with the name too long {{{
INSERT INTO `staging_categories_errors` (
    `categories_id`,
    `issue`,
    `note_1`,
    `note_2`
)
SELECT 
    `categories_id`,
    'Name too long',
    `categories_name`,
    `categories_description`
FROM `staging_categories_new`
WHERE NOT `categories_name`=`categories_description`;
-- }}}
-- Report new categories with invalid parent_id values {{{
INSERT INTO `staging_categories_errors` (
    `categories_id`,
    `issue`,
    `note_1`
)
SELECT 
    `categories_id`,
    'Invalid parent_id',
    `parent_id`
FROM `staging_categories_new`
WHERE
    `parent_id` IN (
        SELECT `categories_id` FROM `staging_categories_dropped`
    ) OR
    `parent_id` NOT IN (
        SELECT `categories_id` FROM `staging_categories_new`
        UNION
        SELECT `categories_id` FROM `staging_categories_import`
        UNION
        SELECT 0
    );
-- }}}
-- Report existing categories with now invalid parent_id values {{{
INSERT INTO `staging_categories_errors` (
    `categories_id`,
    `issue`,
    `note_1`
)
SELECT 
    `categories_id`,
    'Invalid parent_id',
    `parent_id`
FROM `staging_categories_live`
WHERE
    `parent_id` IN (
        SELECT `categories_id` FROM `staging_categories_dropped`
    ) OR
    `parent_id` NOT IN (
        SELECT `categories_id` FROM `staging_categories_new`
        UNION
        SELECT `categories_id` FROM `staging_categories_import`
    );
-- }}}
-- Report active categories which have inactive parents {{{
-- New table categories and new table parents {{{
INSERT INTO `staging_categories_errors` (
    `categories_id`,
    `issue`,
    `note_1`
)
SELECT
    `child_table`.`categories_id`,
    'Inactive parent',
    `child_table`.`parent_id`
FROM `staging_categories_new` AS `child_table`
JOIN `staging_categories_new` AS `parent_table`
    ON `child_table`.`parent_id`=`parent_table`.`categories_id`
WHERE 
    `child_table`.`categories_status`=1 AND
    `parent_table`.`categories_status`=0;
-- }}}
-- New table categories and import table parents {{{
INSERT INTO `staging_categories_errors` (
    `categories_id`,
    `issue`,
    `note_1`
)
SELECT
    `child_table`.`categories_id`,
    'Inactive parent',
    `child_table`.`parent_id`
FROM `staging_categories_new` AS `child_table`
JOIN `staging_categories_import` AS `parent_table`
    ON `child_table`.`parent_id`=`parent_table`.`categories_id`
WHERE 
    `child_table`.`categories_status`=1 AND
    `parent_table`.`categories_status`=0;
-- }}}
-- Import table categories and new table parents {{{
INSERT INTO `staging_categories_errors` (
    `categories_id`,
    `issue`,
    `note_1`
)
SELECT
    `child_table`.`categories_id`,
    'Inactive parent',
    `child_table`.`parent_id`
FROM `staging_categories_import` AS `child_table`
JOIN `staging_categories_new` AS `parent_table`
    ON `child_table`.`parent_id`=`parent_table`.`categories_id`
WHERE 
    `child_table`.`categories_status`=1 AND
    `parent_table`.`categories_status`=0;
-- }}}
-- Import table categories and import table parents {{{
INSERT INTO `staging_categories_errors` (
    `categories_id`,
    `issue`,
    `note_1`
)
SELECT
    `child_table`.`categories_id`,
    'Inactive parent',
    `child_table`.`parent_id`
FROM `staging_categories_import` AS `child_table`
JOIN `staging_categories_import` AS `parent_table`
    ON `child_table`.`parent_id`=`parent_table`.`categories_id`
WHERE 
    `child_table`.`categories_status`=1 AND
    `parent_table`.`categories_status`=0;
-- }}}
-- }}}
-- }}}za
-- Apply collected changes to categories tables {{{
--    insert new categories into database
-- Add new categories to the database {{{
-- Add to the categories table {{{
-- Generate the script to update the remote table {{{
SELECT
    CONCAT(
        ' INSERT IGNORE INTO `categories`',
        ' SET ',
        CONCAT_WS(',',
            CONCAT('`categories_id`=',`categories_id`),
            CONCAT('`parent_id`=',`parent_id`),
            CONCAT('`date_added`=',"'",@SCRIPT_ADD_DATE,"'")
        ),
        ';'
    )
FROM `staging_categories_new`;
-- }}}
-- Update the local copy {{{
INSERT IGNORE INTO `categories` (
    `categories_id`,
    `parent_id`,
    `date_added`
)
SELECT
    `categories_id`,
    `parent_id`,
    @SCRIPT_ADD_DATE
FROM `staging_categories_new`;
-- }}}
-- }}}
-- Add to the categories_description table {{{
-- Generate the script to update the remote table {{{
SELECT
    CONCAT(
        'INSERT IGNORE INTO `categories_description`',
        ' SET ',
        CONCAT_WS(',',
            CONCAT('`categories_id`=',`categories_id`),
            CONCAT('`categories_name`="',`categories_name`,'"'),
            CONCAT('`categories_description`="',`categories_description`,'"')
        ),
        ';'
    )
FROM `staging_categories_new`;
-- }}}
-- Update the local copy {{{
INSERT IGNORE INTO `categories_description` (
    `categories_id`,
    `categories_name`,
    `categories_description`
)
SELECT
    `categories_id`,
    `categories_name`,
    `categories_description`
FROM `staging_categories_new`;
-- }}}
-- }}}
-- Add to the meta_tags_categories_description table {{{
-- Generate the script to update the remote table {{{
SELECT
    CONCAT(
        'INSERT IGNORE INTO `meta_tags_categories_description`',
        ' SET ',
        CONCAT_WS(',',
            CONCAT('`categories_id`=',`categories_id`),
            CONCAT('`metatags_title`="',LEFT(`categories_description`,64),'"'),
            CONCAT('`metatags_keywords`="',`categories_description`,'"'),
            CONCAT('`metatags_description`="',`categories_description`,'"')
        ),
        ';'
    )
FROM `staging_categories_new`;
-- }}}
-- Update the local copy {{{
INSERT IGNORE INTO `meta_tags_categories_description` (
    `categories_id`,
    `metatags_title`,
    `metatags_keywords`,
    `metatags_description`
)
SELECT
    `categories_id`,
    LEFT(`categories_description`,64),
    `categories_description`,
    `categories_description`
FROM `staging_categories_new`;
-- }}}
-- }}}
-- }}}
-- Update parent categories {{{
-- Generate the script to update the remote table {{{
SELECT
    CONCAT(
        'UPDATE `categories`',
        ' SET ',
        CONCAT('`parent_id`=',`parent_id`),
        ' WHERE `categories_id`=',`categories_id`,
        ' LIMIT 1;'
    )
FROM `staging_categories_parent`;
-- }}}
-- Update the local copy {{{
UPDATE `categories`
JOIN `staging_categories_parent`
    ON `staging_categories_parent`.`categories_id`
        = `categories`.`categories_id`
SET `categories`.`parent_id`=`staging_categories_parent`.`parent_id`;
-- }}}
-- }}}
-- Update renamed categories {{{
-- Apply name changes to the description table {{{
-- Generate the script to update the remote table {{{
SELECT
    CONCAT(
        'UPDATE `categories_description`',
        ' SET ',
        CONCAT_WS(',',
            CONCAT('`categories_name`="',`categories_name`,'"'),
            CONCAT('`categories_description`="',`categories_description`,'"')
        ),
        ' WHERE `categories_id`=',`categories_id`,
        ' AND `language_id`=1',
        ' LIMIT 1;'
    )
FROM `staging_categories_rename`;
-- }}}
-- Update the local copy {{{
UPDATE `categories_description`
JOIN `staging_categories_rename`
    ON `categories_description`.`categories_id`
        = `staging_categories_rename`.`categories_id`
SET
    `categories_description`.`categories_name`
        = `staging_categories_rename`.`categories_name`,
    `categories_description`.`categories_description`
        = `staging_categories_rename`.`categories_description`
WHERE `categories_description`.`language_id`=1;
-- }}}
-- }}}
-- Apply name changes to the meta_tags table {{{
-- Generate the script to update the remote table {{{
SELECT
    CONCAT(
        'UPDATE `meta_tags_categories_description`',
        ' SET ',
        CONCAT_WS(',',
            CONCAT('`metatags_title`="',LEFT(`categories_description`,64),'"'),
            CONCAT('`metatags_keywords`="',`categories_description`,'"'),
            CONCAT('`metatags_descriptionn`="',`categories_description`,'"')
        ),
        ' WHERE `language_id`=1',
        ' LIMIT 1;'
    )
FROM `staging_categories_rename`;
-- }}}
-- Update the local copy {{{
UPDATE `meta_tags_categories_description`
JOIN `staging_categories_rename`
    ON `meta_tags_categories_description`.`categories_id`
        = `staging_categories_rename`.`categories_id`
SET
    `meta_tags_categories_description`.`metatags_title`
        = LEFT(`staging_categories_rename`.`categories_description`,64),
    `meta_tags_categories_description`.`metatags_keywords`
        = `staging_categories_rename`.`categories_description`,
    `meta_tags_categories_description`.`metatags_description`
        = `staging_categories_rename`.`categories_description`
WHERE `language_id`=1;
-- }}}
-- }}}
-- }}}
-- Update category status values {{{
-- Generate the script to update the remote table {{{
SELECT
    CONCAT(
        'UPDATE `categories`',
        ' SET ',
        CONCAT_WS(',',
            CONCAT('`categories_status`=',`staging_categories_status`.`categories_status`)
        ),
        ' WHERE `categories_id`=',`staging_categories_status`.`categories_id`,
        ' LIMIT 1;'
    )
FROM `categories`
JOIN `staging_categories_status`
    ON `staging_categories_status`.`categories_id`
        = `categories`.`categories_id`
WHERE NOT `categories`.`categories_status`
    = `staging_categories_status`.`categories_status`;
-- }}}
-- Update the local copy {{{
UPDATE `categories`
JOIN `staging_categories_status`
    ON `staging_categories_status`.`categories_id`
        = `categories`.`categories_id`
SET `categories`.`categories_status`
    = `staging_categories_status`.`categories_status`
WHERE NOT `categories`.`categories_status`
    = `staging_categories_status`.`categories_status`;
-- }}}
-- }}}
--    force inactive status for unwanted categories
-- Make choosen categories inactive, regardless of AzureGreen's data {{{
-- Generate the script to update the remote table {{{
SELECT
    CONCAT(
        'UPDATE `categories`',
        ' SET ',
        CONCAT('`categories_status`=',0),
        ' WHERE `categories_id` IN (29,33,250,278,524,421,6,14,124,396);'
    );
-- }}}
-- Update the local copy {{{
UPDATE `categories`
SET `categories_status`=0
WHERE `categories_id` IN (29,33,250,278,524,421,6,14,124,396);
-- }}}
-- }}}
-- }}}
-- }}}za

-- Import product data {{{
--    clone existing data [staging_products_current]
-- Convenience view for current data {{{
-- CREATE OR REPLACE VIEW `staging_products_live` AS
DROP TABLE IF EXISTS `staging_products_live`;
CREATE TEMPORARY TABLE `staging_products_live` (
    `products_id`             INT(11) NOT NULL,
    `products_model`          VARCHAR(32) DEFAULT NULL,
    `products_image`          VARCHAR(255) DEFAULT NULL,
    `products_price`          DECIMAL (15,4) NOT NULL DEFAULT 0.0000,
    `products_quantity`       FLOAT NOT NULL DEFAULT 0,
    `products_date_added`     DATETIME NOT NULL DEFAULT '0001-01-01 00:00:00',
    `products_last_modified`  DATETIME DEFAULT NULL,
    `products_date_available` DATETIME DEFAULT NULL,
    `products_weight`         FLOAT NOT NULL DEFAULT 0,
    `products_status`         TINYINT(1) NOT NULL DEFAULT 1,
    `master_categories_id`    INT(11) NOT NULL DEFAULT 0,
    `products_name`           VARCHAR(255) NOT NULL DEFAULT '',
    `products_description`    TEXT DEFAULT NULL,
    UNIQUE (`products_model`),
    UNIQUE (`products_id`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;
INSERT IGNORE INTO `staging_products_live` (
    `products_id`,
    `products_model`,
    `products_image`,
    `products_price`,
    `products_quantity`,
    `products_date_added`,
    `products_last_modified`,
    `products_date_available`,
    `products_weight`,
    `products_status`,
    `master_categories_id`,
    `products_name`,
    `products_description`
)
SELECT
    `products_id`,
    `products_model`,
    `products_image`,
    `products_price`,
    `products_quantity`,
    `products_date_added`,
    `products_last_modified`,
    `products_date_available`,
    `products_weight`,
    `products_status`,
    `master_categories_id`,
    IFNULL(`products_name`,''),
    IFNULL(`products_description`,'')
FROM `products`
LEFT OUTER JOIN `products_description`
    USING (`products_id`)
WHERE
    `products`.`products_id` < @INCREMENT_BASE AND
    (
        `language_id`=1 OR
        `language_id` IS NULL
    ); 
-- }}}
-- A table to generate ID values below the INCREMENT_BASE {{{
DROP TABLE IF EXISTS `staging_products_id`;
CREATE TEMPORARY TABLE `staging_products_id` (
    `products_id`    INT(11) NOT NULL AUTO_INCREMENT,
    `products_model` VARCHAR(32) NOT NULL DEFAULT '',
    PRIMARY KEY (`products_id`),
    UNIQUE (`products_model`)
)Engine=MEMORY DEFAULT CHARSET=utf8mb4 AS
SELECT
    `products_id`,
    `products_model`
FROM `staging_products_live`;
-- }}}
--    read raw data from CSV file [staging_products_complete_ag {db_import-ag_complete_files.csv},
-- Read the raw CSV files of product data into tables {{{
-- Table for the raw CSV data in the ag_complete_files file {{{
DROP TABLE IF EXISTS `staging_products_complete_ag`;
CREATE TEMPORARY TABLE `staging_products_complete_ag` (
    `prod_code`  VARCHAR(32) NOT NULL DEFAULT '',
    `prod_desc`  VARCHAR(255) NOT NULL DEFAULT '',
    `narrative`  TEXT DEFAULT NULL,
    `units_qty`  FLOAT NOT NULL DEFAULT 0,
    `weight`     FLOAT NOT NULL DEFAULT 0,
    `price`      DECIMAL(15,4) NOT NULL DEFAULT 0.0000,
    `del_date`   VARCHAR(20),
    `discont`    TINYINT(1) NOT NULL DEFAULT 0,
    `prod_image` VARCHAR(255) DEFAULT NULL,
    `cantsell`   TINYINT(1) NOT NULL DEFAULT 0,
    INDEX (`prod_code`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;
-- }}}
-- Read the ag_complete_files.csv file {{{
LOAD DATA LOCAL
    INFILE 'db_import-ag_complete_files.csv'
INTO TABLE `staging_products_complete_ag`
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES;
-- }}}
--                                 staging_products_stockinfo_ag {db_import-stockinfo.csv},
-- Table for the raw CSV data in the stockinfo file {{{
DROP TABLE IF EXISTS `staging_products_stockinfo_ag`;
CREATE TEMPORARY TABLE `staging_products_stockinfo_ag` (
    `prod_code`  VARCHAR(32) NOT NULL DEFAULT '',
    `prod_desc`  VARCHAR(255) NOT NULL DEFAULT '',
    `units_qty`  FLOAT NOT NULL DEFAULT 0,
    `weight`     FLOAT NOT NULL DEFAULT 0,
    `price`      DECIMAL(15,4) NOT NULL DEFAULT 0.0000,
    `del_date`   VARCHAR(20),
    `discont`    TINYINT(1) NOT NULL DEFAULT 0,
    `prod_image` VARCHAR(255) DEFAULT NULL,
    `cantsell`   TINYINT(1) NOT NULL DEFAULT 0,
    INDEX (`prod_code`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;
-- }}}
-- Read the stockinfo.csv file {{{
LOAD DATA LOCAL
    INFILE 'db_import-stockinfo.csv'
INTO TABLE `staging_products_stockinfo_ag`
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES;
-- }}}
--                                 staging_products_description_ag {db_import-descriptions.csv}]
-- Table for the raw CSV data in the descriptions file {{{
DROP TABLE IF EXISTS `staging_products_description_ag`;
CREATE TEMPORARY TABLE `staging_products_description_ag` (
    `prod_code`  VARCHAR(32) NOT NULL DEFAULT '',
    `narrative`  TEXT DEFAULT NULL,
    INDEX (`prod_code`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;
-- }}}
-- Read the descriptions.csv file {{{
LOAD DATA LOCAL
    INFILE 'db_import-descriptions.csv'
INTO TABLE `staging_products_description_ag`
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES;
-- }}}
-- }}}
--    convert data to Zen-Cart standards [staging_products_import]
-- Table for applying the Zen-Cart rules to the products data {{{
DROP TABLE IF EXISTS `staging_products_import`;
CREATE TEMPORARY TABLE `staging_products_import` (
    `products_id`             INT(11) DEFAULT NULL,
    `products_model`          VARCHAR(32) DEFAULT NULL,
    `products_image`          VARCHAR(255) DEFAULT NULL,
    `products_price`          DECIMAL(15,4) NOT NULL DEFAULT 0.0000,
    `products_quantity`       FLOAT NOT NULL DEFAULT 0,
    `products_date_added`     DATETIME NOT NULL DEFAULT '2019-10-31 03:13:21',
    `products_last_modified`  DATETIME DEFAULT NULL,
    `products_weight`         FLOAT NOT NULL DEFAULT 0,
    `products_status`         TINYINT(1) NOT NULL DEFAULT 0,
    `master_categories_id`    INT(11) NOT NULL DEFAULT 0,
    `products_name`           VARCHAR(64) NOT NULL DEFAULT '',
    `products_title`          VARCHAR(255) NOT NULL DEFAULT '',
    `products_description`    TEXT DEFAULT NULL,
    PRIMARY KEY (`products_model`),
    UNIQUE `idx_staging_products_id_import` (`products_id`),
    KEY `idx_staging_products_name_import` (`products_name`),
    KEY `idx_staging_products_status_import` (`products_status`),
    KEY `idx_staging_products_date_added_import` (`products_date_added`),
    KEY `idx_staging_master_categories_id_import` (`master_categories_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4;
-- }}}
-- Convert the products data to Zen-Cart rules {{{
-- Process the complete listing first {{{
INSERT INTO `staging_products_import` (
    `products_model`,
    `products_image`,
    `products_price`,
    `products_quantity`,
    `products_date_added`,
    `products_last_modified`,
    `products_weight`,
    `products_status`,
    `master_categories_id`,
    `products_name`,
    `products_title`,
    `products_description`
)
SELECT 
    `prod_code`,
    LCASE(CONCAT(
        LEFT(`prod_image`,2),
        '/',
        `prod_image`
    )),
    `price`,
    `units_qty`,
    @SCRIPT_ADD_DATE,
    NULL,
    `weight`,
    IF(`cantsell`=1,0,1),
    5000,
    LEFT(`prod_desc`,64),
    `prod_code`,
    `narrative`
FROM `staging_products_complete_ag`;
-- }}}
-- Process the stockinfo file second, adding any not in the table so far {{{
INSERT INTO `staging_products_import` (
    `products_model`,
    `products_image`,
    `products_price`,
    `products_quantity`,
    `products_date_added`,
    `products_last_modified`,
    `products_weight`,
    `products_status`,
    `master_categories_id`,
    `products_name`,
    `products_title`
)
SELECT 
    `staging_products_stockinfo_ag`.`prod_code`,
    LCASE(CONCAT(
        LEFT(`staging_products_stockinfo_ag`.`prod_image`,2),
        '/',
        `staging_products_stockinfo_ag`.`prod_image`
    )),
    `staging_products_stockinfo_ag`.`price`,
    `staging_products_stockinfo_ag`.`units_qty`,
    @SCRIPT_ADD_DATE,
    NULL,
    `staging_products_stockinfo_ag`.`weight`,
    IF(`staging_products_stockinfo_ag`.`cantsell`=1,0,1),
    5000,
    LEFT(`staging_products_stockinfo_ag`.`prod_desc`,64),
    `staging_products_stockinfo_ag`.`prod_desc`
FROM `staging_products_stockinfo_ag`
LEFT OUTER JOIN `staging_products_complete_ag`
    ON `staging_products_stockinfo_ag`.`prod_code`
        = `staging_products_complete_ag`.`prod_code`
WHERE `staging_products_complete_ag`.`prod_code` IS NULL;
-- }}}
-- Process the stockinfo file, updating anything already there {{{
UPDATE `staging_products_import`
JOIN `staging_products_stockinfo_ag`
    ON `staging_products_stockinfo_ag`.`prod_code`
        = `staging_products_import`.`products_model`
SET
    `staging_products_import`.`products_model`
        = `staging_products_stockinfo_ag`.`prod_code`,
    `staging_products_import`.`products_image`
        = LCASE(CONCAT(
            LEFT(`staging_products_stockinfo_ag`.`prod_image`,2),
            '/',
            `staging_products_stockinfo_ag`.`prod_image`
        )),
    `staging_products_import`.`products_price`
        = `staging_products_stockinfo_ag`.`price`,
    `staging_products_import`.`products_quantity`
        = `staging_products_stockinfo_ag`.`units_qty`,
    `staging_products_import`.`products_date_added`=@SCRIPT_ADD_DATE,
    `staging_products_import`.`products_last_modified`=NULL,
    `staging_products_import`.`products_weight`
        = `staging_products_stockinfo_ag`.`weight`,
    `staging_products_import`.`products_status`
        = IF(`staging_products_stockinfo_ag`.`cantsell`=1,0,1),
    `staging_products_import`.`master_categories_id`=5000,
    `staging_products_import`.`products_name`
        = LEFT(`staging_products_stockinfo_ag`.`prod_desc`,64),
    `staging_products_import`.`products_title`=`prod_desc`;
-- }}}
-- Process the descriptions file, with minimal data available adding any not in the table so far {{{
INSERT INTO `staging_products_import` (
    `products_model`,
    `products_description`
)
SELECT 
    `staging_products_description_ag`.`prod_code`,
    `staging_products_description_ag`.`narrative`
FROM `staging_products_description_ag`
LEFT OUTER JOIN `staging_products_complete_ag`
    ON `staging_products_description_ag`.`prod_code`
        = `staging_products_complete_ag`.`prod_code`
WHERE `staging_products_complete_ag`.`prod_code` IS NULL;
-- }}}
-- Process the descriptions file, with minimal data available, updating anything already there {{{
UPDATE `staging_products_import`
JOIN `staging_products_description_ag`
    ON `staging_products_import`.`products_model`
        = `staging_products_description_ag`.`prod_code`
SET
    `staging_products_import`.`products_description`
        = `staging_products_description_ag`.`narrative`;
-- }}}
-- }}}
--    filter new products from _import [staging_products_new]
-- Move new products to their own table {{{
DROP TABLE IF EXISTS `staging_products_new`;
CREATE TEMPORARY TABLE `staging_products_new` (
    `products_id`             INT(11) DEFAULT NULL,
    `products_model`          VARCHAR(32) DEFAULT NULL,
    `products_image`          VARCHAR(255) DEFAULT NULL,
    `products_price`          DECIMAL(15,4) NOT NULL DEFAULT 0.0000,
    `products_quantity`       FLOAT NOT NULL DEFAULT 0,
    `products_date_added`     DATETIME NOT NULL DEFAULT '2019-10-31 03:13:21',
    `products_last_modified`  DATETIME DEFAULT NULL,
    `products_weight`         FLOAT NOT NULL DEFAULT 0,
    `products_status`         TINYINT(1) NOT NULL DEFAULT 0,
    `master_categories_id`    INT(11) NOT NULL DEFAULT 0,
    `products_name`           VARCHAR(64) NOT NULL DEFAULT '',
    `products_title`          VARCHAR(255) NOT NULL DEFAULT '',
    `products_description`    TEXT DEFAULT NULL,
    PRIMARY KEY (`products_model`),
    UNIQUE `idx_staging_products_id_import` (`products_id`),
    KEY `idx_staging_products_name_import` (`products_name`),
    KEY `idx_staging_products_status_import` (`products_status`),
    KEY `idx_staging_products_date_added_import` (`products_date_added`),
    KEY `idx_staging_master_categories_id_import` (`master_categories_id`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4 AS
SELECT
    `staging_products_import`.`products_id`,
    `staging_products_import`.`products_model`,
    `staging_products_import`.`products_image`,
    `staging_products_import`.`products_price`,
    `staging_products_import`.`products_quantity`,
    `staging_products_import`.`products_date_added`,
    `staging_products_import`.`products_last_modified`,
    `staging_products_import`.`products_weight`,
    `staging_products_import`.`products_status`,
    `staging_products_import`.`master_categories_id`,
    `staging_products_import`.`products_name`,
    `staging_products_import`.`products_title`,
    `staging_products_import`.`products_description`
FROM `staging_products_import`
LEFT OUTER JOIN `staging_products_live`
    ON `staging_products_import`.`products_model`
        = `staging_products_live`.`products_model`
WHERE `staging_products_live`.`products_model` IS NULL;

DELETE `staging_products_import`
FROM `staging_products_import`
JOIN `staging_products_new`
    ON `staging_products_import`.`products_model`
        = `staging_products_new`.`products_model`;
-- }}}
-- Add the products_id for existing products from the database {{{
UPDATE `staging_products_import`
JOIN `staging_products_live`
    ON `staging_products_import`.`products_model`
        = `staging_products_live`.`products_model`
SET `staging_products_import`.`products_id`
    = `staging_products_live`.`products_id`;
-- }}}
--    mark dropped products as inactive
-- Missing products become inactive {{{
DROP TABLE IF EXISTS `staging_products_dropped`;
CREATE TEMPORARY TABLE `staging_products_dropped` (
    `products_id`  INT(11) NOT NULL
)Engine=MEMORY AS
SELECT
    `staging_products_live`.`products_id`
FROM `staging_products_live`
LEFT OUTER JOIN `staging_products_import`
    ON `staging_products_live`.`products_model`
        = `staging_products_import`.`products_model`
WHERE
    `staging_products_import`.`products_model` IS NULL AND
    `staging_products_live`.`products_status`=1;
-- }}}
--    update quantity, weight and price, where available, from import data
-- Table for the vital statistics for products {{{
DROP TABLE IF EXISTS `staging_products_vitals`;
CREATE TEMPORARY TABLE `staging_products_vitals` (
    `products_id`           INT(11) DEFAULT NULL,
    `products_model`        VARCHAR(32) NOT NULL DEFAULT '',
    `products_quantity`     FLOAT DEFAULT NULL,
    `products_weight`       FLOAT DEFAULT NULL,
    `products_price`        DECIMAL(15,4) DEFAULT NULL
)Engine=MEMORY DEFAULT CHARSET=utf8mb4 AS
SELECT
    `staging_products_import`.`products_id`,
    `staging_products_import`.`products_model`,
    NULLIF(
        `staging_products_import`.`products_quantity`,
        `staging_products_live`.`products_quantity`
    ) AS 'products_quantity',
    NULLIF(
        `staging_products_import`.`products_weight`,
        `staging_products_live`.`products_weight`
    ) AS 'products_weight',
    NULLIF(
        `staging_products_import`.`products_price`,
        `staging_products_live`.`products_price`
    ) AS 'products_price'
FROM `staging_products_import`
JOIN `staging_products_live`
    ON `staging_products_import`.`products_id`
        = `staging_products_live`.`products_id`
WHERE 
    NOT `staging_products_import`.`products_price`
        = `staging_products_live`.`products_price` OR
    NOT `staging_products_import`.`products_weight`
        = `staging_products_live`.`products_weight` OR
    NOT `staging_products_import`.`products_quantity`
        = `staging_products_live`.`products_quantity`;
-- }}}
--    update product status based on import status or quantity
-- Set product status inactive {{{
DROP TABLE IF EXISTS `staging_products_inactive`;
CREATE TEMPORARY TABLE `staging_products_inactive` (
    `products_id` INT(11) NOT NULL
)Engine=MEMORY;
INSERT IGNORE INTO `staging_products_inactive` (
    `products_id`
)
SELECT
    `staging_products_import`.`products_id`
FROM `staging_products_import`
JOIN `staging_products_live`
    ON `staging_products_import`.`products_id`
        = `staging_products_live`.`products_id`
WHERE
    `staging_products_live`.`products_status`=1 AND
    (
        `staging_products_import`.`products_status`=0 OR
        NOT `staging_products_import`.`products_quantity` > 0
    );
-- Add in products which were dropped by AzureGreen
INSERT IGNORE INTO `staging_products_inactive` (
    `products_id`
)
SELECT
    `products_id`
FROM `staging_products_dropped`;
-- }}}
-- Set product status active {{{
DROP TABLE IF EXISTS `staging_products_active`;
CREATE TEMPORARY TABLE `staging_products_active` (
    `products_id` INT(11) NOT NULL
)Engine=MEMORY;
INSERT INTO `staging_products_active` (
    `products_id`
)
SELECT
    `staging_products_import`.`products_id`
FROM `staging_products_import`
JOIN `staging_products_live`
    ON `staging_products_import`.`products_id`
        = `staging_products_live`.`products_id`
WHERE
    `staging_products_live`.`products_status`=0 AND
    (
        `staging_products_import`.`products_status`=1 AND
        `staging_products_import`.`products_quantity` > 0
    );
-- }}}
--    remove unchanged products from _import, ignoring changes in qty, price and weight
-- Drop unchanged products from further processing {{{
DELETE `staging_products_import`
FROM `staging_products_import`
JOIN `staging_products_live`
    ON `staging_products_import`.`products_model`
        = `staging_products_live`.`products_model`
WHERE
    `staging_products_import`.`products_name`=`staging_products_live`.`products_name` AND
    `staging_products_import`.`products_description`=`staging_products_live`.`products_description`;
-- }}}
--    update product name and description where different, unless manually changed in database
-- Find name changes for products {{{
DROP TABLE IF EXISTS `staging_products_info`;
CREATE TEMPORARY TABLE `staging_products_info` (
    `products_id`        INT(11) NOT NULL,
    `products_label`     VARCHAR(64) DEFAULT NULL,
    `products_title`     VARCHAR(255) DEFAULT NULL,
    `products_narrative` TEXT DEFAULT NULL,
    PRIMARY KEY (`products_id`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4 AS
SELECT
    `products_id`,
    `staging_products_import`.`products_name` AS 'products_label',
    `staging_products_import`.`products_title` AS 'products_title'
FROM `staging_products_import`
JOIN `staging_products_live`
    USING (`products_id`)
WHERE
    `staging_products_live`.`products_last_modified` IS NULL AND
    NOT `staging_products_import`.`products_name`
        = `staging_products_live`.`products_name`;
-- }}}
-- Find description changes for products {{{
INSERT INTO `staging_products_info` (
    `products_id`,
    `products_narrative`
)
SELECT
    `products_id`,
    `staging_products_import`.`products_description` AS 'products_narrative'
FROM `staging_products_import`
JOIN `staging_products_live`
    USING (`products_id`)
WHERE
    `staging_products_live`.`products_last_modified` IS NULL AND
    NOT `staging_products_import`.`products_description`
        = `staging_products_live`.`products_description`
ON DUPLICATE KEY UPDATE
    `products_narrative`
        = `staging_products_import`.`products_description`;
-- }}}
--    collect anomolies (name/desc too long, missing data, etc.) [staging_products_errors]
-- Record problems found in the new data for products {{{
-- Report new products with name too long {{{
INSERT INTO `staging_products_errors` (
    `products_model`,
    `issue`,
    `note_1`,
    `note_2`
)
SELECT
    `products_model`,
    'Name too long',
    `products_name`,
    `products_title`
FROM `staging_products_import`
WHERE NOT `products_name`=`products_title`;
-- }}}
-- Report new products with missing desciptions {{{
INSERT INTO `staging_products_errors` (
    `products_model`,
    `issue`
)
SELECT
    `products_model`,
    'Missing Description'
FROM `staging_products_import`
WHERE
    `products_description` IS NULL OR
    `products_description`='';
-- }}}
-- Report new products with missing names {{{
INSERT INTO `staging_products_errors` (
    `products_model`,
    `issue`
)
SELECT
    `products_model`,
    'Missing Name'
FROM `staging_products_import`
WHERE
    `products_name` IS NULL OR
    `products_name`='';
-- }}}
-- }}}
--    insert new products information into the database
-- Apply changes from the information files {{{
-- Update the status of existing products {{{
-- Generate the script for the remote database {{{
SELECT
    IFNULL(CONCAT(
        'UPDATE `products`',
        ' SET ',
        '`products_status`=1',
        ' WHERE `products_id` IN (',
        GROUP_CONCAT(`products_id`),
        ');'
    ),'')
FROM `staging_products_active`;
SELECT
    IFNULL(CONCAT(
        'UPDATE `products`',
        ' SET ',
        '`products_status`=0',
        ' WHERE `products_id` IN (',
        GROUP_CONCAT(`products_id`),
        ');'
    ),'')
FROM `staging_products_inactive`;
-- }}}
-- Update the local tables {{{
UPDATE `products`
JOIN `staging_products_active`
    ON `staging_products_active`.`products_id`
        = `products`.`products_id`
SET `products_status`=1;
UPDATE `products`
JOIN `staging_products_inactive`
    ON `staging_products_inactive`.`products_id`
        = `products`.`products_id`
SET `products_status`=0;
-- }}}
-- }}}
-- Update names and descriptions of existing products {{{
-- Update the products_description table {{{
-- Generate the script for the remote database {{{
SELECT
    CONCAT(
        'UPDATE `products_description`',
        ' SET ',
        CONCAT_WS(',',
            CONCAT('`products_name`="',`products_label`,'"'),
            CONCAT('`products_description`="',`products_narrative`,'"')
        ),
        ' WHERE `products_id`=',`products_id`,
        ' LIMIT 1;'
    )
FROM `staging_products_info`;
-- }}}
-- Update the local table {{{
UPDATE `products_description`
JOIN `staging_products_info`
    ON `staging_products_info`.`products_id`
        = `products_description`.`products_id`
SET 
    `products_description`.`products_name`=IFNULL(
        `staging_products_info`.`products_label`,
        `products_description`.`products_name`
    ),
    `products_description`.`products_description`=IFNULL(
        `staging_products_info`.`products_narrative`,
        `products_description`.`products_description`
    );
-- }}}
-- }}}
-- Update the meta_tags table {{{
-- Generate the script for the remote database {{{
SELECT
    CONCAT(
        'UPDATE `meta_tags_products_description`',
        ' SET ',
        CONCAT_WS(',',
            CONCAT('`metatags_title`="',`products_title`,'"'),
            CONCAT('`metatags_keywords`="',`products_narrative`,'"'),
            CONCAT('`metatags_description`="',`products_narrative`,'"')
        ),
        ' WHERE `products_id`=',`products_id`,
        ' LIMIT 1;'
    )
FROM `staging_products_info`;
-- }}}
-- Update the local table {{{
UPDATE `meta_tags_products_description`
JOIN `staging_products_info`
    ON `staging_products_info`.`products_id`
        = `meta_tags_products_description`.`products_id`
SET
    `meta_tags_products_description`.`metatags_title`=IFNULL(
        `staging_products_info`.`products_title`,
        `meta_tags_products_description`.`metatags_title`
    ),
    `meta_tags_products_description`.`metatags_keywords`=IFNULL(
        `staging_products_info`.`products_narrative`,
        `meta_tags_products_description`.`metatags_keywords`
    ),
    `meta_tags_products_description`.`metatags_description`=IFNULL(
        `staging_products_info`.`products_narrative`,
        `meta_tags_products_description`.`metatags_description`
    );
-- }}}
-- }}}
-- }}}
-- Update the vital stats for existing products {{{
-- Generate the script for the remote database {{{
SELECT
    CONCAT(
        'UPDATE `products`',
        ' SET ',
        CONCAT_WS(',',
            CONCAT(
                '`products_quantity`=',
                IFNULL(`products_quantity`,NULL)
            ),
            CONCAT(
                '`products_weight`=',
                IFNULL(`products_weight`,NULL)
            ),
            CONCAT(
                '`products_price`=',
                IFNULL(`products_price`,NULL)
            ),
            CONCAT(
                '`products_price_sorter`=',
                IFNULL(`products_price`,NULL)
            )
        ),
        ' WHERE `products_id`=',`products_id`,
        ' LIMIT 1;'
    )
FROM `staging_products_vitals`;
-- }}}
-- Update the local tables {{{
UPDATE `products`
JOIN `staging_products_vitals`
    ON `staging_products_vitals`.`products_id`
        = `products`.`products_id`
JOIN `staging_products_live`
    ON `staging_products_live`.`products_id`
        = `products`.`products_id`
SET
    `products`.`products_quantity`
        = IFNULL(
            `staging_products_vitals`.`products_quantity`,
            `staging_products_live`.`products_quantity`
        ),
    `products`.`products_weight`
        = IFNULL(
            `staging_products_vitals`.`products_weight`,
            `staging_products_live`.`products_weight`
        ),
    `products`.`products_price`
        = IFNULL(
            `staging_products_vitals`.`products_price`,
            `staging_products_live`.`products_price`
        ),
    `products`.`products_price_sorter`
        = IFNULL(
            `staging_products_vitals`.`products_price`,
            `staging_products_live`.`products_price`
        );
-- }}}
-- }}}
-- Insert the new products into the database {{{
-- Get new ID numbers with the specialized table {{{
-- Insert product into the table {{{
INSERT INTO `staging_products_id` (
    `products_model`
)
SELECT
    `products_model`
FROM `staging_products_new`;
-- }}}
-- Add the new ID numbers to the working table {{{
-- Set master_categories_id to the temporary import-sorting category
UPDATE `staging_products_new`
JOIN `staging_products_id`
    ON `staging_products_new`.`products_model`
        = `staging_products_id`.`products_model`
SET
    `staging_products_new`.`products_id`
        = `staging_products_id`.`products_id`,
    `staging_products_new`.`master_categories_id`
        = @IMPORT_CATEGORY;
-- }}}
-- }}}
-- Add products to the products table {{{
-- Generate the script for the remote database {{{
SELECT
    CONCAT(
        'INSERT IGNORE INTO `products`'
        ' SET ',
        CONCAT_WS(',',
            CONCAT('`products_id`=',`products_id`),
            CONCAT('`products_quantity`=',`products_quantity`),
            CONCAT('`products_model`="',`products_model`,'"'),
            CONCAT('`products_image`="',`products_image`,'"'),
            CONCAT('`products_price`=',`products_price`),
            CONCAT('`products_date_added`="',`products_date_added`,'"'),
            CONCAT('`products_date_available`="',@SCRIPT_NEW_DATE,'"'),
            CONCAT('`products_weight`=',`products_weight`),
            CONCAT('`products_status`=',`products_status`),
            CONCAT('`manufacturers_id`=',@AZUREGREEN_ID),
            CONCAT('`products_price_sorter`=',`products_weight`),
            CONCAT('`master_categories_id`=',`master_categories_id`)
        ),
        ';'
    )
FROM `staging_products_new`;
-- }}}
-- Update the local tables {{{
INSERT IGNORE INTO `products` (
    `products_id`,
    `products_quantity`,
    `products_model`,
    `products_image`,
    `products_price`,
    `products_date_added`,
    `products_date_available`,
    `products_weight`,
    `products_status`,
    `manufacturers_id`,
    `products_price_sorter`,
    `master_categories_id`
)
SELECT
    `products_id`,
    `products_quantity`,
    `products_model`,
    `products_image`,
    `products_price`,
    `products_date_added`,
    @SCRIPT_NEW_DATE,
    `products_weight`,
    `products_status`,
    @AZUREGREEN_ID,
    `products_price`,
    `master_categories_id`
FROM `staging_products_new`;
-- }}}
-- }}}
-- Add products to the products_description table {{{
-- Generate the script for the remote database {{{
SELECT
    CONCAT(
        'INSERT IGNORE INTO `products_description`',
        ' SET ',
        CONCAT_WS(',',
            CONCAT('`products_id`=',`products_id`),
            '`language_id`=1',
            CONCAT('`products_name`="',`products_name`,'"'),
            CONCAT('`products_description`="',`products_description`,'"')
        ),
        ";"
    )
FROM `staging_products_new`;
-- }}}
-- Update the local tables {{{
INSERT IGNORE INTO `products_description` (
    `products_id`,
    `language_id`,
    `products_name`,
    `products_description`
)
SELECT
    `products_id`,
    1,
    `products_name`,
    `products_description`
FROM `staging_products_new`;
-- }}}
-- }}}
-- Add products to the meta tags table {{{
-- Generate the script for the remote database {{{
SELECT
    CONCAT(
        'INSERT IGNORE INTO `meta_tags_products_description`',
        ' SET ',
        CONCAT_WS(',',
            CONCAT('`products_id`=',`products_id`),
            '`language_id`=1',
            CONCAT('`metatags_title`="',`products_title`,'"'),
            CONCAT('`metatags_keywords`="',`products_description`,'"'),        
            CONCAT('`metatags_description`="',`products_description`,'"')
        ),
        ";"
    )
FROM `staging_products_new`;
-- }}}
-- Update the local tables {{{
INSERT IGNORE INTO `meta_tags_products_description` (
    `products_id`,
    `language_id`,
    `metatags_title`,
    `metatags_keywords`,
    `metatags_description`
)
SELECT
    `products_id`,
    1,
    `products_title`,
    `products_description`,
    `products_description`
FROM `staging_products_new`;
-- }}}
-- }}}
-- }}}
-- }}}
-- }}}

-- Import product-category links {{{
--    clone existing data [staging_placement_live]
-- Create a convenience view of the current data {{{
DROP TABLE IF EXISTS `staging_placement_live`;
CREATE TEMPORARY TABLE `staging_placement_live` (
    `products_id`    INT(11) NOT NULL,
    `categories_id`  INT(11) NOT NULL,
    `products_model` VARCHAR(32) NOT NULL,
    PRIMARY KEY (`products_id`,`categories_id`),
    UNIQUE (`products_model`,`categories_id`),
    INDEX (`products_id`),
    INDEX (`products_model`)
)Engine=MEMORY DEFAULT CHARSET=utf8mb4 AS
SELECT
    `products_to_categories`.`products_id` AS 'products_id',
    `products_to_categories`.`categories_id` AS 'categories_id',
    `staging_products_live`.`products_model` AS 'products_model'
FROM `products_to_categories`
LEFT OUTER JOIN `staging_products_live`
    ON `products_to_categories`.`products_id`
        = `staging_products_live`.`products_id`
WHERE
    `products_to_categories`.`categories_id` < @INCREMENT_BASE AND
    `products_to_categories`.`products_id` < @INCREMENT_BASE
ORDER BY `products_model`,`categories_id`;
-- }}}
--    read raw data from CSV file [staging_products_categories_ag {db_import-product-department.csv}]
-- Read the raw CSV into the database {{{
-- The table to read the data into {{{
DROP TABLE IF EXISTS `staging_placement_ag`;
CREATE TEMPORARY TABLE `staging_placement_ag` (
    `prod_code` VARCHAR(32) NOT NULL,
    `dept_code` INT(11) NOT NULL,
    KEY (`prod_code`)
)Engine=MEMORY DEFAULT CHARSET=utf8mb4;
-- }}}
-- Read the AzureGree data file {{{
LOAD DATA LOCAL
    INFILE 'db_import-product-department.csv'
INTO TABLE `staging_placement_ag`
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES;
-- }}}
-- }}}
--    convert data to Zen-Cart standards [staging_placement_import]
-- Apply Zen-Cart rules to the data {{{
-- Table for applying Zen-Cart rules to the links data {{{
DROP TABLE IF EXISTS `staging_placement_import`;
CREATE TEMPORARY TABLE `staging_placement_import` (
    `products_model` VARCHAR(32) NOT NULL,
    `products_id`    INT(11) DEFAULT NULL,
    `categories_id`  INT(11) NOT NULL,
    PRIMARY KEY (`products_model`,`categories_id`),
    UNIQUE (`categories_id`,`products_id`)
) ENGINE=MEMORY DEFAULT CHARSET=utf8mb4;
-- }}}
-- Convert the data to Zen-Cart rules {{{
INSERT IGNORE INTO `staging_placement_import` (
    `products_model`,
    `categories_id`
) SELECT
    `prod_code`,
    `dept_code`
FROM `staging_placement_ag`;
-- }}}
-- }}}
-- Sift placement records into new and dropped placements and new products {{{
-- Move placement records for new products to their own table {{{
DROP TABLE IF EXISTS `staging_placement_new`;
CREATE TEMPORARY TABLE `staging_placement_new` (
    `products_model` VARCHAR(32) NOT NULL,
    `categories_id`  INT(11) NOT NULL,
    `products_id`    INT(11) DEFAULT NULL,
    PRIMARY KEY (`products_model`,`categories_id`),
    INDEX (`products_model`),
    UNIQUE (`categories_id`,`products_id`)
)Engine=MEMORY DEFAULT CHARSET=utf8mb4;
INSERT IGNORE INTO `staging_placement_new` (
    `products_model`,
    `categories_id`,
    `products_id`
)
SELECT
    `staging_placement_import`.`products_model`,
    `staging_placement_import`.`categories_id`,
    `staging_products_new`.`products_id`
FROM `staging_placement_import`
JOIN `staging_products_new`
    ON `staging_products_new`.`products_model`
        =`staging_placement_import`.`products_model`;
DELETE FROM `staging_placement_import`
WHERE `products_model` IN (
    SELECT DISTINCT `products_model` FROM `staging_products_new`
);
-- }}}
-- Add products_id to the table, for remaining products {{{
UPDATE `staging_placement_import`
JOIN `staging_products_live`
    ON `staging_products_live`.`products_model`
        = `staging_placement_import`.`products_model`
SET `staging_placement_import`.`products_id`
    = `staging_products_live`.`products_id`
WHERE `staging_products_live`.`products_model` IS NOT NULL;
-- }}}
-- Find placements which have been dropped by AzureGreen {{{
DROP TABLE IF EXISTS `staging_placement_dropped`;
CREATE TEMPORARY TABLE `staging_placement_dropped` (
    `products_id`   INT(11) NOT NULL,
    `categories_id` INT(11) NOT NULL,
    INDEX (`products_id`)
)Engine=MEMORY;
INSERT IGNORE INTO `staging_placement_dropped` (
    `products_id`,
    `categories_id`
)
SELECT
    `staging_placement_live`.`products_id`,
    `staging_placement_live`.`categories_id`
FROM `staging_placement_live`
LEFT OUTER JOIN `staging_placement_import`
    ON `staging_placement_live`.`products_id`
        = `staging_placement_import`.`products_id`
    AND `staging_placement_live`.`categories_id`
        = `staging_placement_import`.`categories_id`
WHERE
    `staging_placement_import`.`products_id` IS NULL AND
    `staging_placement_import`.`categories_id` IS NULL AND
    `staging_placement_live`.`products_id` NOT IN (
        SELECT DISTINCT `products_id`
        FROM `staging_placement_errors`
        WHERE `issue`='Non-leaf category placement'
    );
-- }}}
-- Find placements which have been added by AzureGreen {{{
DROP TABLE IF EXISTS `staging_placement_added`;
CREATE TEMPORARY TABLE `staging_placement_added` (
    `products_id`   INT(11) NOT NULL,
    `categories_id` INT(11) NOT NULL,
    INDEX (`products_id`)
)Engine=MEMORY;
INSERT IGNORE INTO `staging_placement_added` (
    `products_id`,
    `categories_id`
)
SELECT
    `staging_placement_import`.`products_id`,
    `staging_placement_import`.`categories_id`
FROM `staging_placement_import`
LEFT OUTER JOIN `staging_placement_live`
    ON `staging_placement_import`.`products_id`
        = `staging_placement_live`.`products_id`
    AND `staging_placement_import`.`categories_id`
        = `staging_placement_live`.`categories_id`
WHERE
    `staging_placement_live`.`products_id` IS NULL AND
    `staging_placement_live`.`categories_id` IS NULL AND
    `staging_placement_import`.`categories_id` NOT IN (
        SELECT DISTINCT `parent_id` FROM `categories`
    );
-- }}}
-- }}}
-- Apply changes from the imported data {{{
-- Remove placements dropped by AzureGreen {{{
-- Generate script for remote database {{{
SELECT
    CONCAT(
        'DELETE FROM `products_to_categories`',
        ' WHERE ',
        CONCAT_WS(' AND',
            CONCAT('`products_id`=',`products_id`),
            CONCAT('`categories_id`=',`categories_id`)
        ),
        ';'
    )
FROM `staging_placement_dropped`;
-- }}}
-- Update local table {{{
DELETE `products_to_categories`
FROM `products_to_categories`
JOIN `staging_placement_dropped`
    ON `products_to_categories`.`products_id`
        = `staging_placement_dropped`.`products_id`
    AND `products_to_categories`.`categories_id`
        = `staging_placement_dropped`.`categories_id`;
-- }}}
-- }}}
-- Add new placements added by AzureGreen {{{
-- Generate script for remote database {{{
SELECT
    CONCAT(
        'INSERT IGNORE INTO `products_to_categories`',
        ' (`products_id`,`categories_id`)',
        ' VALUES (',
        CONCAT_WS(
            `products_id`,
            `categories_id`
        ),
        ');'
    )
FROM `staging_placement_added`;
-- }}}
-- Update local table {{{
INSERT IGNORE INTO `products_to_categories` (
    `products_id`,
    `categories_id`
)
SELECT
    `products_id`,
    `categories_id`
FROM `staging_placement_added`;
-- }}}
-- }}}
-- Apply new product placements {{{
-- Add the sorting category for each new product to the placement data {{{
INSERT IGNORE INTO `staging_placement_new` (
    `categories_id`,
    `products_id`,
    `products_model`
)
SELECT
    @IMPORT_CATEGORY,
    `products_id`,
    `products_model`
FROM `staging_products_new`;
-- }}}
-- Add the new product placements to the database {{{
-- Generate the script for the remote database {{{
SELECT
    CONCAT(
        'INSERT IGNORE INTO `products_to_categories`',
        ' SET ',
        CONCAT_WS(',',
            CONCAT('`products_id`=',`products_id`),
            CONCAT('`categories_id`=',`categories_id`)
        ),
        ' LIMIT 1;'
    )
FROM `staging_placement_new`
ORDER BY `products_model`,`categories_id`;
-- }}}
-- Update the local table {{{
INSERT IGNORE INTO `products_to_categories` (
    `products_id`,
    `categories_id`
)
SELECT
    `products_id`,
    `categories_id`
FROM `staging_placement_new`
ORDER BY `products_model`,`categories_id`;
-- }}}
-- }}}
-- Set the master category for new products, wehre possible {{{
-- Use an external, generated, script to set the master category for new products {{{
SOURCE ./master_categories.sql
-- }}}
-- Find and fix any new products not handled by the generated script {{{
UPDATE `products`
JOIN `products_to_categories`
    ON `products`.`products_id`
        = `products_to_categories`.`products_id`
SET `master_categories_id`=`categories_id`
WHERE
    `master_categories_id`=@IMPORT_CATEGORY AND
    NOT `categories_id`=@IMPORT_CATEGORY;
-- }}}
-- Generate the script to replicate the changes in the remote database {{{
SELECT 
    CONCAT(
        'UPDATE `products`',
        ' SET ',
        CONCAT_WS(',',
            CONCAT('`master_categories_id`=',`products`.`master_categories_id`)
        ),
        ' WHERE `products_id`=',`products`.`products_id`,
        ' LIMIT 1;'
    )
FROM `products`
JOIN `staging_products_new`
    USING (`products_id`);
-- }}}
-- }}}
-- }}}
-- }}}
--    collect anomolies (product in non-leaf category) [staging_placement_errors] 
-- Record errors found in the processing of placement data {{{
-- Items placed in categories which are not leaf nodes {{{
INSERT IGNORE INTO `staging_placement_errors` (
    `categories_id`,
    `products_id`,
    `products_model`,
    `issue`
)
SELECT
    `categories_id`,
    `products`.`products_id`,
    `products`.`products_model`,
    'Non-leaf category placement'
FROM `products_to_categories`
JOIN `products`
    ON `products`.`products_id`
        = `products_to_categories`.`products_id`
WHERE `categories_id` IN (
    SELECT DISTINCT `parent_id` FROM `categories`
);
-- }}}
-- Items without a sane master category {{{
INSERT IGNORE INTO `staging_placement_errors` (
    `categories_id`,
    `products_id`,
    `products_model`,
    `note_1`,
    `issue`
)
SELECT
    `master_categories_id`,
    `products_id`,
    `products_model`,
    `products_name`,
    'No category assigned'
FROM `products`
NATURAL JOIN `products_description`
WHERE `master_categories_id`=@IMPORT_CATEGORY;
-- }}}
-- }}}
--    correct AzureGreen error, changing cat-202 to cat-552 across the board
--    remove unchanged links from _import
--    insert new links into database
--    verify master of all products is still in link table
--       for dropped categories: set master to "missing", and add to anomolies
--       for existing categories: re-add to link table, and add to anomolies
-- }}}



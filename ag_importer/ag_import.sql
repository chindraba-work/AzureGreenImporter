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

-- TODO Add the "update" for categories
--      Force some categories to inactive
--      Add the "update" for products
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
    @SCRIPT_ADD_DATE:=`add_date`,
    @SCRIPT_NEW_DATE:=`new_date`
FROM `staging_control_dates`;
-- }}}

-- TODO: Add the creation of db_import-control_dates.csv to the Bash script.
--       Only needed if there is a pre-load happening, so that the date on
--       the pre-load will match the "new" date for new entries in the data
--       Could be useful, as well, to customize the "add" date for entries.
-- }}}

-- Import category data {{{
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
    `categories_description`
FROM `categories`
LEFT OUTER JOIN `categories_description`
    USING (`categories_id`)
WHERE `language_id`=1
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
    ON `staging_categories_live`.`categories_id`=`staging_categories_import`.`categories_id`
WHERE `staging_categories_import`.`categories_id` IS NULL;
-- }}}
--    remove unchanged categories from _import
-- Drop unchanged categories from further processing {{{
DELETE `staging_categories_import`
FROM `staging_categories_import`
JOIN `staging_categories_live`
    ON `staging_categories_import`.`categories_id`=`staging_categories_live`.`categories_id`
WHERE
    `staging_categories_import`.`categories_description`=`staging_categories_live`.`categories_description` AND
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
    `categories_description`  VARCHAR(255),
    `categories_status`       TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`categories_id`),
    KEY `idx_staging_categories_name_new` (`categories_name`),
    UNIQUE `idx_staging_categories_by_parent_new` (`parent_id`,`categories_description`)
) Engine=MEMORY DEFAULT CHARSET=utf8mb4 AS
SELECT
    `staging_categories_import`.`categories_id`,
    `staging_categories_import`.`parent_id`,
    LEFT(`staging_categories_import`.`categories_description`,32),
    `staging_categories_import`.`categories_description`,
    `staging_categories_import`.`categories_status`
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
    `parent_id`     INT(11) NOT NULL,
    PRIMARY KEY (`categories_id`)
)Engine=MEMORY AS
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
    ON `staging_categories_live`.`categories_id`=`staging_categories_import`.`categories_id`
WHERE NOT
    `staging_categories_live`.`categories_description`=`staging_categories_import`.`categories_description` AND
    `staging_categories_live`.`last_modified` IS NULL;
-- }}}
--    verify status of categories
-- Set status of categories to match the data from AzureGree {{{
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
    ON `staging_categories_import`.`categories_id`=`staging_categories_live`.`categories_id`
WHERE NOT `staging_categories_import`.`categories_status`=`staging_categories_live`.`categories_status`;
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
-- Table to hold the errors {{{
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
-- }}}
--    insert new categories into database
--    force inactive status for unwanted categories
-- }}}


-- Import product data {{{
--    clone existing data [staging_products_current]
-- Convenience view for current data {{{
CREATE OR REPLACE VIEW `staging_products_live` AS
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
    `products_name`,
    `products_description`
FROM `products`
LEFT OUTER JOIN `products_description`
    USING (`products_id`)
WHERE `language_id`=1; 
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
CREATE TABLE `staging_products_import` (
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
--    mark dropped products as inactive
-- Missing products become inactive {{{
DROP TABLE IF EXISTS `staging_products_dropped`;
CREATE TEMPORARY TABLE `staging_products_dropped` (
    `products_model`  VARCHAR(32) NOT NULL DEFAULT ''
)Engine=MEMORY DEFAULT CHARSET=utf8mb4 AS
SELECT
    `staging_products_live`.`products_model`
FROM `staging_products_live`
LEFT OUTER JOIN `staging_products_import`
    ON `staging_products_live`.`products_model`
        = `staging_products_import`.`products_model`
WHERE `staging_products_import`.`products_model` IS NULL;
-- }}}
--    update quantity, weight and price, where available, from import data
-- Table for the vital statistics for products {{{
DROP TABLE IF EXISTS `staging_products_vitals`;
CREATE TEMPORARY TABLE `staging_products_vitals` (
    `products_id`           INT(11) DEFAULT NULL,
    `products_model`        VARCHAR(32) NOT NULL DEFAULT '',
    `products_quantity`     FLOAT NOT NULL DEFAULT 0,
    `products_weight`       FLOAT NOT NULL DEFAULT 0,
    `products_price`        DECIMAL(15,4) NOT NULL DEFAULT 0.0000
)Engine=MEMORY DEFAULT CHARSET=utf8mb4 AS
SELECT
    `products_id`,
    `products_model`,
    `products_quantity`,
    `products_weight`,
    `products_price`
FROM `staging_products_import`;
-- }}}
--    update product status based on import status or quantity
-- Set product status {{{
DROP TABLE IF EXISTS `staging_products_status`;
CREATE TEMPORARY TABLE `staging_products_status` (
    `products_model` VARCHAR(32) NOT NULL DEFAULT ''
)Engine=MEMORY DEFAULT CHARSET=utf8mb4;
INSERT IGNORE INTO `staging_products_status` (
    `products_model`
)
SELECT
    `products_model`
FROM `staging_products_import`
WHERE
    `products_status`=0 OR
    NOT `products_quantity` > 0;
-- Add in products which were dropped by AzureGreen
INSERT IGNORE INTO `staging_products_status` (
    `products_model`
)
SELECT
    `products_model`
FROM `staging_products_dropped`;
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
DROP TABLE IF EXISTS `staging_products_rename`;
CREATE TEMPORARY TABLE `staging_products_rename` (
    `products_model` VARCHAR(32) NOT NULL DEFAULT '',
    `products_name`  VARCHAR(64) NOT NULL DEFAULT '',
    `products_title` VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (`products_model`)
)Engine=MEMORY DEFAULT CHARSET=utf8mb4 AS
SELECT
    `products_model`,
    `staging_products_import`.`products_name`,
    `staging_products_import`.`products_title`
FROM `staging_products_import`
JOIN `staging_products_live`
    USING (`products_model`)
WHERE
    NOT `staging_products_import`.`products_name`
        = `staging_products_live`.`products_name`
    AND `staging_products_live`.`products_last_modified` IS NULL;
-- }}}
-- Find description changes for products {{{
DROP TABLE IF EXISTS `staging_products_info`;
CREATE TEMPORARY TABLE `staging_products_info` (
    `products_model` VARCHAR(32) NOT NULL DEFAULT '',
    `products_description` TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (`products_model`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4 AS
SELECT
    `products_model`,
    `staging_products_import`.`products_description`
FROM `staging_products_import`
JOIN `staging_products_live`
    USING (`products_model`)
WHERE
    NOT `staging_products_import`.`products_description`
        = `staging_products_live`.`products_description`
    AND `staging_products_live`.`products_last_modified` IS NULL;
-- }}}
--    collect anomolies (name/desc too long, missing data, etc.) [staging_products_errors]
-- Record problems found in the new data for products {{{
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
--    insert new products into database
-- }}}

-- Import product-category links {{{
--    clone existing data [staging_products_categories_current]
--    read raw data from CSV file [staging_products_categories_ag {db_import-product-department.csv}]
-- Read the raw CSV into the database {{{
-- The table to read the data into {{{
DROP TABLE IF EXISTS `staging_products_categories_ag`;
CREATE TEMPORARY TABLE `staging_products_categories_ag` (
    `prod_code` VARCHAR(32) NOT NULL,
    `dept_code` INT(11) NOT NULL,
    KEY (`prod_code`)
)Engine=MEMORY DEFAULT CHARSET=utf8mb4;
-- }}}
-- Read the AzureGree data file {{{
LOAD DATA LOCAL
    INFILE 'db_import-product-department.csv'
INTO TABLE `staging_products_categories_ag`
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES;
-- }}}
-- }}}
--    convert data to Zen-Cart standards [staging_products_categories_import]
--    correct AzureGreen error, changing cat-202 to cat-552 across the board
--    remove unchanged links from _import
--    filter new links from _import [staging_products_categories_new]
--    collect anomolies (product in non-leaf category) [staging_products_categories_errors] 
--    insert new links into database
--    verify master of all products is still in link table
--       for dropped categories: set master to "missing", and add to anomolies
--       for existing categories: re-add to link table, and add to anomolies
-- }}}


-- Generate script to use in the admin area Install SQL Patch page {{{
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
-- }}}

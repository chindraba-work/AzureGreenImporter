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

-- Instructions:
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
-- 
-- Before this script is used the first time the realted tables need
-- to be empty. Most important is that there be no categories or
-- products in the database. The installation script sets the values
-- for auto_increment in both cases, and the AzureGreen imports are
-- intended to have ID values below that value and anything added by
-- the admin using in-built tools will have ID values above that. The
-- installer also adds the needed categories, hopefully near the start
-- of the sequence, for recording imports and errors.
--
-- This script is intended to be called by the shell script which does
-- the pre-processing of the AzureGreen data files, creating the data
-- files used by this script.

-- Setup the work area:
-- Set the global control dates for later use
-- add_date will be used for the 'created' type fields in the tables
-- new_date will be used for data_available on new products.
--   if all cases, the 'modified' type fields will be untouched, allowing
--   the store to create/update those as normal. Will serve as a flag here
--   indicating that the store (under admin control) made changes to the 
--   data, making that record 'untouchable' for updates to names and other
--   description-type information. 
DROP TABLE IF EXISTS `staging_control_dates`;
CREATE TABLE `staging_control_dates` (
    `add_date` DATETIME NOT NULL DEFAULT '2018-10-31 21:13:08',
    `new_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP 
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;
LOAD DATA LOCAL
    INFILE './db_import-control_dates.csv'
INTO TABLE `staging_control_dates`
    FIELDS TERMINATED BY ',' 
    OPTIONALLY ENCLOSED BY '"' 
    LINES TERMINATED BY '\n';
SELECT `add_date` FROM `staging_control_dates` INTO @SCRIPT_ADD_DATE;
SELECT `new_date` FROM `staging_control_dates` INTO @SCRIPT_NEW_DATE;

-- Set the AUTO_INCREMENT values for the category and product tables
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
SELECT CONCAT(
    'ALTER TABLE `products` AUTO_INCREMENT=',
    @INCREMENT_BASE,
    ';'
);

-- The `manufacturers_id` to be used for AzureGreen products
-- This requires that AzureGreen has been added to the database as a
-- manufacturer. For stores which will only ever carry AzureGreen
-- products this could be set to NULL. It is safer, at very little
-- cost in admin time, to add them to the database anyway.
SET @AZUREGREEN_ID=1;

-- Set the categories_id for some control categories
-- A category to place all new products into until they can be sorted out
SELECT `categories_id`
FROM `categories_description`
WHERE
    `language_id`=1 AND
    `categories_name`='AzureGreen Imports'
INTO @IMPORT_CATEGORY;
-- A category to place products into if a problem is found with the imported data
SELECT `categories_id`
FROM `categories_description`
WHERE
    `language_id`=1 AND
    `categories_name`='AzureGreen Issues'
INTO @ISSUE_CATEGORY;

-- Tables to hold discovered errors in the imported data
CREATE TABLE IF NOT EXISTS `staging_products_errors` (
    `products_model` VARCHAR(32) NOT NULL DEFAULT '',
    `issue`          VARCHAR(32) NOT NULL DEFAULT '',
    `note_1`         TEXT DEFAULT NULL,
    `note_2`         TEXT DEFAULT NULL,
    PRIMARY KEY (`products_model`,`issue`),
    KEY `idx_staging_products_errors` (`products_model`),
    KEY `idx_staging_products_issues` (`issue`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;

-- Import product data
DROP TABLE IF EXISTS `staging_products_live`;
CREATE TABLE `staging_products_live` (
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
DROP TABLE IF EXISTS `staging_products_id`;
CREATE TABLE `staging_products_id` (
    `products_id`    INT(11) NOT NULL AUTO_INCREMENT,
    `products_model` VARCHAR(32) NOT NULL DEFAULT '',
    PRIMARY KEY (`products_id`),
    UNIQUE (`products_model`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4 AS
SELECT
    `products_id`,
    `products_model`
FROM `staging_products_live`;
DROP TABLE IF EXISTS `staging_products_complete_ag`;
CREATE TABLE `staging_products_complete_ag` (
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
LOAD DATA LOCAL
    INFILE 'db_import-ag_complete_files.csv'
INTO TABLE `staging_products_complete_ag`
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES;
UPDATE `staging_products_complete_ag`
SET `prod_image` = REPLACE(`prod_image`, ' ', '');
UPDATE `staging_products_complete_ag`
SET `prod_image` = REPLACE(`prod_image`, '.jpeg', '.jpg');
UPDATE `staging_products_complete_ag`
SET `prod_image` = REPLACE(`prod_image`, '.tiff', '.tif');
DROP TABLE IF EXISTS `staging_products_stockinfo_ag`;
CREATE TABLE `staging_products_stockinfo_ag` (
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
LOAD DATA LOCAL
    INFILE 'db_import-stockinfo.csv'
INTO TABLE `staging_products_stockinfo_ag`
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES;
UPDATE `staging_products_stockinfo_ag`
SET `prod_image` = REPLACE(`prod_image`, ' ', '');
UPDATE `staging_products_stockinfo_ag`
SET `prod_image` = REPLACE(`prod_image`, '.jpeg', '.jpg');
UPDATE `staging_products_stockinfo_ag`
SET `prod_image` = REPLACE(`prod_image`, '.tiff', '.tif');
DROP TABLE IF EXISTS `staging_products_description_ag`;
CREATE TABLE `staging_products_description_ag` (
    `prod_code`  VARCHAR(32) NOT NULL DEFAULT '',
    `narrative`  TEXT DEFAULT NULL,
    INDEX (`prod_code`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;
LOAD DATA LOCAL
    INFILE 'db_import-descriptions.csv'
INTO TABLE `staging_products_description_ag`
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES;
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
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;
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
    IF(`narrative`='',`prod_desc`,`narrative`)
FROM `staging_products_complete_ag`;
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
UPDATE `staging_products_import`
JOIN `staging_products_description_ag`
    ON `staging_products_import`.`products_model`
        = `staging_products_description_ag`.`prod_code`
SET
    `staging_products_import`.`products_description`
        = `staging_products_description_ag`.`narrative`;
DROP TABLE IF EXISTS `staging_products_new`;
CREATE TABLE `staging_products_new` (
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
UPDATE `staging_products_new`
SET `products_status`=0
WHERE NOT `products_quantity` > 0;
DELETE `staging_products_import`
FROM `staging_products_import`
JOIN `staging_products_new`
    ON `staging_products_import`.`products_model`
        = `staging_products_new`.`products_model`;
UPDATE `staging_products_import`
JOIN `staging_products_live`
    ON `staging_products_import`.`products_model`
        = `staging_products_live`.`products_model`
SET `staging_products_import`.`products_id`
    = `staging_products_live`.`products_id`;
DROP TABLE IF EXISTS `staging_products_dropped`;
CREATE TABLE `staging_products_dropped` (
    `products_id`  INT(11) NOT NULL
)Engine=MyISAM AS
SELECT
    `staging_products_live`.`products_id`
FROM `staging_products_live`
LEFT OUTER JOIN `staging_products_import`
    ON `staging_products_live`.`products_model`
        = `staging_products_import`.`products_model`
WHERE
    `staging_products_import`.`products_model` IS NULL AND
    `staging_products_live`.`products_status`=1;
DROP TABLE IF EXISTS `staging_products_vitals`;
CREATE TABLE `staging_products_vitals` (
    `products_id`           INT(11) DEFAULT NULL,
    `products_model`        VARCHAR(32) NOT NULL DEFAULT '',
    `products_quantity`     FLOAT DEFAULT NULL,
    `products_weight`       FLOAT DEFAULT NULL,
    `products_price`        DECIMAL(15,4) DEFAULT NULL
)Engine=MyISAM DEFAULT CHARSET=utf8mb4 AS
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
DROP TABLE IF EXISTS `staging_products_inactive`;
CREATE TABLE `staging_products_inactive` (
    `products_id` INT(11) NOT NULL
)Engine=MyISAM;
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
INSERT IGNORE INTO `staging_products_inactive` (
    `products_id`
)
SELECT
    `products_id`
FROM `staging_products_dropped`;
DROP TABLE IF EXISTS `staging_products_active`;
CREATE TABLE `staging_products_active` (
    `products_id` INT(11) NOT NULL
)Engine=MyISAM;
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
DELETE `staging_products_import`
FROM `staging_products_import`
JOIN `staging_products_live`
    ON `staging_products_import`.`products_model`
        = `staging_products_live`.`products_model`
WHERE
    `staging_products_import`.`products_name`=`staging_products_live`.`products_name` AND
    `staging_products_import`.`products_description`=`staging_products_live`.`products_description`;
DROP TABLE IF EXISTS `staging_products_info`;
CREATE TABLE `staging_products_info` (
    `products_id`        INT(11) NOT NULL,
    `products_label`     VARCHAR(64) DEFAULT NULL,
    `products_title`     VARCHAR(255) DEFAULT NULL,
    `products_narrative` TEXT DEFAULT NULL,
    PRIMARY KEY (`products_id`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4 AS
SELECT
    `products_id`,
    `staging_products_import`.`products_name` AS 'products_label',
    `staging_products_import`.`products_title` AS 'products_title',
    NULL AS 'products_narrative'
FROM `staging_products_import`
JOIN `staging_products_live`
    USING (`products_id`)
WHERE
    `staging_products_live`.`products_last_modified` IS NULL AND
    NOT `staging_products_import`.`products_name`
        = `staging_products_live`.`products_name`;
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
INSERT IGNORE INTO `staging_products_errors` (
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
FROM `staging_products_new`
WHERE NOT `products_name`=`products_title`;
INSERT IGNORE INTO `staging_products_errors` (
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
INSERT IGNORE INTO `staging_products_errors` (
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
-- Apply changes from the information files
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
INSERT INTO `staging_products_id` (
    `products_model`
)
SELECT
    `products_model`
FROM `staging_products_new`;
UPDATE `staging_products_new`
JOIN `staging_products_id`
    ON `staging_products_new`.`products_model`
        = `staging_products_id`.`products_model`
SET
    `staging_products_new`.`products_id`
        = `staging_products_id`.`products_id`,
    `staging_products_new`.`master_categories_id`
        = @IMPORT_CATEGORY;
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
            CONCAT('`products_price_sorter`=',`products_price`),
            CONCAT('`master_categories_id`=',`master_categories_id`)
        ),
        ';'
    )
FROM `staging_products_new`;
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

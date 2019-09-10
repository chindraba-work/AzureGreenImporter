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
SELECT
CONCAT('SET @SCRIPT_ADD_DATE="',@SCRIPT_ADD_DATE:=`add_date`,'";')
FROM `staging_control_dates`;
SELECT
CONCAT('SET @SCRIPT_NEW_DATE="',@SCRIPT_NEW_DATE:=`new_date`,'";')
FROM `staging_control_dates`;

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
    'ALTER TABLE `categories` AUTO_INCREMENT=',
    @INCREMENT_BASE,
    ';'
);

-- Set the categories_id for some control categories
-- A category to place all new products into until they can be sorted out
SELECT 
CONCAT('SET @IMPORT_CATEGORY=',@IMPORT_CATEGORY:=`categories_id`,';')
FROM `categories_description`
WHERE
    `language_id`=1 AND
    `categories_name`='AzureGreen Imports';
-- A category to place products into if a problem is found with the imported data
SELECT 
CONCAT('SET @ISSUE_CATEGORY=',@ISSUE_CATEGORY:=`categories_id`,';')
FROM `categories_description`
WHERE
    `language_id`=1 AND
    `categories_name`='AzureGreen Issues';

-- Tables to hold discovered errors in the imported data
CREATE TABLE IF NOT EXISTS `staging_categories_errors` (
    `categories_id`  INT(11) NOT NULL,
    `issue`          VARCHAR(32) NOT NULL DEFAULT '',
    `note_1`         TEXT DEFAULT NULL,
    `note_2`         TEXT DEFAULT NULL,
    PRIMARY KEY (`categories_id`,`issue`),
    KEY `idx_staging_categories_errors` (`categories_id`),
    KEY `idx_staging_categories_issues` (`issue`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;

-- Import category data
DROP TABLE IF EXISTS `staging_categories_live`;
CREATE TABLE `staging_categories_live` (
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
DROP TABLE IF EXISTS `staging_categories_ag`;
CREATE TABLE `staging_categories_ag` (
    `dept_name`  VARCHAR(255) NOT NULL,
    `dept_code`  INT(11) NOT NULL,
    `dept_deep`  INT(11) NOT NULL,
    `dept_show`  TINYINT(1) NOT NULL DEFAULT 1,
    `parent_id`  INT(11) NOT NULL DEFAULT 0,
    INDEX (`dept_code`),
    INDEX (`parent_id`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;
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
DROP TABLE IF EXISTS `staging_categories_import`;
CREATE TABLE `staging_categories_import` (
    `categories_id`           INT(11) NOT NULL,
    `parent_id`               INT(11) NOT NULL,
    `categories_description`  VARCHAR(255),
    `categories_status`       TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`categories_id`),
    KEY `idx_staging_categories_name_import` (`categories_description`)
--    UNIQUE `idx_staging_categories_by_parent_import` (`parent_id`,`categories_description`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;
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
-- Missing categories become inactive
DROP TABLE IF EXISTS `staging_categories_dropped`;
CREATE TABLE `staging_categories_dropped` (
    `categories_id` INT(11) NOT NULL
)Engine=MyISAM AS
SELECT
    `staging_categories_live`.`categories_id`
FROM `staging_categories_live`
LEFT OUTER JOIN `staging_categories_import`
    ON `staging_categories_live`.`categories_id`
        = `staging_categories_import`.`categories_id`
WHERE `staging_categories_import`.`categories_id` IS NULL;
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
DROP TABLE IF EXISTS `staging_categories_new`;
CREATE TABLE `staging_categories_new` (
    `categories_id`           INT(11) NOT NULL,
    `parent_id`               INT(11) NOT NULL,
    `categories_name`         VARCHAR(32),
    `categories_description`  VARCHAR(255),
    `categories_status`       TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`categories_id`),
    KEY `idx_staging_categories_name_new` (`categories_name`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4 AS
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
DROP TABLE IF EXISTS `staging_categories_parent`;
CREATE TABLE `staging_categories_parent` (
    `categories_id` INT(11) NOT NULL,
    `parent_id`     INT(11) NOT NULL,
    PRIMARY KEY (`categories_id`)
)Engine=MyISAM AS
SELECT
    `staging_categories_import`.`categories_id`,
    `staging_categories_import`.`parent_id`
FROM `staging_categories_import`
JOIN `staging_categories_live`
    ON `staging_categories_import`.`categories_id`
        = `staging_categories_live`.`categories_id`
WHERE NOT `staging_categories_import`.`parent_id`
    = `staging_categories_live`.`parent_id`;
DROP TABLE IF EXISTS `staging_categories_rename`;
CREATE TABLE `staging_categories_rename` (
    `categories_id`          INT(11) NOT NULL,
    `categories_name`        VARCHAR(32) NOT NULL DEFAULT '',
    `categories_description` VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (`categories_id`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4 AS
SELECT
    `staging_categories_import`.`categories_id` AS 'categories_id',
    LEFT(`staging_categories_import`.`categories_description`,32) AS 'categories_name',
    `staging_categories_import`.`categories_description` AS 'categories_description'
FROM `staging_categories_import`
JOIN `staging_categories_live`
    ON `staging_categories_live`.`categories_id`
        = `staging_categories_import`.`categories_id`
WHERE NOT
    `staging_categories_live`.`categories_description`
        = `staging_categories_import`.`categories_description` AND
    `staging_categories_live`.`last_modified` IS NULL;
DROP TABLE IF EXISTS `staging_categories_status`;
CREATE TABLE `staging_categories_status` (
    `categories_id`     INT(11) NOT NULL,
    `categories_status` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`categories_id`)
)Engine=MyISAM AS
SELECT
    `staging_categories_import`.`categories_id`,
    `staging_categories_import`.`categories_status`
FROM `staging_categories_import`
JOIN `staging_categories_live`
    ON `staging_categories_import`.`categories_id`
        = `staging_categories_live`.`categories_id`
WHERE NOT `staging_categories_import`.`categories_status`
    = `staging_categories_live`.`categories_status`;
INSERT INTO `staging_categories_status` (
    `categories_id`,
    `categories_status`
)
SELECT `categories_id`,0
FROM `staging_categories_dropped`
ON DUPLICATE KEY UPDATE `categories_status`=0;
INSERT IGNORE INTO `staging_categories_errors` (
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
INSERT IGNORE INTO `staging_categories_errors` (
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
        SELECT `categories_id` FROM `staging_categories_live`
        UNION
        SELECT `categories_id` FROM `staging_categories_new`
        UNION
        SELECT `categories_id` FROM `staging_categories_import`
        UNION
        SELECT 0
    );
INSERT IGNORE INTO `staging_categories_errors` (
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
        SELECT `categories_id` FROM `staging_categories_live`
        UNION
        SELECT `categories_id` FROM `staging_categories_new`
        UNION
        SELECT `categories_id` FROM `staging_categories_import`
        UNION
        SELECT 0
    );
INSERT IGNORE INTO `staging_categories_errors` (
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
INSERT IGNORE INTO `staging_categories_errors` (
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
INSERT IGNORE INTO `staging_categories_errors` (
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
INSERT IGNORE INTO `staging_categories_errors` (
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
-- Apply collected changes to categories tables
--    insert new categories into database
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
SELECT
    CONCAT(
        'UPDATE `categories`',
        ' SET ',
        CONCAT('`parent_id`=',`parent_id`),
        ' WHERE `categories_id`=',`categories_id`,
        ' LIMIT 1;'
    )
FROM `staging_categories_parent`;
UPDATE `categories`
JOIN `staging_categories_parent`
    ON `staging_categories_parent`.`categories_id`
        = `categories`.`categories_id`
SET `categories`.`parent_id`=`staging_categories_parent`.`parent_id`;
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
SELECT
    CONCAT(
        'UPDATE `meta_tags_categories_description`',
        ' SET ',
        CONCAT_WS(',',
            CONCAT('`metatags_title`="',LEFT(`categories_description`,64),'"'),
            CONCAT('`metatags_keywords`="',`categories_description`,'"'),
            CONCAT('`metatags_description`="',`categories_description`,'"')
        ),
        ' WHERE `language_id`=1',
        ' LIMIT 1;'
    )
FROM `staging_categories_rename`;
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
UPDATE `categories`
JOIN `staging_categories_status`
    ON `staging_categories_status`.`categories_id`
        = `categories`.`categories_id`
SET `categories`.`categories_status`
    = `staging_categories_status`.`categories_status`
WHERE NOT `categories`.`categories_status`
    = `staging_categories_status`.`categories_status`;
-- Make choosen categories inactive, regardless of AzureGreen's data
SELECT
    CONCAT(
        'UPDATE `categories`',
        ' SET ',
        CONCAT('`categories_status`=',0),
        ' WHERE `categories_id` IN (29,33,250,278,524,421,6,14,124,396,619);'
    );
UPDATE `categories`
SET `categories_status`=0
WHERE `categories_id` IN (29,33,250,278,524,421,6,14,124,396,619);

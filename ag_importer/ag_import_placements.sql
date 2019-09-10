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

-- Instructions: (see the ag_import_categories.sql file)

-- Setup the work area:

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

-- Import product-category links
DROP TABLE IF EXISTS `staging_placement_live`;
CREATE TABLE `staging_placement_live` (
    `products_id`    INT(11) NOT NULL,
    `categories_id`  INT(11) NOT NULL,
    `products_model` VARCHAR(32) NOT NULL,
    PRIMARY KEY (`products_id`,`categories_id`),
    UNIQUE (`products_model`,`categories_id`),
    INDEX (`products_id`),
    INDEX (`products_model`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4 AS
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
DROP TABLE IF EXISTS `staging_placement_ag`;
CREATE TABLE `staging_placement_ag` (
    `prod_code` VARCHAR(32) NOT NULL,
    `dept_code` INT(11) NOT NULL,
    KEY (`prod_code`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;
LOAD DATA LOCAL
    INFILE 'db_import-product-department.csv'
INTO TABLE `staging_placement_ag`
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES;
DROP TABLE IF EXISTS `staging_placement_import`;
CREATE TABLE `staging_placement_import` (
    `products_model` VARCHAR(32) NOT NULL,
    `products_id`    INT(11) DEFAULT NULL,
    `categories_id`  INT(11) NOT NULL,
    PRIMARY KEY (`products_model`,`categories_id`),
    UNIQUE (`categories_id`,`products_id`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;
INSERT IGNORE INTO `staging_placement_import` (
    `products_model`,
    `categories_id`
) SELECT
    `prod_code`,
    `dept_code`
FROM `staging_placement_ag`
JOIN `categories`
    ON `staging_placement_ag`.`dept_code`
        = `categories`.`categories_id`;
DROP TABLE IF EXISTS `staging_placement_new`;
CREATE TABLE `staging_placement_new` (
    `products_model` VARCHAR(32) NOT NULL,
    `categories_id`  INT(11) NOT NULL,
    `products_id`    INT(11) DEFAULT NULL,
    PRIMARY KEY (`products_model`,`categories_id`),
    INDEX (`products_model`),
    UNIQUE (`categories_id`,`products_id`)
)Engine=MyISAM DEFAULT CHARSET=utf8mb4;
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
UPDATE `staging_placement_import`
JOIN `staging_products_live`
    ON `staging_products_live`.`products_model`
        = `staging_placement_import`.`products_model`
SET `staging_placement_import`.`products_id`
    = `staging_products_live`.`products_id`
WHERE `staging_products_live`.`products_model` IS NOT NULL;
DROP TABLE IF EXISTS `staging_placement_dropped`;
CREATE TABLE `staging_placement_dropped` (
    `products_id`   INT(11) NOT NULL,
    `categories_id` INT(11) NOT NULL,
    INDEX (`products_id`)
)Engine=MyISAM;
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
DROP TABLE IF EXISTS `staging_placement_added`;
CREATE TABLE `staging_placement_added` (
    `products_id`   INT(11) NOT NULL,
    `categories_id` INT(11) NOT NULL,
    INDEX (`products_id`)
)Engine=MyISAM;
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
SELECT
    CONCAT(
        'DELETE FROM `products_to_categories`',
        ' WHERE ',
        CONCAT_WS(' AND ',
            CONCAT('`products_id`=',`products_id`),
            CONCAT('`categories_id`=',`categories_id`)
        ),
        ';'
    )
FROM `staging_placement_dropped`;
DELETE `products_to_categories`
FROM `products_to_categories`
JOIN `staging_placement_dropped`
    ON `products_to_categories`.`products_id`
        = `staging_placement_dropped`.`products_id`
    AND `products_to_categories`.`categories_id`
        = `staging_placement_dropped`.`categories_id`;
SELECT
    CONCAT(
        'INSERT IGNORE INTO `products_to_categories`',
        ' (`products_id`,`categories_id`)',
        ' VALUES (',
        CONCAT_WS(',',
            `products_id`,
            `categories_id`
        ),
        ');'
    )
FROM `staging_placement_added`;
INSERT IGNORE INTO `products_to_categories` (
    `products_id`,
    `categories_id`
)
SELECT
    `products_id`,
    `categories_id`
FROM `staging_placement_added`;
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
SELECT
    CONCAT(
        'INSERT IGNORE INTO `products_to_categories`',
        ' SET ',
        CONCAT_WS(',',
            CONCAT('`products_id`=',`products_id`),
            CONCAT('`categories_id`=',`categories_id`)
        ),
        ';'
    )
FROM `staging_placement_new`
ORDER BY `products_model`,`categories_id`;
INSERT IGNORE INTO `products_to_categories` (
    `products_id`,
    `categories_id`
)
SELECT
    `products_id`,
    `categories_id`
FROM `staging_placement_new`
ORDER BY `products_model`,`categories_id`;
-- Use an external, generated, script to set the master category for new products
SOURCE ./db_import-master_categories.sql
UPDATE `products`
JOIN `products_to_categories`
    ON `products`.`products_id`
        = `products_to_categories`.`products_id`
SET `master_categories_id`=`categories_id`
WHERE
    `master_categories_id`=@IMPORT_CATEGORY AND
    NOT `categories_id`=@IMPORT_CATEGORY;
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

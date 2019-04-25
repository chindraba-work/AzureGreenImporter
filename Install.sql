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

INSERT INTO `PFX_categories`
    (`categories_id`, `categories_image`, `parent_id`, `sort_order`, `date_added`, `last_modified`, `categories_status`)
VALUES
    (5000, NULL, 0, 0, '2019-04-01 02:51:05', NULL, 0),
    (5001, NULL, 0, 0, '2019-04-01 02:51:05', NULL, 0),
    (5002, NULL, 0, 0, '2019-04-01 02:51:05', NULL, 0);
INSERT INTO `PFX_categories_description`
    (`categories_id`, `language_id`, `categories_name`, `categories_description`)
VALUES
    (5000, 1, 'AzureGreen Imports',         'Items imported from the online resources supplied by AzureGreen'),
    (5001, 1, 'AzureGreen Editing Imports', 'Items imported from the online resources supplied by AzureGreen which look like they need editing or reviewing.'),
    (5002, 1, 'AzureGreen Products',        'Checked imports using the online resources supplied by AzureGreen');

ALTER TABLE `PFX_categories`
  MODIFY `categories_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5011;

DROP TABLE IF EXISTS `PFX_acquired_anomalies`;
CREATE TABLE `PFX_acquired_anomalies` (
  `table_name` VARCHAR(64) NOT NULL,
  `field_name` VARCHAR(64) NOT NULL,
  `record_id`  INT(11) NOT NULL,
  `original`   TEXT,
  `imported`   TEXT,
  `created`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated`    DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`table_name`,`field_name`,`record_id`)
) Engine=MyISAM DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS `PFX_ag_departments`;
CREATE TABLE `PFX_ag_departments` (
  `dept_name`  VARCHAR(255) NOT NULL,
  `dept_code`  INT(11) NOT NULL,
  `dept_deep`  INT(11) NOT NULL,
  `dept_show`  TINYINT(1) NOT NULL DEFAULT 1,
  `parent_id`  INT(11) NOT NULL DEFAULT 0,
  INDEX (`dept_code`),
  INDEX (`parent_id`)
) Engine=MyISAM DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS `PFX_import_departments`;
CREATE TABLE `PFX_import_departments` (
  `categories_id`           INT(11) NOT NULL,
  `parent_id`               INT(11) NOT NULL,
  `categories_name`         VARCHAR(32),
  `categories_description`  TEXT,
  `categories_status`       TINYINT(1) NOT NULL DEFAULT 1
) Engine=MyISAM DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS `PFX_ag_products_department`;
CREATE TABLE `PFX_ag_products_department` (
  `prod_code`  VARCHAR(32) NOT NULL,
  `dept_code`  INT(11) NOT NULL,
  INDEX (`prod_code`)
) Engine=MyISAM DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS `PFX_import_products_category`;
CREATE TABLE `PFX_import_products_category` (
  `products_model` VARCHAR(32) DEFAULT NULL,
  `categories_id`  INT(11) NOT NULL,
  PRIMARY KEY (`products_model`,`categories_id`),
  INDEX (`products_model`)
) Engine=MyISAM DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS `PFX_ag_stockinfo`;
CREATE TABLE `PFX_ag_stockinfo` (
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
) Engine=MyISAM DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS `PFX_ag_descriptions`;
CREATE TABLE `PFX_ag_descriptions` (
  `prod_code`  VARCHAR(32) NOT NULL DEFAULT '',
  `narrative`  TEXT DEFAULT NULL,
  INDEX (`prod_code`)
) Engine=MyISAM DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS `PFX_ag_complete`;
CREATE TABLE `PFX_ag_complete` (
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
) Engine=MyISAM DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS `PFX_import_products`;
CREATE TABLE `PFX_import_products` (
  `products_model`       VARCHAR(32) DEFAULT NULL,
  `products_name`        VARCHAR(64) NOT NULL DEFAULT '',
  `metatags_title`       VARCHAR(255) NOT NULL DEFAULT '',
  `products_description` TEXT DEFAULT NULL,
  `metatags_keywords`    TEXT DEFAULT NULL,
  `metatags_description` TEXT DEFAULT NULL,
  `products_quantity`    FLOAT NOT NULL DEFAULT 0,
  `products_weight`      FLOAT NOT NULL DEFAULT 0,
  `products_price`       DECIMAL(15,4) NOT NULL DEFAULT 0.0000,
  `products_image`       VARCHAR(255) DEFAULT NULL,
  `products_status`      TINYINT(1) NOT NULL DEFAULT 0,
  `master_categories_id` INT(11) NOT NULL DEFAULT 0,
  PRIMARY KEY `products_model` (`products_model`)
) Engine=MyISAM DEFAULT CHARSET=utf8mb4;

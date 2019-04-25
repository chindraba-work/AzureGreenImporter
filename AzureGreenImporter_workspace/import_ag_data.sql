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

--
-- Load the Departments table from AzureGreen
--

-- Impose Zen-Cart limits

TRUNCATE `PFX_import_departments`;

INSERT INTO `PFX_import_departments` (
  `categories_id`,
  `parent_id`,
  `categories_name`,
  `categories_description`,
  `categories_status`
)
SELECT
  `dept_code`,
  `parent_id`,
  LEFT(`dept_name`,32),
  `dept_name`,
  `dept_show`
FROM `PFX_ag_departments`
ORDER BY `dept_deep`,`parent_id`,`dept_code`;

DELETE FROM `PFX_ag_products_department`
WHERE `dept_code` < 0;

TRUNCATE `PFX_import_products_category`;

INSERT IGNORE INTO `PFX_import_products_category` (
  `products_model`,
  `categories_id`
)
SELECT
  `prod_code`,
  `dept_code`
FROM `PFX_ag_products_department`;

-- Convert the complete listing first

TRUNCATE `PFX_import_products`;
INSERT INTO `PFX_import_products` (
  `products_model`,
  `products_name`,
  `products_description`,
  `products_quantity`,
  `products_weight`,
  `products_price`,
  `products_image`,
  `products_status`
)
SELECT
  `prod_code`,
  LEFT(`prod_desc`,64),
  `narrative`,
  `units_qty`,
  `weight`,
  `price`,
  LCASE(CONCAT(
    LEFT(`prod_image`,2),
    '/',
    `prod_image`
  )),
  IF(`cantsell`=1 OR `discont`=1,0,1)
FROM `PFX_ag_complete`;

-- Add the StockInfo listing, overriding previous data

INSERT INTO `PFX_import_products` (
  `products_model`,
  `products_name`,
  `products_quantity`,
  `products_weight`,
  `products_price`,
  `products_image`,
  `products_status`
)
SELECT
  `prod_code`,
  LEFT(`prod_desc`,64),
  `units_qty`,
  `weight`,
  `price`,
  LCASE(CONCAT(
    LEFT(`prod_image`,2),
    '/',
    `prod_image`
  )),
  IF(`cantsell`=1 OR `discont`=1,0,1)
FROM `PFX_ag_stockinfo` AS `src`
ON DUPLICATE KEY UPDATE
  `products_name`=LEFT(`src`.`prod_desc`,64),
  `products_quantity`=`src`.`units_qty`,
  `products_weight`=`src`.`weight`,
  `products_price`=`src`.`price`,
  `products_image`=LCASE(CONCAT(
    LEFT(`src`.`prod_image`,2),
    '/',
    `src`.`prod_image`
  )),
  `products_status`=IF(`src`.`cantsell`=1 OR `src`.`discont`=1,0,1);

-- Add the Descriptions, overriding previous data

INSERT INTO `PFX_import_products` (
  `products_model`,
  `products_description`
)
SELECT
  `prod_code`,
  `narrative`
FROM `PFX_ag_descriptions` AS `src`
  JOIN `PFX_ag_stockinfo` AS `stock`
    USING (`prod_code`)
ON DUPLICATE KEY UPDATE
  `products_description`=`src`.`narrative`;

-- Find new categories and add them to the database

INSERT INTO `PFX_categories_description` (
  `categories_id`,
  `categories_name`,
  `categories_description`
)
SELECT
  `import`.`categories_id`,
  `import`.`categories_name`,
  `import`.`categories_description`
FROM `PFX_import_departments` AS `import`
  LEFT OUTER JOIN `PFX_categories` AS `cats`
    ON `import`.`categories_id` = `cats`.`categories_id`
WHERE `cats`.`categories_id` IS NULL;

INSERT INTO `PFX_acquired_anomalies` (
  `table_name`,
  `field_name`,
  `record_id`,
  `original`,
  `imported`
)
SELECT
  'categories_description',
  'categories_description',
  `import`.`categories_id`,
  NULL,
  `import`.`categories_description`
FROM `PFX_import_departments` AS `import`
  LEFT OUTER JOIN `PFX_categories` AS `cats`
    ON `import`.`categories_id` = `cats`.`categories_id`
WHERE `cats`.`categories_id` IS NULL
ON DUPLICATE KEY UPDATE
  `updated` = NULL,
  `imported` = `import`.`categories_description`;

INSERT INTO `PFX_meta_tags_categories_description` (
  `categories_id`,
  `metatags_title`,
  `metatags_keywords`,
  `metatags_description`
)
SELECT
  `import`.`categories_id`,
  `import`.`categories_name`,
  `import`.`categories_description`,
  `import`.`categories_description`
FROM `PFX_import_departments` AS `import`
  LEFT OUTER JOIN `PFX_categories` AS `cats`
    ON `import`.`categories_id` = `cats`.`categories_id`
WHERE `cats`.`categories_id` IS NULL;

INSERT INTO `PFX_acquired_anomalies` (
  `table_name`,
  `field_name`,
  `record_id`,
  `original`,
  `imported`
)
SELECT
  'categories_description',
  'categories_name',
  `import`.`categories_id`,
  `import`.`categories_description`,
  `import`.`categories_name`
FROM `PFX_import_departments` AS `import`
  LEFT OUTER JOIN `PFX_categories` AS `cats`
    ON `import`.`categories_id` = `cats`.`categories_id`
WHERE `cats`.`categories_id` IS NULL
  AND NOT `import`.`categories_name` = `import`.`categories_description`
ON DUPLICATE KEY UPDATE
  `updated` = NULL,
  `original` = `import`.`categories_description`,
  `imported` = `import`.`categories_name`;

INSERT INTO `PFX_categories` (
  `categories_id`,
  `parent_id`,
  `categories_status`,
  `sort_order`,
  `date_added`
)
SELECT
  `import`.`categories_id`,
  `import`.`parent_id`,
  `import`.`categories_status`,
  0,
  CURRENT_TIMESTAMP
FROM `PFX_import_departments` AS `import`
  LEFT OUTER JOIN `PFX_categories` AS `cats`
    ON `import`.`categories_id` = `cats`.`categories_id`
WHERE `cats`.`categories_id` IS NULL;

-- Find categories dropped by AzureGreen and make them inactive

UPDATE `PFX_categories` AS `cats`
  LEFT OUTER JOIN `PFX_import_departments` AS `import`
    ON `cats`.`categories_id` = `import`.`categories_id`
SET `cats`.`categories_status`=0
WHERE `import`.`categories_id` IS NULL
  AND `cats`.`categories_status`=1;

-- Resync categories that have a new parent category

UPDATE `PFX_categories` AS `cats`
  JOIN `PFX_import_departments` AS `import`
    ON `import`.`categories_id` = `cats`.`categories_id`
SET `cats`.`parent_id` = `import`.`parent_id`
WHERE NOT `cats`.`parent_id` = `import`.`parent_id`;

-- Find existing categories with new names

UPDATE `PFX_categories_description` AS `target`
  JOIN `PFX_categories` AS `cats`
    USING (`categories_id`)
  JOIN `PFX_import_departments` AS `import`
    USING (`categories_id`)
SET
  `target`.`categories_name` = `import`.`categories_name`
WHERE NOT `import`.`categories_name` = `target`.`categories_name`
  AND `cats`.`last_modified` IS NULL;

-- Turn off selecte categories. Repeated as earlier operation could clear this

UPDATE `PFX_categories`
SET `categories_status` = 0
WHERE `categories_id` IN (29,33,250,278,524,421,6,14,124,396);

-- Find the products where AzureGreen dropped the product
-- Mark dropped products as inactive

UPDATE `PFX_products` AS `prod`
  LEFT OUTER JOIN `PFX_import_products` AS `import`
    ON `prod`.`products_model` = `import`.`products_model`
SET `prod`.`products_status`=0
WHERE `import`.`products_model` IS NULL;

-- Find the products which AzureGreen has added to the catalog
-- Add the "imported" category to new products

INSERT INTO `PFX_import_products_category` (
  `categories_id`,
  `products_model`
)
SELECT
  5000,
  `import`.`products_model`
FROM `PFX_import_products` AS `import`
  LEFT OUTER JOIN `PFX_products` AS `prod`
    ON  `import`.`products_model` = `prod`.`products_model`
WHERE `prod`.`products_model` IS NULL;

-- Find new products which have a name that will not fit in the database
-- Add the "edited" category to new products that had their name chopped

INSERT INTO `PFX_import_products_category` (
  `categories_id`,
  `products_model`
)
SELECT
  5001,
  `import`.`products_model`
FROM `PFX_ag_stockinfo` AS `info`
  JOIN `PFX_import_products` AS `import`
    ON `info`.`prod_code` = `import`.`products_model`
  LEFT OUTER JOIN `PFX_products` AS `prod`
    ON  `import`.`products_model`  = `prod`.`products_model`
WHERE `prod`.`products_model` IS NULL
  AND NOT `info`.`prod_desc` = `import`.`products_name`;

REPLACE INTO `PFX_acquired_anomalies` (
  `table_name`,
  `field_name`,
  `record_id`,
  `original`,
  `imported`
)
SELECT
  'products_description',
  'products_name',
  `prod`.`products_id`,
  `stock`.`prod_desc`,
  `info`.`products_name`
FROM `PFX_ag_stockinfo` AS `stock`
  JOIN `PFX_products` AS `prod`
    ON `prod`.`products_model` = `stock`.`prod_code`
    AND `prod`.`products_last_modified` IS NULL
    AND `prod`.`products_model` NOT IN (
      SELECT `products_model`
      FROM `PFX_import_products_category`
      WHERE `categories_id` = 5000
    )
  JOIN `PFX_products_description` AS `info`
    ON `info`.`products_id` = `prod`.`products_id`
    AND NOT `info`.`products_name` = `stock`.`prod_desc`;

-- Add the new products to our catalog

INSERT INTO `PFX_products` (
  `master_categories_id`,
  `products_tax_class_id`,
  `metatags_title_status`,
  `metatags_products_name_status`,
  `products_date_added`,
  `products_last_modified`,
  `products_date_available`,
  `products_model`,
  `products_image`,
  `products_quantity`,
  `products_price`,
  `products_price_sorter`,
  `products_weight`,
  `products_status`
)
SELECT
  5000,1,1,1,
  CURRENT_TIMESTAMP,
  NULL,
  CURRENT_TIMESTAMP,
  `import`.`products_model`,
  `import`.`products_image`,
  `import`.`products_quantity`,
  `import`.`products_price`,
  `import`.`products_price`,
  `import`.`products_weight`,
  `import`.`products_status`
FROM `PFX_import_products` AS `import`
  LEFT OUTER JOIN `PFX_products` AS `prod`
    ON  `import`.`products_model` = `prod`.`products_model`
  JOIN `PFX_import_products_category` AS `cats`
    ON `cats`.`products_model` = `import`.`products_model`
    AND `cats`.`categories_id` = 5000;

INSERT INTO `PFX_products_description` (
  `products_id`,
  `products_name`,
  `products_description`
)
SELECT
  `prod`.`products_id`,
  `import`.`products_name`,
  `import`.`products_description`
FROM `PFX_import_products` AS `import`
  JOIN `PFX_products` AS `prod`
    USING (`products_model`)
  JOIN `PFX_import_products_category` AS `cats`
    ON `cats`.`products_model` = `prod`.`products_model`
    AND `cats`.`categories_id` = 5000;

INSERT INTO `PFX_meta_tags_products_description` (
  `products_id`,
  `metatags_title`,
  `metatags_keywords`,
  `metatags_description`
)
SELECT
  `prod`.`products_id`,
  `import`.`products_name`,
  `import`.`products_description`,
  `import`.`products_description`
FROM `PFX_import_products` AS `import`
  JOIN `PFX_products` AS `prod`
    USING (`products_model`)
  JOIN `PFX_import_products_category` AS `cats`
    ON `cats`.`products_model` = `prod`.`products_model`
    AND `cats`.`categories_id` = 5000;

-- Update vital statistics for the active products using imported data

UPDATE `PFX_products` AS `prod`
  JOIN `PFX_import_products` AS `import`
    ON `prod`.`products_model` = `import`.`products_model`
    AND `prod`.`products_model` NOT IN (
      SELECT `products_model`
      FROM `PFX_import_products_category`
      WHERE `categories_id` = 5000
    )
SET
  `prod`.`products_last_modified` = NULL,
  `prod`.`products_quantity`      = `import`.`products_quantity`,
  `prod`.`products_weight`        = `import`.`products_weight`,
  `prod`.`products_price`         = `import`.`products_price`,
  `prod`.`products_price_sorter`  = `import`.`products_price`,
  `prod`.`products_image`         = `import`.`products_image`,
  `prod`.`products_status`        = `import`.`products_status`;

-- Add the links betwen products and categories

REPLACE INTO `PFX_products_to_categories` (
  `products_id`,
  `categories_id`
)
SELECT `products_id`,`categories_id`
FROM `PFX_import_products_category`
  JOIN `PFX_products`
    USING (`products_model`);

-- Remove product to categories links that AzureGreen has dropped

DELETE `cats`.*
FROM `PFX_products_to_categories` AS `cats`
  JOIN `PFX_products` AS `prod`
    USING (`products_id`)
  LEFT OUTER JOIN `PFX_import_products_category` AS `import`
    ON  `import`.`products_model` = `prod`.`products_model`
    AND `import`.`categories_id`  = `cats`.`categories_id`
WHERE `import`.`categories_id` IS NULL
  AND `import`.`products_model` IS NULL
  AND `cats`.`categories_id` < 5000;

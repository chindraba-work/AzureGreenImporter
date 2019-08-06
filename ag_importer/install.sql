ALTER TABLE `categories` AUTO_INCREMENT=100001;
ALTER TABLE `products` AUTO_INCREMENT=100001;
INSERT INTO `categories`
SET
    `parent_id`=0,
    `categories_status`=0;
INSERT INTO `categories_description`
SET
    `categories_id`=LAST_INSERT_ID(),
    `categories_name`='AzureGreen Imports',
    `categories_description`='Products imported using the automated importer scripts',
    `language_id`=1;
INSERT IGNORE INTO `meta_tags_categories_description`
SET
    `categories_id`=LAST_INSERT_ID(),
    `metatags_title`='AzureGreen Imports',
    `metatags_keywords`='Products imported using the automated importer scripts',
    `metatags_description`='Products imported using the automated importer scripts';
INSERT INTO `categories`
SET
    `parent_id`=0,
    `categories_status`=0;
INSERT INTO `categories_description`
SET
    `categories_id`=LAST_INSERT_ID(),
    `categories_name`='AzureGreen Issues',
    `categories_description`='Products with errors found when imported using the automated importer scripts',
    `language_id`=1;
INSERT IGNORE INTO `meta_tags_categories_description`
SET
    `categories_id`=LAST_INSERT_ID(),
    `metatags_title`='AzureGreen Issues',
    `metatags_keywords`='Products with errors found when imported using the automated importer scripts',
    `metatags_description`='Products with errors found when imported using the automated importer scripts',
    `language_id`=1;

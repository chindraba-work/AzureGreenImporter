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

TRUNCATE TABLE `ag_departments`;
LOAD DATA LOCAL
INFILE 'ag_imports/utf8-departments.csv'
INTO TABLE `PFX_ag_departments`
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

--
-- Load the product department placement table
--

TRUNCATE TABLE `ag_products_department`;
LOAD DATA LOCAL
INFILE 'ag_imports/utf8-product-department.csv'
INTO TABLE `PFX_ag_products_department`
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

--
-- Load the product tables from AzureGreen
--

-- The StockInfo table

TRUNCATE TABLE `ag_stockinfo`;
LOAD DATA LOCAL
INFILE 'ag_imports/utf8-stockinfo.csv'
INTO TABLE `PFX_ag_stockinfo`
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- The long descriptions

TRUNCATE TABLE `ag_descriptions`;
LOAD DATA LOCAL
INFILE 'ag_imports/utf8-descriptions.csv'
INTO TABLE `PFX_ag_descriptions`
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- The combined, though not always up-to-date, listing

TRUNCATE TABLE `ag_complete`;
LOAD DATA LOCAL
INFILE 'ag_imports/utf8-ag_complete_files.csv'
INTO TABLE `PFX_ag_complete`
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;


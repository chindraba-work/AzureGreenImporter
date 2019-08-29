# _AzureGreenImporter_

## Changelog

### v2.1.4

- Add small amount of progress reporting, esp. in image archive work
- Switch to use of `curl` over `wget`
- Switch to `https` for images, as AzureGreen now supports it
- Expand granularity on image archive names

### v2.1.3

- Handle image filenames with spaces in the image archives
- Handle image names in the `products` table with spaces in them
- Force the JPEG files to always use `.jpg` and force TIFF image files
  to be `.tif`

### v2.1.2

- Fix new products with no stock and active status

### v2.1.1

- Add process for scraping the AzureGreen website for images they have not yet supplied

### v2.1.0

- Make processing tables in the 'local' database persistent
- Removed key from the `staging_categories_new` table

### v2.0.0

- Completely replaced the system for reasons given in the README file
- Better trapping for oddities in the data supplied by AzureGreen
- Reduced the MySQL permissions needed on the hosted database
- Filtered images to only include new images in the upload pack
- Improved data handling across the board

### v1.1.1

- Add notice to README that version 1 will be dead

### v1.1.0

- Add the prefix conversion to the automated Install script

### v1.0.4

- Convert the SQL license blocks to hash mark syntax
- Make all Bash and SQL license blocks identical

### v1.0.3

- Remove spurious lines added in the license block edits

### v1.0.2

- Correct package name in license blocks

### v1.0.1

- Added anchor files, `empty.txt` to force the creation of needed directories.

### v1.0.0

- Initial release



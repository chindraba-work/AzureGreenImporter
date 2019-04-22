# Importing AzureGreen data

This packages contains the files scripts helpful in managing the updates from AzureGreen in Zen-Cart.

There are no _core_ file or database changes. There are, however,  requirements for the local computer.

The Installation process will add a single, empty, directory to the store’s admin directory. Several new tables are also added to the database.

## Requirements

### Zen-Cart store

On the server for the Zen-Cart store, you need to have:

- FTP access to the store’s admin directory
- Access to the store’s admin control panel, specifically `Admin -> Tools -> Install SQL Patches`
- Direct access to the store’s database. (**Not** using the in-store controls above.) Two options are:
 1. phpMyAdmin, supplied by the host
 2. Direct Command-line interface using the `mysql` client program.

### Local computer (by preference, a GNU/Linux system, or VM)

- The ability to execute `Bash` shell scripts
- A working version of `wget`
- Command-line access to a `Perl` interpreter
- Space to save, long-term, the files from AzureGreen
- An FTP client
- The ability to download files from AzureGreen’s wholesaler resource page

### Additional requirements

- You need to know the new name of your admin directory in the Zen-Cart store
- You need to know the database prefix, if any, applied to the database during installation

## Installation & setup

Download and unpack the file. (Reading this means you have probably done that already.)

Without moving or renaming any files, yet, run the `Install.sh` script in a Bash shell.

With the FTP client upload the local `public_html` directory to the root of the remote system. (All that is contained in this upload is a new directory, `ag_imports`, in the renamed admin directory. You can create that directory manually if you so choose.)

Move, or copy, the `AzureGreenImporter_workspace` directory to someplace where you can keep it permanently, and use it regularly. Please note:

- The directory will be nearly 1 GB after the first use !
- Most of the space is used by the image files from AzureGreen
- The apce requirement will only increase as new products, and images, are added by AzureGreen
- The directory can be renamed as you wish
- The file and folder names, as well as the layout, within the directory _**must**_ remain unchanged

Using your direct access to the database execute the `Install.sql` script:

### Using phpMyAdmin

- Select the database itself, not a table within it, from the tree in the left-hand panel
- Click on “Import” on the toolbar at the top of the right-hand panel
- Click the “Browse” button, and locate the `Install.sql` file on your computer
- Click on the “Go” button at the bottom of the page

### Using command-line access

- In the shell, be sure you are in the directory where you unpacked the files
- Enter `mysql -u <zen-user-name> -p -D <zen-database-name> -e 'source ./Install.sql'`

## Usage

## Images updates

1. Enter a shell
2. Change to the `AzureGreenImporter_workspace` directory (or the new name you have assigned it)
3. Enter the command `./refresh_images.sh`
4. Open your FTP client connected to your Zen-Cart store host
5. Upload the either the images folder, or the archive of the images.
 - The images folder is `AzureGreenImporter_workspace/import_images/public_html/images`
    1. In the FTP client, select the `public_html` directory in both the remote and local directory lists. (The remote directory could be named `htdocs`, or some other, but it is the “root” of the web site file system)
    2. Select, and upload the `images` directory, selecting the “overwrite all” option if needed.
  - The images archive is `AzureGreenImporter_workspace/import_images/new_images.tar.gz`
    1. Upload that file to a convenient spot in your hosted file system.
    2. Open the File Manager in the `cPanel` access to the hosted system.
    3. Find, and right-click on the uploaded file
    4. Select “Extract”.
    5. For the destination, set it to the directory _ABOVE_ the `public_html` directory. Commonly, in cPanel, this will be the root, i.e.: `/`
    6. Click on “Extract file(s)”

The processing of the images will take a few minutes. The first time they are downloaded from AzureGreen will be slow. Future downloads shouldn’t take as long since they will not update all the files at once.

The speed of your local computer will determine how long it takes to sort and classify the collected images.

The uploading of the images to the host will be about the same every time it is done.

To save your important time, after processing the images locally, after step 3, check the dates on the zip files in the `AzureGreeImporter_workspace/ag_images` directory. If there are no new files there, nothing else will have changed and you can stop working on the images.

## Stock information updates

1. Enter a shell
2. Change to the `AzureGreenImporter_workspace` directory (or the new name you have assigned it)
3. Enter the command `./refresh_data.sh`
4. Open your FTP client connected to your Zen-Cart store host
5. Upload the `.csv` files in `AzureGreenImporter_workspace/import_files/` to `public_html/YOUR_ADMIN/ag_imports`
6. In your Zen-Cart admin, go to `Admin -> Tools -> Install SQL Patches`
7. At the bottom of the page, in the box labeled “Upload file:” click on the “Choose file” button
8. Locate and select the `AzureGreenImporter_workspace/load_ag_files.sql` file
9. Click on the “Upload” button on the right side of the page.
10. At the top of the bage, a notification bar should appear with the notice of “10 statements processed.”
11. Using your direct access to the database, execute the `import_ag_data.sql` script. (Use the same process as given above for installation.)
12. Check the `acquired_anomalies` table for unusual occurrences detected by the script (mostly AxureGreen names that do not fit within the limits of Zen-Cart names.)
13. That table is not read by the script, it is merely appended to as an aid to locating problems with the import process.
14. Using the `changes.xls` file from AzureGreen is the best way to know what should be changed, and you can verify the new item information by viewing the store itself.

## Wrap up

There is no need to remove, delete, or rename any of the files or tables created locally or on the server during the refresh process. Each time the refresh scripts are run they will create fresh copies of the information, removing any old versions as needed. This includes the tables of the database used during the loading and importing of data.

The files in the original package which are outside the `AzureGreenImporter_workspace` directory are used for installation, and can be removed from your computer once that is done.

Keeping the `.zip` files downloaded from AzureGreen is not required, but it is a _very_ good idea. The refresh scripts check the timestamp on the local files and only download new versions when available. For the data files, the size is small enough that you will not likely notice a difference. The images, however, are a large collection of large files, and the time to download all of them, every time, can be rather long.

The data files are also updated almost daily by AzureGreen, so a comparison version usually would not make a difference. The images files can be more than four months between updates, and that can be a huge savings on your personal time.


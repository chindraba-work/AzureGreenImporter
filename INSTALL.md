# Importing AzureGreen data

This packages contains the files scripts helpful in managing the updates from AzureGreen in Zen-Cart.

There are no _core_ file or database changes. There are, however,  requirements for the local computer.

The Installation process will add a single, empty, directory to the store’s admin directory. Several new tables are also added to the database.

## Requirements

### Zen-Cart store

On the server for the Zen-Cart store, you need to have:

- FTP access to the store’s admin directory
- Direct access to the store’s database. (**Not** using the in-store admin control Import SQL Patch tool.) Two options are:
   1. phpMyAdmin, supplied by the host, or
   2. Direct Command-line interface using the `mysql` client program.

### Local computer (by preference, a GNU/Linux system, or VM)

- The ability to execute `Bash` shell scripts
- A working version of `curl`
- Command-line access to a `Perl` interpreter
- Space to save, long-term, the files from AzureGreen
- An FTP client
- The ability to download files from AzureGreen’s wholesaler resource page (Internet access)

_[The shell script is written in Bash script and uses "Bashisms" which limits its operation in most other Unix, or non-Linux shells (such as Windows PowerShell).]_

## Installation & setup

Download and unpack the file. (Reading this means you have probably done that already.)

1.  Copy the 4 files, `ag_*`, to a directory of your choice
  -  Create a symbolic link to the `ag_update.sh` file in your path, if that file is not in your path
2.  Create a directory on the local machine where the commands and data will be kept
3.  Ensure that the live database has no products or categories added to it
4.  Import the install.sql into your empty database
5.  Copy the needed tables from the live database to the database where the work will be done. This can be done using phpMyAdmin, or any other tool of choice, so long as the entire set of data is copied. The tables to copy are:
  -  `categories`
  -  `categories_description`
  -  `meta_tags_categories_description`
  -  `meta_tags_products_description`
  -  `products`
  -  `products_description`
  -  `products_to_categories`

Using your direct access to the database execute, or import, the `install.sql` script:

### Using phpMyAdmin

- Select the database itself, not a table within it, from the tree in the left-hand panel
- Click on “Import” on the toolbar at the top of the right-hand panel
- Click the “Browse” button, and locate the `install.sql` file on your computer
- Click on the “Go” button at the bottom of the page

### Using command-line access

- In the shell, be sure you are in the directory where you unpacked the files
- Enter `mysql -u <zen-user-name> -p -D <zen-database-name> -e 'source ./install.sql'`



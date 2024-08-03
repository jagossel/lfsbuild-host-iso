# lfsbuild-host-iso

An archiso profile designed to contain the bare minimum tools to build Linux
From Scratch 12.1.

## Prerequisites

Minimum requirements:
 - 1GB of RAM
 - 10GB of storage
 - Arch Linux installed with the following packages
   - archiso: Tool used to create live Arch Linux CDs, usually used for Arch
     Linux installations.  This repository is a custom profile to provide a
     bare minimum building environment for Linux from Scratch 12.1.
   - jq: There is a JSON config file that will have to be created for the
     time being.  JQ is a JSON querying tool.
   - wget: WGet is used because the parameter names are more straight-forward
     then curl.  WGet will be used to download the source archive files that
     will be stored in the ISO itself.

It is possible to have VM built for the archiso tool and these scripts; that is
how this script was tested.  It is highly recommended to create another VM to
test the ISO file in, and make sure it boots up properly.

## Configuration

The script checks to see if the configuration JSON file exists; and if it does
not, it will create one to be edited manually before running the script again.
It is possible to create one manually.  The file will have to be saved in
`src/data/config.json`, with the following structure:

``` JSON
{
  "workingDirectoryPath": "",
  "outputDirectoryPath": ""
}
```

`workingDirectoryPath` is the temporary path that archiso will be building
the file system for the ISO in.

`outputDirectoryPath` is the folder where the ISO will be created in after
archiso builds the file system.

## Executing

After the configuration JSON has been created, simply point the current
working directory to the `src` folder, and execute the script,
`mkiso.sh` in BASH:

``` BASH
./mkiso.sh
```

Or for any other shell:

``` sh
bash ./mkiso.sh
```

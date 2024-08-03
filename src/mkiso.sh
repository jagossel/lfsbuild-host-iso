#!/bin/bash

bail () {
	echo >&2 "$@"
	exit 1
}

ScriptRootPath=$( dirname "$( readlink -f $0 )" )
DataRootPath="$ScriptRootPath/data"
if [ ! -d "$DataRootPath" ]; then
	bail "Cannot find the data folder, $DataRootPath."
fi

ConfigPath="$DataRootPath/config.json"
if [ ! -f "$ConfigPath" ]; then
	(echo '{"workingDirectoryPath":"","outputDirectoryPath":""}' | jq ".") > $ConfigPath
	bail "Configuration JSON created; please edit: $ConfigPath"
fi

WorkingDirectoryPath=$( cat $ConfigPath|jq -r .workingDirectoryPath )
if [ ! -d "$WorkingDirectoryPath" ]; then
	bail "Cannot find the path, $WorkingDirectoryPath."
fi

OutputDirectoryPath=$( cat $ConfigPath|jq -r .outputDirectoryPath )
if [ ! -d "$OutputDirectoryPath" ]; then
	bail "Cannot find hte path, $OutputDirectoryPath."
fi

LogFilePath="$ScriptRootPath/mkiso.log"
if [ -f "$LogFilePath" ]; then
	rm -v $LogFilePath
fi

PackageSourcePath="$DataRootPath/package-source.csv"
if [ ! -f "$PackageSourcePath" ]; then
	bail "Cannot find the packages source data, $PackageSourcePath."
fi

PatchSourcePath="$DataRootPath/patch-source.csv"
if [ ! -f "$PatchSourcePath" ]; then
	bail "Cannot find the packages patch data, $PatchSourcePath."
fi

ProjectRootPath=$( dirname $ScriptRootPath )

ProfileFolderPath="$ProjectRootPath/lfsbuild"
if [ ! -d "$ProfileFolderPath" ]; then
	bail "Cannot find the profile path, $ProfileFolderPath."
fi

RootFileSystemPath="$ProfileFolderPath/airootfs"
if [ ! -d "$RootFileSystemPath" ]; then
	bail "Cannot find the archiso root path, $RootFileSystemPath."
fi

RootUserHomePath="$RootFileSystemPath/root"
if [ ! -d "$RootFileSystemPath" ]; then
	bail "Cannot find the root user home path, $RootUserHomePath."
fi

SourcesRootPath="$RootUserHomePath/sources"
if [ ! -d "$SourcesRootPath" ]; then
	mkdir -v $SourcesRootPath
fi

echo "Downloading source files..."
tail -n +2 $PackageSourcePath | while IFS="," read -r PackageName PackageVersion PackageSourceUrl PackageSourceMd5Hash
do
	PackageFileName=$(basename $PackageSourceUrl)
	PackagePath="$SourcesRootPath/$PackageFileName"
	if [ -f "$PackagePath" ]; then
		echo "Skipping: $PackageName ($PackageVersion) was already downloaded."
	else
		echo "Downloading and verifying $PackageName $PackageVersion..."
		wget --output-document=$PackagePath $PackageSourceUrl --append-output=$LogFilePath
		HashCheck=$(md5sum $PackagePath | grep -Po [0-9a-f]{32})
		if [ "$PackageSourceMd5Hash" != "$HashCheck" ]; then
			bail "$PackageName is not valid, expected $PackageSourceMd5Hash, but got $HashCheck."
		fi
	fi
done

tail -n +2 $PatchSourcePath | while IFS="," read -r PatchName PatchUrl PatchMd5Hash
do
	PatchFileName=$(basename $PatchUrl)
	PatchPath="$SourcesRootPath/$PatchFileName"
	if [ -f "$PatchPath" ]; then
		echo "Skipping: $PatchName was already downloaded."
	else
		echo "Downloading and verifying $PatchName..."
		wget --output-document=$PatchPath $PatchUrl --append-output=$LogFilePath
		HashCheck=$(md5sum $PatchPath|grep -Po [0-9a-f]{32})
		if [ "$PatchMd5Hash" != "$HashCheck" ]; then
			bail "$PatchName is not valid, expected $PatchMd5Hash, but got $HashCheck."
		fi
	fi
done

echo "Building the ISO file..."
mkarchiso -v -w $WorkingDirectoryPath -o $OutputDirectoryPath $ProfileFolderPath

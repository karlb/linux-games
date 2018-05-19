#!/usr/bin/perl

# Easy install script by Karl Bartel
# License: GPL
# Please give me feedback: karlb@gmx.net

use strict;

my @selected;

my $VERSION="1.0";
my ($BASE,$AGENDA_FTP);
    ### These are the "real" values
    $BASE="http://www.linux-games.com/agenda";
    $AGENDA_FTP='ftp.agendacomputing.com::ftp/agenda/dists/h2o/main/binary-vr3';
my $SCRIPT_UPDATE_URL="$BASE/ei.pl";
my $INSTALL_UPDATE_URL="$BASE/install";
my $LIST_UPDATE_URL="$BASE/package-list.ei";
my $VRPPREPFS_URL="$BASE/vrpprepfs";
my $VRP_INSTALL_FILE_URL="$BASE/install";
my $RSYNC='rsync -pzl';

my (@Name,@Section,@Description,@URL,@Importance,@Path,@Filename,@Elf);
my ($ListItems,$SNOW,$VRP_PATH,$IP,$ELF_VERSION,$romdisk);
my @file;
my @TEST_FILES=qw/package-list.ei install/;
my @AGENDA_FILE_LIST;

### conversion table for installation in the user flash space
my @USER_INSTALL_PATH=("root->ERROR",
		       "defaults->root",
		       "bin->usrlocalbin",
		       "usrbin->usrlocalbin",
		       "dev->ERROR",
		       "usrman->usrlocalman",
		       "lib->usrlocallib",
		       "usrlib->usrlocallib",
		       "share->usrlocalshare",
		       "usrshare->usrlocalshare",
		       "doc->usrlocaldoc",
		       "usrdoc->usrlocaldoc",
		       "sbin->usrlocalsbin",
		       "usrsbin->usrlocalsbin",
		       "usr->usrlocal",
		       );

my @VRP_PATH=("root->",
	      "bin->bin",
	      "usrbin->usr/bin",
	      "usrlocalbin->usr/local/bin",
	      "etc->etc",
	      "dev->dev",
	      "usrman->usr/man",
	      "usrlocalman->usr/local/man",
	      "lib->lib",
	      "usrlib->usr/lib",
	      "usrlocallib->usr/local/lib",
	      "usrshare->usr/share",
	      "usrlocalshare->usr/local/share",
	      "doc->doc",
	      "usrdoc->usr/doc",
	      "usrlocaldoc->usr/local/doc",
	      "sbin->sbin",
	      "usrsbin->usr/sbin",
	      "usrlocalsbin->usr/local/bin",
	      "log->log",
	      "usr->usr",
#	      "usrlocal->usr/local",
	      "usrlocal->flash/local",
	      );


###### get a list of files on the agenda ftp server ######
sub load_agenda_file_list
{
    if (!defined(@AGENDA_FILE_LIST)) {
	@AGENDA_FILE_LIST=`$RSYNC $AGENDA_FTP/`;
	foreach (@AGENDA_FILE_LIST) {
	    chop($_);
	    $_ =~ s/.*\ //;
	}
	shift(@AGENDA_FILE_LIST);
    }
}

###### read an application list file ######
sub read_list
{
    my ($i, $line, $start);

    $i = $ListItems;
    read_file("$_[0]");
    foreach (@file) {
	($start,$line)=split(/: /,$_);

	if ($start =~ /name.*/i) { $Name[$i]=$line; }
	if ($start =~ /sect.*/i) { $Section[$i]=$line; }
	if ($start =~ /desc.*/i) { $Description[$i]=$line; }
	if ($start =~ /impor.*/i) { $Importance[$i]=$line; }
	if ($start =~ /elf.*/i) { $Elf[$i]=$line; }
	if ($start =~ /url.*/i) { 
	
	    ### Get the real URL
	    $URL[$i]=$line;
	    $URL[$i] =~ s/BASE/$BASE/;
	    
	    ### Get the filename
	    my @URL_parts;
    
	    @URL_parts = split ( /\//, $URL[$i] );
	    while (@URL_parts) { $Filename[$i] = shift(@URL_parts) };
	}

	if ($start =~ /--.*/i) { 
	    $i++; 
	}
    }
    $ListItems=$i;
}

###### get a remote file ######
sub get
{
    if ( $_[1] =~ /$AGENDA_FTP/i ) {
	`$RSYNC $_[1] $_[0]`;
    } else {
	`wget -q -O $_[0] $_[1]`;
    }
    if (!exist($_[0]) ) {
	print "Couldn't get $_[1]. Exiting...\n";
	exit(1);
    }
}

###### update the script and data files ######
sub update
{
    if ($_[0] ne "direct-update") {
	print "** Updating package lists and easyinstall script **\n";
	`cp ei.pl ei.old`;
	get("ei.pl", $SCRIPT_UPDATE_URL);
	print `./ei.pl direct-update`;
	exit(0);
    }
    print "** Performing update **\n";
    get("recources/package-list.ei", $LIST_UPDATE_URL);
    get("recources/install", $INSTALL_UPDATE_URL);
    print "** Update finished **\n";
}

###### do all needed files exist? ######
sub test_lists
{
    if (!($_[0] =~ /direct-update/)) {
	foreach (@TEST_FILES) {
	    if (!open(FILE,"<recources/$_")) {
		print("** One or more required files not found. Forcing update. **\n");
	        update(@_);
	    } else {
		close(FILE);
	    }
	}
    }
}

###### does this file exist ######
sub exist
{
    my $dummy;

    if (!open(FILE,"<$_[0]")) {
	return(0);
    } else {
	read(FILE,$dummy,10);
	close(FILE);
	if ( !$dummy ) {
	    return(0);
	}
    }
    return(1);
}

###### exit if this file doesn't exist ######
sub exist_or_exit
{
    if (!exist($_[0])) {
	print("Required file ($_[0]) not found. Exiting...\n");
	exit(1);
    }
}

###### read a file and put the output to @file ######
sub read_file
{
    my $i=0;
    my $a=0;

    if (!open(FILE,"<@_")) { print("Could not open @_ !\n");exit(); }
    @file = <FILE>;
    foreach (@file) {
	$_ =~ s/\n//;
    }
    while ($file[$i]) {
	if ($file[$i] =~ /^#/) {
	    $file[$i] = "";
	    $a=$i;
	    while ($file[$a+1]) {
		$file[$a] = $file[$a+1];
		$a++;
	    }
	}
	$i++;
    }
    close(FILE);
}

###### write the content of the second parameter into this file ######
sub write_file
{
    if (!open(FILE,">$_[0]")) { print("Could not open $_[0] for writing!\n");exit(); }
    print FILE "$_[1]";
    close(FILE);
}

sub find_app
{
    my $i=0;

    chomp($_[0]);
    while ( !( $Name[$i] =~ /^$_[0]$/i ) ) {
	$i++;
	if ($i > $ListItems) {
	    chomp ($_[0]);
	    print "No program with this name found. ($_[0])\n";
	    return -1;
	}
	#print "$Name[$i] == $_[0] ?\n";
    }
    
    return $i;
}

sub get_package
{
    my $i=$_[0];

    if ($Elf[$i] =~ /all/) {
	$URL[$i] =~ s/\/$ELF_VERSION\//\//;
    }
    print "** Getting $Filename[$i] **\n";
    get("cache/$Filename[$i]","$URL[$i]");
    exist_or_exit("cache/$Filename[$i]");
    print "** Extracting $Filename[$i] **\n";
    if ( $Filename[$i] =~ /.vrp$/ ) {
	`tar xvf cache/$Filename[$i]`;
    } else {
	`tar xvfz cache/$Filename[$i]`;
    }
}

sub change_vrp_for_local_install
{
    my ($from,$to);
    
    foreach (@USER_INSTALL_PATH) {
	($from,$to) = split (/->/, $_);
	$from.=".tar.gz";
	$to.=".tar.gz";
	if (exist($from)) {
	    if ($to =~ /ERROR/) {
		print "ERROR: Sorry, this .vrp can only be installed in a romdisk!\n";
		exit(1);
	    }
	    `mv $from $to`;
	}
    }
}

sub local_path
{
    my $path = $_[0];

    $path =~ s/defaults/flash/;
    $path =~ s/usr/flash\/local/;
    return $path;
}

sub path_to_root
{
    my $arg = $_[0];
    my $ret;
    
    $arg =~ s/^\///;
    while ($arg =~ /\//) {
	$ret .= "../";
	$arg =~ s/\///;
    }
    
    return $ret;
}

sub create_links
{
    ### Generating Links ###
    if (exist("newlinks")) {
	read_file("newlinks");
	foreach (@file) {
	    my @part = split(/ /,$_);
	    $part[0] = local_path($part[0]);
	    $part[0] =~ /(.*)\/.*?/;
	    `mkdir -p extracted_vrps$1`;
	    my $source = `cd extracted_vrps; find -type f -name $part[1]`;
	    $source =~ s/\n//;
	    $source =~ s/^\.//;
	    $source = path_to_root($part[0]).$source;
	    $part[0] = "./extracted_vrps".$part[0];
	    `ln -s $source $part[0]`;
	}
    }
}

sub create_icons
{
    if (exist("newicons")) {
	my $iconlines;
	read_file("newicons");
	foreach (@file) {
	    my @part = split(/;/,$_);
	    my $source = `cd ./extracted_vrps; find -type f -name $part[1]`;
	    $source =~ s/^\.//;
	    $source =~ s/\n//;
	    $iconlines .= "$part[0];$source\n";
	}
	write_file("iconlines",$iconlines);
    }
}

sub merge_icons
{
    my $newfile;

    read_file("iconlines");
    my @newicons = @file;
    read_file(".icons");
    my @icon = @file;
    foreach (@newicons) {
	my $newline = $_;
	my ($newicon) = split(/;/ , $newline);
	my $i=0;
	my $placed = "";
	foreach (@icon) {
	    if ($_ =~ /$newicon/)  {
		if ($placed eq "") {
		    $_ = $newline;
		    $placed = "yes";
		} else {
		    $_ = "";
		}
	    }
	}
	if (!$placed) {
	 $newfile .= $_."\n";
	}
    }
    foreach (@icon) {
	if ($_ ne "") {
	    $newfile .= $_."\n";
	}
    }
    write_file(".icons",$newfile);
}

sub extract_vrp
{
    my ($from,$to);
    
#    mkdir("extracted_vrps");
    foreach (@VRP_PATH) {
	($from,$to) = split (/->/, $_);
	$from.=".tar.gz";
	if (exist($from)) {
	    if ($to eq "") {
		$to="./";
	    }
	    `mkdir -p extracted_vrps/$to`;
	    `cd extracted_vrps; tar xvfz ../$from -C $to`;
	}
    }
}

sub install_vrp
{
    my $i=$_[0];

    print "** Preparing for sync **\n";
    change_vrp_for_local_install();
    extract_vrp();
}

sub install_ei
{
    my $bin_path = "extracted_vrps/usr/bin";
    my $pixmap_path = "extracted_vrps/usr/share/pixmaps";

    if ($romdisk eq "") {
	$bin_path = local_path($bin_path);
	$pixmap_path = local_path($pixmap_path);
    }

    my $i=$_[0];
    if (exist("$Name[$i]/$Name[$i]")) {
	copy("$Name[$i]/$Name[$i]","$bin_path/$Name[$i]");
    }
    if (exist("$Name[$i]/$Name[$i].xpm")) {
	copy("$Name[$i]/$Name[$i].xpm","$pixmap_path/$Name[$i].xpm");
	write_file("newicons","$Section[$i]/$Name[$i];$Name[$i].xpm");
	write_file("newlinks","/defaults/home/default/.wmx/$Section[$i]/$Name[$i] $Name[$i]");
    }
}

sub create_uninstall
{
    if ($romdisk) {
	return;
    }

    my $i = $_[0];
    my $files = `du -a extracted_vrps`;
    my @files = split(/\n/,$files);
    my $path = "extracted_vrps/defaults/home/default/.uninstall";
       $path = local_path($path);
    my $newfile = "#!/bin/sh\nrm -f";
    
    foreach (@files) {
	$_ =~ s/^.*extracted_vrps//;
	$newfile .= " ".$_;
    }

    `mkdir -p $path`;
    my $abs_path = $path;
    $abs_path =~ s/extracted_vrps//;
    $newfile .= " $abs_path/$Name[$i]\nreturn 0\n";
    write_file("$path/$Name[$i]",$newfile);
    `chmod a+x $path/$Name[$i]`;
}

sub install
{
    my ($i,$dummy);
    my $COMMAND = "cd extracted_vrps; $RSYNC -r ./ $IP\:\:root/ 2>&1";

    $i=find_app($_[0]);
    if ($i<0) {return;}
    print "** Installing $Name[$i] **\n";
    if (!(($Elf[$i] =~ /$ELF_VERSION/) || ($Elf[$i] =~ /all/))) {
	print("No binary for your ELF version ($ELF_VERSION) available. Sorry.");
	return;
    }
    get_package($i);
    print "Please connect your agenda with the workstation. Press enter when you're ready.\n";
    $dummy = <stdin>;
    if ($URL[$i] =~ /.vrp$/) {
	install_vrp($i);	
    } else {
	install_ei($i);
    }
    create_links();
    create_icons();
    create_uninstall($i);
    `chmod -R a+rw extracted_vrps`;
    print "** Rsyncing $Name[$i] **\n";
    my @shellout=`$COMMAND`;
    foreach (@shellout) {
	if (!($_ =~ /read-only/i)) {
	    print "$_";
	}
    }
    if (exist("newicons")) {
	print "** Adding launchpad entry **\n";    
	`$RSYNC $IP\:\:default/.wmx/.icons .icons`;
	merge_icons();
	`$RSYNC .icons $IP\:\:default/.wmx/.icons`;
    }
    print "** Installation finished **\n";
    print "** Removing temporary files **\n";
    $dummy = <stdin>;
    `rm -fr *.tar.gz extracted_vrps install newlinks newicons iconslines`;
}

sub remove
{
    my ($i,$dummy);

    $i=0;
    while ( !( $Name[$i] =~ /$_[0]/i ) ) {
	$i++;
	if ($i > $ListItems) {
	    print "No program found. ($_[0])\n";
	    return;
	}
    }
    print "Please connect your agenda with the workstation. Press enter when you're ready.\n";
#    $dummy = <stdin>;
    print "** Removing not implemented, yet.**\n";
#    print "** Removing $_[0] (binary) **\n";
#    `$RSYNC --delete $_[0] agenda::root/home/default/.wmx/$Section[$i]/$_[0]`;
#    print "** Removing $_[0].xpm (icon) **\n";
#    `$RSYNC --delete $_[0].xpm agenda::root/usr/local/lib/$_[0].xpm`;
#    print "** Removing launchpad entry **\n";    
#    `$RSYNC agenda::root/home/default/.wmx/.icons .icons`;
#    add_icon($i,"delete");
#    `$RSYNC .icons agenda::root/home/default/.wmx/.icons`;
}


#------------------------------------------------------

sub add_vrp
{
    my $i=find_app($_[0]);
    if ($i<0) {return;}
    
    $selected[$i]="yes";
    print "$Name[$i] added";
}

sub remove_vrp
{
    my $i=find_app($_[0]);
    if ($i<0) {return;}

    $selected[$i]="";
    print "$Name[$i] removed";
}

sub parse_user_input
{
    if ($_[0] =~ /help/i ) {
	print "list available 	 -- lists the available apps\n";
	print "list installed    -- lists all vrps that will be installed\n";
	print "install [appname] -- selects the requested app for installation\n";
	print "remove  [appname] -- removes the requested app from installation\n";
	print "quit         	 -- exits without building a romdisk\n";
	print "build        	 -- builds the romdisk\n";
    }
    elsif ($_[0] =~ /^quit/i ) {
	exit(0);
    }
    elsif ($_[0] =~ /^exit/i ) {
	exit(0);
    }
    elsif ($_[0] =~ /^install/i ) {
	my @parts=split(/\ /,$_[0]);
	shift(@parts);
	foreach (@parts) {
	    add_vrp($_);
	}
    }
    elsif ($_[0] =~ /^remove/i ) {
	my @parts=split(/\ /,$_[0]);
	shift(@parts);
	foreach (@parts) {
	    remove_vrp($_);
	}
    }
    elsif ($_[0] =~ /^list available/i ) {
	my $i=0;
	my $name;
	foreach (@Name) {
	    if (!$selected[$i]) {
		$name=$_;
		while (length($name) < 20) {
		    $name.=" ";
		}
		print "$name -- $Description[$i]\n";
	    }
	    $i++;
	}
    }
    elsif ($_[0] =~ /^list installed/i ) {
	my $i=0;
	my $name;
	foreach (@Name) {
	    if ($selected[$i]) {
		$name=$_;
		while (length($name) < 20) {
		    $name.=" ";
		}
		print "$name -- $Description[$i]\n";
	    }
	    $i++;
	}
    }
    else {
	print "Unknown command: $_[0]\n";
    }
}

sub select_default
{
    my (@files,$i,$input);
    
    print "Enter the importance level for apps you want to be installed by default\n";
    print "( 0 = all available apps ; 50 = small, but usable ; 100 = only the raw linux)\n";
    $input = <stdin>;
    
    $i=0;
    foreach (@Name) {
	if ( $Importance[$i] < $input ) {
	    $selected[$i]="";
	} else {
	    $selected[$i]="yes";
	}
	$i++;
    }
    
    print "** default apps selected **\n";
}

sub copy
{
    ### create dir
    my $to=$_[1];
    if ( $to =~ /\// ) {
	while (!( $to =~ /\/$/ )) {
	    $to =~ s/.$//;
	}
	`mkdir -p $to`;
    }
    
    ### copy
    `cp $_[0] $_[1]`;
}

sub modify_defaults
{
    `tar xf cache/defaults*.vrp; tar xvfz root.tar.gz; rm -f *.tar.gz`;
}

sub install_selected_programs
{
    my $i=0;
    my $from;
    
    print "** Getting .vrps **\n";
    for ($i=0; $i<$ListItems; $i++) {
    	if ($selected[$i]) {
	    get_package($i);
	    extract_vrp($i);
	}
    }
}

###### help the poor user building a romdisk ######
sub guide
{
    my $dummy;

    if (`whoami` ne "root\n") {
	print "You need to be root in order to create a romdisk.\n";
	exit(1);
    }
    
    print "Welcome to easyinstall $VERSION romdisk builder!\n";
    print "I'll try to help building a romdisk.\n";
    print "Press ctrl-c when you don't want to continue.\n";
    select_default();
    print "Now you can select which apps you want to have installed.\n";
    print "Type help for help\n";
    do {
	print "\n> ";
	$dummy = <stdin>;	
	parse_user_input($dummy);
    } while ($dummy ne "build\n");
    install_selected_programs();
    ### add XIP etc
    get("vrpprefs", $VRPPREPFS_URL);    
    `cd extracted_vrps; sh ../vrpprefs`;
    print "** Now I'll call mkcramfs to build the romdisk **\n";
    `mkcramfs extracted_vrps root.cramfs`;
#    rename("selected/root.cramfs","root.cramfs");
    print "** Romdisk built - Happy flashing! **\n";
#    `rm -fr usrbin usrshare`;
    `rm -f *.tar.gz install vrpprefs extracted_vrps`;
}

###### Convert an easyinstall package to a .vrp package ######
sub ei2vrp
{
    ### get package
    my $i=find_app($_[0]);
    if ($URL[$i] =~ /.vrp$/) {
	print "$Name[$i] is already a .vrp! Exiting...\n";
	exit(1);
    }
    get_package($i);

    ### create dirs
    `mkdir -p usrbin usrshare`;
        
    ### copy files to vrp-typical places
    if ( exist("$Name[$i]/$Name[$i]") ) {
        copy("$Name[$i]/$Name[$i]","usrbin/$Name[$i]");
    }
    if ( exist("$Name[$i]/$Name[$i].xpm") ) {
        copy("$Name[$i]/$Name[$i].xpm","usrshare/pixmaps/$Name[$i].xpm");
#        add_icon($i,"vrp");
#        symlink("/usr/bin/$Name[$i]","defaults/home/default/.wmx/$Section[$i]/$Name[$i]");
    }
    
    ### create vrp
    my $tars;
    if (`ls usrbin` ne "") {
	`cd usrbin; tar cvfz usrbin.tar.gz *`;
	link("usrbin/usrbin.tar.gz","usrbin.tar.gz");
	$tars.=" usrbin.tar.gz";
    }
    if (`ls usrshare` ne "") {
	`cd usrshare; tar cvfz usrshare.tar.gz *`;
	link("usrshare/usrshare.tar.gz","usrshare.tar.gz");
	$tars.=" usrshare.tar.gz";
    }
    link("recources/install","install");
    `tar cvf $_[0].vrp $tars install`;

    ### remove temporary files
    `rm -fr $Name[$i] *.tar.gz install`;
    `rm -fr usrbin usrshare root`;
    
    print "** vrp built **\n";
}

###### parse the command line options and execute the correct commands ######
sub parse_command_line
{
    my ($i,$dummy);

    if ($_[0] =~ /romdisk/i ) {
#	do {
#	    print "Do you want to use a SNOW romdisk?";
#	    $dummy = <stdin>;
#	} while ( ($dummy ne "no\n")&&($dummy ne "n\n")&&($dummy ne "yes\n")&&($dummy ne "y\n") );
#	if ( ($dummy eq "no\n")||($dummy eq "n\n") ) {
#	    $SNOW="";
#	    $VRP_PATH="vrps";
#	    read_list("recources/agenda-vrp-list.ei");
#	    read_list("recources/package-list.ei");
#	} else {
#	    $SNOW="yes";
#	    $VRP_PATH="SNOWvrps";
#	    read_list("recources/snow-vrp-list.ei");
#	}
#	guide();
#	return;
    } else {
#        read_list("recources/agenda-vrp-list.ei");
	if (!($_[0] =~ /direct-update/i )) {
	    read_list("recources/package-list.ei");
	}
    }

    if ($_[0] =~ /list/i ) {
	for ($i=0;$i<$ListItems;$i++) {
	    if ( ($Section[$i] =~ /$_[1].*/i) && (($Elf[$i] =~ /$ELF_VERSION/) || ($Elf[$i] =~ /all/)) ) {
		$dummy=$Name[$i];
		while (length($dummy) < 15) {
		    $dummy.=" ";
		}
		print "$dummy  --  $Description[$i]\n";
	    }
	}
    }
    elsif ($_[0] =~ /install/i ) {
	shift(@_);
	foreach (@_) {
	    install($_);
	}
    }
    elsif ($_[0] =~ /remove/i ) {
	shift(@_);
	foreach (@_) {
	    remove($_);
	}
    }
    elsif ($_[0] =~ /ei2vrp/i ) {
	shift(@_);
	foreach (@_) {
    	    ei2vrp($_);
	}
    }
    elsif ($_[0] =~ /clean/i ) {
	`rm -fr usrbin usrshare`;
	`rm -f *.tar.gz *.vrp install`;
    }
    elsif ($_[0] =~ /direct-update/i ) {
	update("direct-update");
    }
    elsif ($_[0] =~ /update/i ) {
	update();
    }
    elsif ( ($_[0] =~ /-h/i ) || ($_[0] =~ /help/i ) ) {
	print "\n";
	print "Syntax:    ./ei.pl [command]\n";
	print "\n";
	print "Command list:\n";
	print "list              -- lists all available apps\n";
	print "install [appname] -- installs the requested app\n";
	print "update            -- update package list and script\n";
#	print "romdisk           -- helps building a romdisk\n";
	print "ei2vrp [appname]  -- create a vrp out of the ei package\n";
	print "\n";
    } else {
	print "Unknown Command: $_[0]\n";
    }
}


###### Take care of the user's configuration ######
sub conf
{
    if ( exist("recources/ei.conf") ) {
	read_file("recources/ei.conf");
	shift(@file);
	$IP = shift(@file);
	$ELF_VERSION = shift(@file);
    } else {
	print "** Staring Configuration **\n";
	print "Please enter your agenda's hostname or IP address\n";
	$IP = <stdin>;
	chop($IP);
	print "Please connect your agenda, so I can detect you ELF version.\n";
	$ELF_VERSION = <stdin>;
	`rm -f cache/release`;
	`$RSYNC $IP\:\:root/etc/release cache/release`;
	read_file("cache/release");
	$ELF_VERSION = shift(@file);
	if (($ELF_VERSION =~ /SNOW/)||($ELF_VERSION =~ /h2o/) ) {
	    $ELF_VERSION =~ s/.* Linux\ //;
	    $ELF_VERSION =~ s/S.*//;
	} else {
	    $ELF_VERSION = "SVR4";
	}
	print "The following ELF Version has been detected: $ELF_VERSION\n";
	write_file("recources/ei.conf","$VERSION\n$IP\n$ELF_VERSION\n");
	print "** Configuration finished **\n";
    }
    $BASE .= "/".$ELF_VERSION;
}

########################  Main program starts here #############################

### create backup
`cp ei.pl ei.backup`;

### Init
$ListItems=0;
mkdir("recources");
mkdir("cache");

### Is everything we need OK ?
conf();
test_lists(@ARGV);

### Let's see what the user want's and execute it!
parse_command_line(@ARGV);

### One newline at the end looks nice
print "\n";



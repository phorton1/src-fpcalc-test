#!/usr/bin/perl
#------------------------------------------
# gen_results.pm
#
#    This script calls specific versions and platforms
#    of the fpcalc executable to generate text files for
#    use with compare_results.pm.
#
#    There is also a Android java project that generates
#    such text files for android builds of fpcalc.
#
#--------------------------------------------------
#
# This file is (c) Copyright 2015 - Patrick Horton.
#
# It is released under the GNU Public License Version 2,
# and you are free to modify it as you wish, as long as
# this header, and the copyright it contains are included
# intact in your modified version of the this file.
#
# Please see COPYING.GPLv2 for more information.

use strict;
use warnings;
use utf8;
# no utf8; does not appear to make any difference
use appUtils qw(display error warning $logfile);
use fpDecompress;
use Digest::MD5 'md5_hex';

# disable appUtils logging
$logfile = "";

# this is a case insensitive RE for file(s) that will be
# taken from the directory scan, and if set, no output
# file will be created.

my $do_one_filename = "";
	# 'albums\/Blues\/New\/Blues By Nature - Blue To The Bone\/01 - Cadillac Blues\.mp3';
		# working test case

    # "singles\/Rock\/Alt\/Modest Mouse - Interstate 8\/Broke\.mp3";
		# SAVED AS multi-test/data/test_bad.mp3
        # this one crashes 0.9 win builds
        # and caused orig_x86 to say "could not open file"
        # all other platforms/builds returned various "missing header"
        # and "warning decoding audio" messages, but still returned
        # fingerprints.

    # 'albums\/Compilations\/Various - Unknown/If I Had .1000000|' .
    # 'albums\/Favorite/Dan Hicks & the Acoustic Warriors - Shootin\' Straight\/15 - .100,000\.mp3|'.
    # 'albums\/Rock\/Alt\/Soul Coughing - El Oso\/08 - .300 Soul\.wma';
        # These failed on orig_ubuntu (x86line) and host_x86 builds
        # because $ signs have to be escaped to be passed to the
        # shell in filenames. They *probably* fails from arm command
        # line "orig_arm" builds as well.  As expected, these work
        # fine from a directory scan in Java.

    #'albums\/Compilations\/Various - Unknown/Wild.*\.MP3';
        # Windows Perl returns "WILDTH~1.MP3",
        # Even tho windows shell shows "Wild Thing - Tone-L?c.mp3"
        #     where the ?=o with a line or two dots over it ..
        # Ubuntu Perl returns "Wild Thing - Tone-L?ìc.mp3"
        #     where the ?=a frame "cross" character.
        # x86 java returns the correct UTF8 string and uses it ok.
        # The arm7s build may have crashed cuz no file found.


my $SHOW_ONE_FILENAME_RESULTS = 1;
    # Set to 1 to see the results of the two "one_filename" calls
    # (the version and the fingerprint for the file(s))
    # Set to 0 for easier to read display when just checking
    # if programs work


# my particular platform identification
# and assignment of working directories

my $ext_storage = $ENV{EXTERNAL_STORAGE} || '';
    # only used here for platform identification

my $HOST_ID =
    defined($ENV{WINDIR}) ? "win" :
    $ext_storage =~ /^\/mnt\/sdcard$/ ? "arm" :
    "x86";

my $input_dir =
    $HOST_ID eq "arm" ? "/mnt/usb_storage2/mp3s" :
    $HOST_ID eq "x86" ? "/media/sf_ccc/mp3s" :
    "/mp3s";

my $results_dir = $input_dir;
my $install_dir = ($HOST_ID eq "x86" ? '~' : '').
    "/src/fpcalc/_install";


#------------------------------------------
# table of programs to be run
#------------------------------------------
# will be filtered by $HOST_ID

my @programs = (

# run on windows

    fpcalc_orig_win => "/base/apps/artisan/bin/fpcalc_orig_win.exe",
        # rerun

    "fpcalc_linux_win.0.9"   => "$install_dir/0.9/_linux/win/fpcalc.exe",
    "fpcalc_win_win.0.9"     => "$install_dir/0.9/_win/win/fpcalc.exe",
    "fpcalc_linux_win.0.11"  => "$install_dir/0.11/_linux/win/fpcalc.exe",
    "fpcalc_win_win.0.11"    => "$install_dir/0.11/_win/win/fpcalc.exe",
    "fpcalc_linux_win.2.7"   => "$install_dir/2.7/_linux/win/fpcalc.exe",
    "fpcalc_win_win.2.7"     => "$install_dir/2.7/_win/win/fpcalc.exe",

# run on linux

    "fpcalc_host_x86.0.9"    => "$install_dir/0.9/_linux/host/fpcalc",
    "fpcalc_host_x86.0.11"   => "$install_dir/0.11/_linux/host/fpcalc",
    "fpcalc_host_x86.2.7"    => "$install_dir/2.7/_linux/host/fpcalc",
    "fpcalc_orig_x86"        => "/usr/bin/fpcalc",
        # i'm thinking that my orig0 and orig1 ubuntu's were actually
        # arm runs with different versions of old gen_testresults.pm,
        # maybe with slight differences to decoding fingerprints or something.
        # but now I'm not sure, so re-running orig ubuntu as well

# run on car stereo

    fpcalc_orig_arm => "/usr/bin/fpcalc",

);


#----------------------------------------
# Routines
#----------------------------------------

sub get_program_text
{
    my ($id,$exe,$path) = @_;
    display(0,0,"get_program_text($id,$path)");

    # escape $'s in filenames on x86 platform ...

    if ($HOST_ID =~ /x86/)
    {
        $path =~ s/\$/\\\$/g;
    }

    my $options = $id =~ /_orig/ ? "" : "-md5 -stream_md5 -ints";
    my $text = `$exe $options "$path" 2>&1`;
    $text ||= "NO RESULTS from $exe $path\n";
    if ($text =~ /fingerprint=(.*?)(\s|$)/is)
    {
        my $fingerprint = $1;

        # if the host is an original executable
        # add the fingerprint_md5 and fingerprint_ints

        if ($id =~ /_orig/)
        {
            display(9,1,"getting fingerprint_md5 and fingerprint_ints");
            $text .= "fingerprint_md5=".md5_hex($fingerprint)."\n";
            my $ints = fpDecompress->Decompress($fingerprint);
            if (!$ints)
            {
                error("Could not decompress fingerprint $exe($path)");
            }
            elsif (@$ints < 10)
            {
                error("only found ".scalar(@$ints)."<10 in fingerprint $exe($path)");
            }
            else
            {
                $text .= "fingerprint_ints=".join(',',@$ints)."\n";
            }
        }
    }
    else
    {
        error("No fingeprint in $exe($path)");
    }

    return $text;
}




sub do_one_run
{
    my ($paths,$id,$exe,$check_version) = @_;
    display(0,0,"do_one_run($id,$exe) ffmpeg($check_version)");

    # get the version information first

    my $ffmpeg_version = "";
    my $version_info = `$exe "-version" 2>&1`;
    $ffmpeg_version = $1
        if ($version_info =~ /ffmpeg_version=(.*?)(\s|$)/is);
    $ffmpeg_version =~ s/"//g;
    $ffmpeg_version =~ s/^n//;
	$ffmpeg_version =~ s/-.*$// if $ffmpeg_version =~ /^2.7/;

    if ($ffmpeg_version && $check_version && $ffmpeg_version ne $check_version)
    {
        error("version mismatch calling $exe\nexpected $check_version, but exe returned $ffmpeg_version");
        return 0;
    }
    display(0,1,"version_info=$version_info")
        if $do_one_filename && $SHOW_ONE_FILENAME_RESULTS;


    # normal case, do all the paths in @$paths
    # open the output file and dump the version_info

    display(0,1,"doing ".scalar(@$paths)." paths");

    if (!$do_one_filename)
    {
        my $filename = "$results_dir/$id.txt";
        if (-f $filename)
        {
            warning(0,1,"FILE ALREADY EXISTS (skipping): $filename");
            return 1;
        }
        if (!open(OFILE,">$filename"))
        {
            error("Could not open $filename for writing");
            return 0;
        }
        print OFILE $version_info."\n\n";
    }

    # LOOP THRU PATHS

    my $num = 0;
    my $count = 100000;
    for my $path (@$paths)
    {
        # utf8::downgrade($path) if !$ANDROID;
        my $text = get_program_text($id,$exe,$path);
        if ($do_one_filename)
        {
            display(0,0,"result=$text")
                if $SHOW_ONE_FILENAME_RESULTS;
        }
        else
        {
            print OFILE "\n\n$id($path)\n";
            print OFILE $text."\n\n";
        }
        last if (--$count <= 0);
    }
    close OFILE if !$do_one_filename;
    return 1;

}   # do_one_run



sub get_paths
{
    my ($dir,$paths,$level) = @_;

    $level ||= 0;
    $paths ||= [];

    my @subdirs;

    if (!opendir(DIR,$dir))
    {
        error("Could not opendir $dir");
        exit 1;
    }
    while (my $entry = readdir(DIR))
    {
        next if $entry =~ /^(_|\.)/;
        if (-d "$dir/$entry")
        {
            push @subdirs,$entry;
        }
        elsif (myMimeType($entry))
        {
            push @$paths,"$dir/$entry"
                if (!$do_one_filename ||
                    "$dir/$entry" =~ /$do_one_filename/i);
        }
    }
    closedir DIR;

    for my $subdir (@subdirs)
    {
        get_paths("$dir/$subdir",$paths,$level+1);
    }

    return $paths;
}



sub myMimeType
{
    my ($filename) = @_;
    return 'audio/mpeg'         if ($filename =~ /\.mp3$/i);	# 7231
    return 'audio/x-m4a'        if ($filename =~ /\.m4a$/i);    # 392
	return 'audio/x-ms-wma'     if ($filename =~ /\.wma$/i);    # 965
	return 'audio/x-wav'        if ($filename =~ /\.wav$/i);    # 0
	# mp4 files are not currently scanned
	# return 'audio/mp4a-latm'    if ($filename =~ /\.m4p$/i);
    return '';
}






#----------------------------------------------------
# main
#----------------------------------------------------

display(0,0,"gen_results($HOST_ID) started");

my $paths = undef;

display(0,1,"scanning directories ...");
$paths = get_paths($input_dir);
if (!@$paths)
{
    error("No paths found. Aborting");
    exit 1;
}
display(0,1,"found ".scalar(@$paths)." audio files");


for my $i (0..(@programs/2)-1)
{
    my ($id,$exe) = ($programs[$i*2],$programs[$i*2+1]);
    next if $id !~ /$HOST_ID/;
    my $check_version = "";
    $check_version = $1 if ($id =~ /.*?\.(.*)$/);
    last if !do_one_run($paths,$id,$exe,$check_version);
}

display(0,0,"gen_results($HOST_ID) finished");


1;

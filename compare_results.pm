#!/usr/bin/perl
#---------------------------------------------------------------------
# compare_results.pm
#
# This program compares the text files produced by
# various other programs to develop a list of the
# differences between "runs" of fpcalc on a number
# of audio files.
#
# The files utilize a naming convention, and their
# contents are standardized as follows.
#
# filename:  fpcalc_host_platform.version.txt
#
#   Where host, platform, and version vary according
#   to the host_platform the fpcalc executable or libarry
#   was built upon (_linux,_win, or _orig), the platform it
#   was executed upon (win, x86, x86s, arm, arms, arm7, arms7s,
#   and/or host), and an (optional) version number from the
#   set 0.9, 0.11, 2.7, and "multi-tip").
#
# Each file contains "chunks" that represent the call to
# fpcalc for the version, or a specific audio file.
# The chunks are separated by one or more blank lines.
# The file begins with a "header" that is the output of
# a call to fpcalc -version, then, for each audio file
# there is a line of the format:
#
#   fpcalc_host_platform.version(path)
#
# where host, platform, and version *should* match that
# of the filename, and the "path" will be used to compare
# this particular "run" to the other "runs" in this process.
#
# The result is output to std_out as one big table, which
# can be viewed, but is not much use otherwise.  It is also
# output to a CSV file (results.csv) for further analysis.
#
#------------------------------------------------------------
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
no utf8;
use Encode;
use Digest::MD5 'md5_hex';
use appUtils qw(display warning error pad roundTwo printVarToFile);
    # This program makes use of my own personal application framework,
    # to provide a limited number of output routines.  It *should be*
    # fairly easy, if you want, to remove the "use appUtils" and substitute
    # your own routines for the above.

my $SHOW_BAD_FINGERPRINTS = 0;
    # if 1, will highlight (out of threshold) BAD fingerprints
    # as errors as they are processed.

# all builds in the _results directory, except $base_ref_id
# will be checked.

my $results_base = "_results";
    # the input directory
my $csv_file = "results.csv";
    # the output file

# thresholds for good compares

my $FP_SCORE_THRESHOLD1 = 0.001;
my $FP_SCORE_THRESHOLD2 = 0.010;


#---------------------------------------------
# internals
#---------------------------------------------
# build the "reference" data from the base_ref
# and md5_ref builds by taking duration, fingerprint_md5,
# and fingerprint_ints from the base_ref, and
# the stream_md5 from the md5_ref build files

my $base_ref_id = "orig_win";
    # The "base reference" build is the November 23, 2013
    # "official" acoustid Windows build release.
my $md5_ref_id = "linux_win.0.9";
    # The "base reference" for stream_md5 is my linux built
    # windows executable based on ffmpeg 0.9

my %reference;
    # path => record with all of below fields

my @base_ref_fields = qw(
    duration
    fingerprint_md5
    fingerprint_ints );

my @md5_ref_fields = qw(
    stream_md5 );

my @all_ref_fields = (
    @base_ref_fields,
    @md5_ref_fields );

# hashes of value=>path for uniqueness checks.
# across all platforms md5's should be unique
# i.e. a given md5 should never point at a different
# path.  This allows for different md5s to point
# at the same path (if they are different on different
# platforms) but they should always be "unique".

my %fingerprint_md5_hash;
    # all should have a unique fingerprint_md5
my %stream_md5_hash;
    # all should have a unique stream_md5


#-----------------------------------------
# show the results
#-----------------------------------------

my @compare_ids;
my %final_results;
my %compares_by_id;
my %bad_by_id;


sub bump
{
    my ($key) = @_;
    $final_results{$key} ||= 0;
    $final_results{$key} ++;
}


sub build_results
    # build the summary and/or show detailed results
{
    my %summary;
    display(9,0,"detailed results");
    for my $key (sort(keys(%final_results)))
    {
        my $value = $final_results{$key};
        display(9,1,pad($value,6)." $key");

        $key =~ s/\s+$//;
        my $id = "total";
        my $category = $key;
        if ($key =~ s/\s+for (.*)$//)
        {
            $id = $1;
            $category = $key;
        }
        $summary{$category} ||= {};
        $summary{$category}->{$id} = $value;
    }
    display(9,0,"");
    return \%summary;
}


my $FIRST_COL_WIDTH = "%-36s";
my $RESULT_COL_WIDTH = "%8s";

sub show_results
{
    my $summary = build_results;
    my @ids = ('total', @compare_ids);
    my $csv_text = "SUMMARY OF fpcalc comparisons on ".localtime()."\n\n";
    printf("\nSUMMARY\n");

    # csv gets a line with the whole id

    $csv_text .= "id,";
    for my $id (@ids)
    {
        $csv_text .= "$id,";
    }
    $csv_text .= "\n";


    # show three lines for the id: version, build, platform

    printf($FIRST_COL_WIDTH,"ffmpeg version");
    $csv_text .= "ffmpeg_version,";
    for my $id (@ids)
    {
        my $version = $id;
        $version =~ s/^.*?(\.|$)//;
        printf($RESULT_COL_WIDTH,$version);
        $csv_text .= "$version,";
    }
    printf("\n");
    $csv_text .= "\n";

    printf($FIRST_COL_WIDTH,"build platform");
    $csv_text .= "build_platform,";
    for my $id (@ids)
    {
        my $build = $id;
        $build =~ s/_.*$//;
        $build = "" if $build eq "total";
        printf($RESULT_COL_WIDTH,$build);
        $csv_text .= "$build,";
    }
    printf("\n");
    $csv_text .= "\n";

    printf($FIRST_COL_WIDTH,"execution platform");
    $csv_text .= "exec_platform,";
    for my $id (@ids)
    {
        my $plat = $id;
        $plat =~ s/.*?_//;
        $plat =~ s/\..*$//;
        printf($RESULT_COL_WIDTH,$plat);
        $csv_text .= "$plat,";
    }
    printf("\n\n");
    $csv_text .= "\n\n";

    my $last = 'a';
    for my $key (sort(keys(%$summary)))
    {
        if (substr($key,0,1) ne $last)
        {
            printf("\n");
            $csv_text .= "\n";
            $last = substr($key,0,1);
        }
        printf($FIRST_COL_WIDTH,$key);
        $csv_text .= "$key,";

        my $rec = $summary->{$key};
        for my $id (@ids)
        {
            printf($RESULT_COL_WIDTH,$rec->{$id} || "");
            $csv_text .= ($rec->{$id} || "").",";
        }
        printf("\n");
        $csv_text .= "\n";
    }

    printf("\n");
    $csv_text .= "\nBAD_PERCENT,";

    printf($FIRST_COL_WIDTH,"BAD PERCENT");
    for my $id (@ids)
    {
        my $pct = '';
        if ($id ne "total")
        {
            my $bad = $bad_by_id{$id};
            if ($bad)
            {
                my $possible = $compares_by_id{$id};
                $pct = roundTwo((100*$bad)/$possible)."%";
            }
        }
        printf($RESULT_COL_WIDTH,$pct);
        $csv_text .= "$pct,";
    }
    printf("\n\n");
    $csv_text .= "\n\n";
    printVarToFile(1,$csv_file,$csv_text);
}




#-------------------------------------
# get_compare_ids()
#-------------------------------------
# get a list of "platform ids" that will be compared
# by looking thru the _results directory and gathering
# all text files that match the pattern except the $base_ref_id.
# sort the files by ffmpeg version, my version, platform, build

sub get_compare_ids
{
    my @ids;
    if (!opendir DIR,$results_base)
    {
        error("Could not opendir $results_base");
        return;
    }
    while (my $entry=readdir(DIR))
    {
        if ($entry =~ /^fpcalc_(.*)\.txt$/)
        {
            my $id = $1;
            next if $id eq $base_ref_id;
            push @ids,$id;
        }
    }
    closedir DIR;

    @compare_ids = sort {cmp_id($a,$b)} @ids;
    for my $id (@compare_ids)
    {
        display(0,0,"compare_id=$id");
    }
    return 1;
}


sub parse_id
{
    my ($id) = @_;
    if ($id !~ /(.+)_(.+?)($|\.(.*)$)/)
    {
        error("Unknown id($id) in parse_id");
        exit 1;
    }

    my $my_ver = '';
    my ($build,$plat,$ver) = ($1,$2,$4 || '');
    if ($ver =~ /(\d+)\.(\d+)\.(\d+)/)
    {
        $ver = "$1.$2";
        $my_ver = $3;
    }

    display(9,0,"parse_id=$build, $plat, $ver, $my_ver");
    return ($build,$plat,$ver,$my_ver);
}


sub int_ver
    # returns 0 for blank, 1 for 0.9, 2 for 0.11, and 3 for 2.7, 4 for anything else
{
    my ($ver) = @_;
    return 0 if !$ver;
    return 1 if $ver eq "0.9";
    return 2 if $ver eq "0.11";
    return 3 if $ver eq "2.7";
    return 4;
}


sub int_plat
{
    my ($plat) = @_;
    return 0 if $plat eq "orig";
    return 1 if $plat eq "ubuntu";
    return 2 if $plat eq "win";
    return 3 if $plat eq "x86";
    return 4 if $plat eq "x86s";
    return 5 if $plat eq "arm";
    return 6 if $plat eq "arm7";
    return 7 if $plat eq "arms";
    return 8 if $plat eq "arm7s";
    return 9 if $plat eq "host";
    return 20;
}


sub cmp_id
{
    my ($a,$b) = @_;
    my ($build1,$plat1,$ffmpeg_version1,$my_version1) = parse_id($a);
    my ($build2,$plat2,$ffmpeg_version2,$my_version2) = parse_id($b);

    my $cmp = int_ver($ffmpeg_version1) <=> int_ver($ffmpeg_version2);
    return $cmp if $cmp;
    $cmp = $my_version1 cmp $my_version2;
    return $cmp if $cmp;
    $cmp = int_plat($plat1) cmp int_plat($plat2);
    return $cmp if $cmp;
    return $build1 cmp $build2;
}


#----------------------------------------
# Read the text files
#----------------------------------------
# builds a hash for a single text file
# that will be compared to the $base_ref_id
# and $md5_ref_id hashes.

sub check_unique
{
    my ($field,$hash,$id,$val,$path) = @_;
    my $exists = $hash->{$val};
    if ($exists)
    {
        my ($id_part,$path_part) = split(/:/,$exists);
        if ($path_part ne $path)
        {
            error("DUPLICATE $field($val) for\n\t".pad($id,20)."($path) already in use by \n\t".pad($id_part,20)."($path_part)");
            exit 1;
        }
    }
    else
    {
        $hash->{$val} = "$id:$path";
    }
}



my $dbg_piece = 3;

sub parse_piece
    # each piece is separated by a blank line
{
    my ($is_base_ref, $id, $dest_hash, $fields, $path, $lines) = @_;
    display($dbg_piece,0,"parse_piece($id,$path)");

    # merging is only allowed for $id==$md5_ref

    my $result = $dest_hash->{$path};
    if ($result && $id ne $md5_ref_id)
    {
        error("duplicate path($path) in $id");
        return;
    }

    # warning (and don't do it) if is_base_ref &&
    # id==$md5_ref, and there is no existing result

    if (!$result && $is_base_ref && $id eq $md5_ref_id)
    {
        warning(0,0,"no_base_ref($base_ref_id) for $id($path)");
        return;
    }

    $result = {} if !$result;

    # parse all the fields into a local hash

    my %local_result;
    my $line = shift @$lines;
    chomp $line;
    $line =~ s/\s+$//;
    while ($line ne "")
    {
        if ($line =~ /^(.*?)=(.*)$/)
        {
            my ($lval,$rval) = ($1,$2);
            $rval ||= '';
            display($dbg_piece,1,lc($lval)." = $rval");
            $local_result{lc($lval)} = $rval;
        }
        elsif ($line =~ /ERROR:|NO RESULTS/)
        {
            warning(0,0,"No results: $id($path): $line");
            bump("a2. missing results") if !$is_base_ref;
            bump("a2. missing results for $id") if !$is_base_ref;
            return;
        }
        elsif ($line !~ /^\[(mp3|mwav2|wmav2|mjpeg|wav)/ &&
               $line !~ /^WARNING:/)
        {
            warning(0,0,"Unknown line : $line");
            warning(0,1,"in $id($path)");
        }

        $line = shift @$lines;
        chomp $line;
        $line =~ s/\s+$//;
    }

    # merge the desired fields into the result
    # check for unique fingerprint_md5/stream_md5

    for my $field (@$fields)
    {
        my $val = $local_result{$field};
        if (!$val)
        {
            error("No $field in $id($path)");
        }
        else
        {
            check_unique($field,\%fingerprint_md5_hash,$id,$val,$path)
                if ($field eq "fingerprint_md5");
            check_unique($field,\%stream_md5_hash,$id,$val,$path)
                if ($field eq "stream_md5");
            $result->{$field} = $val;
        }
    }

    # assign the final result to global values

    $dest_hash->{$path} = $result;

}



sub parse_one_file
{
    my ($is_base_ref, $id, $dest_hash, $fields) = @_;
    my $filename = "$results_base/fpcalc_$id.txt";

    display(0,0,"parse_one_file($filename)");
    if (!open(IFILE,"<$filename"))
    {
        warning(0,1,"Could not open $filename for reading");
        return 0;
    }
    my @lines = <IFILE>;
    close IFILE;

    my $debug_this = 0;
    my $warn_different_id = 1;
    my $line = shift @lines;
    while (defined($line))
    {
        # Give a warning if the starting platform indicator
        # does not match the $platform

        if ($line =~ /^(\S+)\((.*)\)\s*$/)
        {
            my ($got_id,$path) = ($1,$2);

            # This one is problematic under x86 it WILDTH~.mp3, under
            # host ubuntu its got words;

            if (00 && $path =~ /albums\/Compilations\/Various - Unknown\/Wild/i)
            {
                warning(0,2,"skipping path: $path");
                $line = shift @lines;
                next;
            }

            if ($got_id ne "fpcalc_$id")
            {
                warning(0,1,"The internal file id $got_id<>$id in $filename")
                    if ($warn_different_id);
                $warn_different_id = 0;
            }

            $path =~ s/^.*\/mp3s\///;
                # prh - would be better if android generation program
                # did not include full path, or if all files did.

            # this code mungs paths from all platforms to
            # single representation

            if ($id =~ /_x86|_arm/ && $id =~ /^(orig|host|linux|win)/)
            {
                $path = Encode::decode("utf-8",$path);
            }

            parse_piece($is_base_ref, $id, $dest_hash, $fields, $path, \@lines);
        }
        $line = shift @lines;;
    }
    return 1;
}




#-------------------------------------
# compare()
#-------------------------------------
# Compare the hash for a single run of fpcalc
# to the base_ref and/or md5_ref hashes for the
# same path.

sub compare
{
    my ($id,$path,$ref,$rec) = @_;
    my $fields = $id =~ /orig/ ? \@base_ref_fields : \@all_ref_fields;

    bump("a3. total compares");
    bump("a3. total compares for $id");
    $compares_by_id{$id} ||= 0;
    $compares_by_id{$id} ++;

    for my $field (@$fields)
    {
        next if ($field eq "fingerprint_ints");
            # compared as subset of fingerprint_md5, below

        my $val1 = $ref->{$field} || '';
        my $val2 = $rec->{$field} || '';
        if ($val1 eq $val2)
        {
            bump("b0. same $field");
            bump("b0. same $field for $id");
        }
        else
        {
            bump("c1. diff $field");
            bump("c1. diff $field for $id");

            # if different fingerprint_md5s, do
            # lower level compare of ints

            if ($field eq 'fingerprint_md5')
            {
                compare_fingerprints($id,$path,$ref,$rec);
            }
        }
    }
}




sub check_ints
{
    my ($id,$path,$rec) = @_;
    my $str = $rec->{fingerprint_ints} || '';
    my @ints = split(/,/,$str);

    if (!$str || !@ints)
    {
        warning(0,0,"no ints for $id($path)");
        bump("d0. missing fingerprint_ints");
        bump("d0. missing fingerprint_ints for $id");
        return;
    }

    my $MIN_INTS = 100;
    if (@ints < $MIN_INTS)
    {
        warning(0,0,"not enough fingerprint_ints for $id($path)");
        bump("d1. not enough fingerprint_ints");
        bump("d1. not enough fingerprint_ints for $id");
        return;
    }

    return \@ints;
}




sub compare_fingerprints
{
    my ($id,$path,$ref,$rec) = @_;

    # errors *should* already have been noted
    # in uniquess checks ..

    my $ints1 = check_ints($base_ref_id,$path,$ref);
    return 0 if !$ints1;

    my $ints2 = check_ints($id,$path,$rec);
    return 0 if !$ints2;

    bump("f0. actual fingerprint comparisons");
    bump("f0. actual fingerprint comparisons for $id");

    my $score = match_fp($ints1,$ints2);

    my $retval = 0;
    if ($score == 0)
    {
        bump("f1. exact match score");
        bump("f1. exact match score for $id");
    }
    elsif ($score <= $FP_SCORE_THRESHOLD1)
    {
        bump("f2. score within threshold($FP_SCORE_THRESHOLD1)");
        bump("f2. score within threshold($FP_SCORE_THRESHOLD1) for $id");
        $retval = 1;
    }
    elsif ($score <= $FP_SCORE_THRESHOLD2)
    {
        bump("f3. score within threshold($FP_SCORE_THRESHOLD2)");
        bump("f3. score within threshold($FP_SCORE_THRESHOLD2) for $id");
        $retval = 2;
    }
    else
    {
        error("fingeprint($base_ref_id<>$id) SCORE($score) in $path")
            if $SHOW_BAD_FINGERPRINTS;
        bump("f4. score over threshold($FP_SCORE_THRESHOLD2)");
        bump("f4. score over threshold($FP_SCORE_THRESHOLD2) for $id");

        my $bad_score = substr($score,0,4);
        bump("g0. bad_score $bad_score");
        bump("g0. bad_score $bad_score for $id");

        $bad_by_id{$id} ||= 0;
        $bad_by_id{$id} ++;

        $retval = 3;
    }
    return $retval;

}



sub match_fp
    # develop score from 0..1 by matching 2 bit groups
    # where 0 is a perfect match.
{
    my ($ints1,$ints2) = @_;
    my $len = @$ints1 > @$ints2 ? @$ints1 : @$ints2;
    my $num_groups = $len * 16;

    my $num_diffs = 0;
    for (my $i=0; $i<$len; $i++)
    {
        my $mask = 0x11;
        my $i1 = $i < @$ints1 ? $$ints1[$i] : 0;
        my $i2 = $i < @$ints2 ? $$ints2[$i] : 0;
        for my $j (0..15)
        {
            $num_diffs++ if ($i1 & $mask) != ($i2 & $mask);
            $mask <<= 2;
        }
    }

    my $score = $num_diffs / $num_groups;
    $score = sprintf("%0.6f",$score);
    return $score;
}





#-------------------------------------
# main
#-------------------------------------

display(0,0,"compare_results.pm started");

# get list of files (ids) to compare

display(0,0,"getting compare_ids");
exit 1 if !get_compare_ids();

# build the reference data

display(0,0,"building reference data");
exit 1 if !parse_one_file(1,$base_ref_id,,\%reference,\@base_ref_fields);
exit 1 if !parse_one_file(1,$md5_ref_id,\%reference,\@md5_ref_fields);

# do the compares

display(0,0,"parsing files");
for my $id (@compare_ids)
{
    my %file_results;
    my $fields =  $id =~ /orig/ ? \@base_ref_fields : \@all_ref_fields;
    if (parse_one_file(0,$id,\%file_results,$fields))
    {
        $final_results{"a1. total_possible for $id"} = scalar(keys(%reference));

        for my $path (sort(keys(%reference)))
        {
            my $rec = $file_results{$path};
            compare($id,$path,$reference{$path},$rec) if $rec;
        }
    }
}

display(0,0,"showing_results");

show_results();

display(0,0,"compare_results.pm finished");


1;

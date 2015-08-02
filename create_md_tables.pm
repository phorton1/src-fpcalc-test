#!/usr/bin/perl
#---------------------------------------------------------------------
# create_md_tables.pm
#
# A program which reads results.csv produced by compare_results.pm,
# and generates the md (markdown syntax) tables that I want in my
# phorton1/fpcalc-test readme.md file.

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
use Digest::MD5 'md5_hex';
use appUtils qw(display warning error pad roundTwo printVarToFile);
    # This program makes use of my own personal application framework,
    # to provide a limited number of output routines.  It *should be*
    # fairly easy, if you want, to remove the "use appUtils" and substitute
    # your own routines for the above.

my $csv_file = "results.csv";

my %results;
    # A hash, by id, of records containing the following fields
    #     ffmpeg_version
    #     build_platform
    #     exec_platform
    #     text = array of strings containing the entire colum of text starting with ffmpeg version
my @left_column;
    # the left most (common) column
my @ids;


#---------------------------------------
# read_results_csv
#---------------------------------------

sub read_results_csv
{
    if (!open IFILE,"<$csv_file")
    {
        error("Could not open $csv_file for reading");
        return;
    }
    my @lines = <IFILE>;
    close IFILE;

    my $started = 0;
    for my $line (@lines)
    {
        chomp($line);
        display(9,1,"line=$line");

        $line =~ s/\s*//;
        my @parts = split(/,/,$line);
        if (!$started && $parts[0] && $parts[0] eq "id")
        {
            $started = 1;
            for (my $i=1; $i<@parts; $i++)
            {
                my $id = $parts[$i];    # one based
                push @ids,$id;
                $results{$id} = {};
                $results{$id}->{text} = [];
                display(9,2,"starting id=$id");
            }
        }
        elsif ($started)
        {
            my $col_id = $parts[0] || '';
            display(9,2,"doing '$col_id'");
            push @left_column,$col_id;
            for (my $i=1; $i<@ids+1; $i++)
            {
                my $id = $ids[$i-1];
                my $val = $parts[$i] || '';
                display(9,3,"adding($id)='$val'");

                push @{$results{$id}->{text}},$val;
                $results{$id}->{ffmpeg_version} = $val
                    if ($col_id eq "ffmpeg_version");
                $results{$id}->{build_platform} = $val
                    if ($col_id eq "build_platform");
                $results{$id}->{exec_platform} = $val
                    if ($col_id eq "exec_platform");
            }
        }
    }

    display(0,0,"found ".scalar(keys(%results))." result platforms");
    return 1;
}


#-------------------------------------
# show results
#-------------------------------------

my $dbg_show = 3;

sub show_results
{
    my ($output_file,$version,$specific_re) = @_;
    my @columns;
    push @columns,[@left_column];

    display($dbg_show,0,"");
    display(0,0,"show_results($output_file,$version,$specific_re)");
    display($dbg_show,0,"");

    for my $id (@ids)
    {
        next if $version && $results{$id}->{ffmpeg_version} ne $version;
        next if $specific_re && $id !~ /$specific_re/;
        push @columns,$results{$id}->{text};
    }

    my $html_text = "<table style='border:1px solid black; border-collapse:collapse; padding:4px; spacing:2px'>\n";
    for (my $i=0; $i<@left_column; $i++)
    {
        my $used = 0;
        my $show_text = "";
        my $html_line = "<tr>\n";
        for (my $j=0; $j<@columns; $j++)
        {
            my $value = $columns[$j]->[$i] || "";
            $used = 1 if $j>0 && $value;
            $show_text .= pad($value,($j==0?45:12));
            $html_line .= "<td>";
            $html_line .= "<b>" if ($j==0 || $i<4);
            $html_line .= ($value || "&nbsp;");
            $html_line .= "</b>" if ($j==0 || $i<4);
            $html_line .= "</td>\n";
        }
        $html_line .= "</tr>\n";
        $html_text .= $html_line if !$columns[0]->[$i] || $used;
        display($dbg_show,0,$show_text);
    }
    display($dbg_show,0,"");
    $html_text .= "</table>\n";
    printVarToFile(1,$output_file,$html_text);
}




#-------------------------------------
# main
#-------------------------------------

display(0,0,"create_md_tables.pm started");

# read the results.csv file into memory

display(0,0,"reading results.csv");
if (read_results_csv())
{
    show_results("results.2.7.html","2.7",'');
    show_results("results.0.11.html","0.11",'');
    show_results("results.0.9.html","0.9",'');
    show_results("orig.html","",'orig');
}

display(0,0,"create_md_tables.pm finished");


1;

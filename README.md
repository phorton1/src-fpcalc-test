phorton1/test
=========================

## Contents

This repository contains my own personal scripts, and perl and java code to install, run, and compare the results of the various versions of fpcalc built with the phorton1/chromaprint repository.

It is beyond the scope of my efforts to document the contents of this repository. If you are curious about (or regarding) how I use the particular scripts, perl, and java code to produce the results, and analyze them, please feel free to browse the source code and use it, and/or modify it as you wish.

The essential reason I am publishing this repository is to bring to light the results of my analysis of the behavior of the **chromaprint fpCalc utility** accross different **platforms** and
**versions of ffmpeg**.


## Executive Summary

It is my observation that the results of fpCalc (particularly the fingerprints produced by it), are sensitive to the **version of ffmpeg** they are built against, and to a lesser degree, by the **platform** they are built *for*, and *on*.  Undoubtedly, further analysis would reveal that it is also sensitive to the particular **ffmpeg flags** used in building it, as well as the specific **compiler and linker flags** used in the process.

I feel that this is an important fact to bring to light, insamuch as fpCalc appears to be generally intended to *produce consistent fingerprints for audio files in the wild* and that may not always be the case.

This fact, and this analysis *may* be important to others, including the original author of chromaprint/fpcalc and the https://acoustic.id website, **Lukas Lalinsky**, and the authors and publishers of the widely distrubuted musicBrainz [picard](http://picard.musicbrainz.org/) application, and/or other applications that use fpCalc and/or chromaprint.


## General Observations

I personally *backed into* this project as initially all I was trying to do was build an **Android version of fpCalc** for use in my own application development.  When I did so, as a matter of *due diligence*, I endeavored to test the results of my build against the **Windows 32bit reference fpCalc** that I have been using for several years, which is available on the acoustid site
[here](https://bitbucket.org/acoustid/chromaprint/downloads/chromaprint-fpcalc-1.1-win-i686.zip),
and which is distributed as part of the Windows release of the musicBrainz [picard](http://picard.musicbrainz.org/) application (henceforth named **orig_win** for brevity).

When I compared the results of my Android build of fpCalc to the *orig_win* version, using my 9000 or so personal audio files as a test base, I found that over **5%** of the files produced **significantly different** fingerprints using my build versus the orig_win build. This perplexed and bothered me, both for my own personal use, and because I had been hoping to *release* my Android build of fpCalc into the wild for use by other application developers.

As a result, I ended up spending hundreds of hours exploring the problem, learning to build various versions of fpCalc, looking at virtually every available webpage for the android NDK, chromaprint, ffmpeg, cross platform building, and so on, and ended up developing the phorton1/ffmpeg, phorton1/chromaprint, and phorton1/fpcalc-releases repositories, in addition to this one.

The end result is that I believe that fpCalc, and to a lesser degree, chromaprint itself, is senstive to the version of ffmpeg they are built against, the particular ffmpeg, compiler, and linker flags used in the process, and that **care should be taken when releasing fpCalc executables into the wild** and that **further thought should be given to this issue**.


## General Methodology

The general methodolgy I used was to build the various versions of fpCalc as executables and/or JNI shared libraries as described in the phorton1/chromaprint repository, and to run each of those executables and libraries against my 9000 or so audio files, and develop a 100MB+ text file per platform containing the output of fpcalc against those 9000 files.

As a baseline, and for additional perusal, I also ran the 9000 files thru the **orig_win** build, and an **x86 Ubuntu 12.04 distro of fpCalc** that is called **orig_x86** in this discussion.

There is a separate program that can then compare these text files, and the fingerprints (and other information) produced by the runs of fpCalc and display those results in a table to let me see trends, differences, etc.  The *entire results* of that comparison are available as a comma delimited *csv file* called **results.csv** in this repository, and I wrote yet another perl program to present those results in *bite size chunks* for this README.md text file.

Generally speaking, the **text fingerprint** produced by fpCalc can be decompressed and decoded into a series of **unsigned 32 bit integers**.  In my analsysis, those integers are compared *bitwise*, 2 bits at a time, and a count of the differences is kept.  So a perfect match of fingerprints, herein, has a "score" of 0.00000, and a perfect mis-match has a score of 1.00000.

*aside: I am interested in the actual comparison operation used by the acoustid website, for example, if the **magnitude** of the difference of the 2 bit comparisons is important, if acoustid does any kind of **shifting** or initial matching (i.e. what if there is a little bit of extra white noise at the beginning of one file or another), and very interested in the **semantics and expectations** for these "fingerprints", i.e. when should they be *similar*, and when are they expected to be *different* across platforms, ffmpeg versions, audio files that only differ in, for example, bitrate, and/or audio files that are actually different recordings of the same songs by the same artist at different times.  I look forward to a analytical discussion of these topics with the author of chromaprint.*

*aside2: I believe that my comparison is sufficient to detect **significant** differences.  If the **magnitude** were important, it would merely **increase** the number of differences detected by my analysis.*

In doing this analysis (over and over for the past 2 months), I also **added some fpCalc features** that help with the process, and may be useful for other things.  I added an **md5 hash of the text fingerprint** to allow for quicker exact matching, and a **stream_md5 hash** that identifies if the lower level ffmpeg stream being passed to chromaprint is the same, or different, on a given build. I also **beefed up the -version option** to display the particulars about the version and flags of the ffmpeg it is linked to, and *hope that the author will incorporate these changes into the main trunk of acoustid/chromaprint*. Personally, I will be using this new stream_md5 as a unique identifier for the audio stream in a cross platform manner, independent of, for example, the *tags* that the user can modify in those files.

Once again, this *summarization of my efforts* for the last 2 months or so belies the fact that I ran more than 500,000 tests of fpCalc, and built it dozens, if not hundreds, of times, using various versions of chromaprint **and** ffmpeg sources available on the web, before I finally settled down on the specific acoustid/chromaprint and https://ffmpeg.org repositories and the formalization of the build process contained herein.

So, without further ado, here are the results:


## A. ffmpeg version 2.7

This set of results most closely mimics the results you would be likely to get if you built chromaprint/fpCalc from one of the many descriptions of how to do so that you are likely to find on the web.  The key is that, unless the particular instructions you are following work with a **specific version of ffmpeg**, that you are *wily nilly* selecting an arbitrary version of ffmpeg, which is most likely to be near the current **tip** as available at https://ffmpeg.org.

This set of results is basically what I got when I first tried to build an android version of fpCalc, and which led me to this huge analytical project.


**ffmpeg_version**|**2.7**|**2.7**|**2.7**|**2.7**|**2.7**|**2.7**|**2.7**|
:---|---:|---:|---:|---:|---:|---:|---:|
**build_platform**|**linux**|**win**|**host**|**linux**|**win**|**linux**|**linux**|
**exec_platform**|**win**|**win**|**x86**|**x86**|**x86**|**x86s**|**arm7s**|
||||||||
**a1. total_possible**|8577|8577|8577|8577|8577|8577|8577|
**a3. total compares**|8577|8577|8577|8577|8577|8577|8577|
||||||||
**b0. same duration**|7476|7476|7476|7476|7476|7476|7476|
**b0. same fingerprint_md5**|6312|6308|6306|6313|6313|6313|6026|
**b0. same stream_md5**|8117|8117|8117|8117|8117|8117|8117|
||||||||
**c1. diff duration**|1101|1101|1101|1101|1101|1101|1101|
**c1. diff fingerprint_md5**|2265|2269|2271|2264|2264|2264|2551|
**c1. diff stream_md5**|460|460|460|460|460|460|460|
||||||||
**f0. actual fingerprint comparisons**|2265|2269|2271|2264|2264|2264|2551|
**f1. exact match score**|648|650|650|648|648|648|743|
**f2. score within threshold(0.001)**|1159|1161|1163|1158|1158|1158|1347|
**f3. score within threshold(0.01)**|4|4|4|4|4|4|7|
**f4. score over threshold(0.01)**|454|454|454|454|454|454|454|
||||||||
**g0. bad_score 0.02**|1|1|1|1|1|1|1|
**g0. bad_score 0.03**|1|1|1|1|1|1|1|
**g0. bad_score 0.04**|1|1|1|1|1|1|1|
**g0. bad_score 0.05**|11|11|11|11|11|11|11|
**g0. bad_score 0.06**|38|38|38|38|38|38|38|
**g0. bad_score 0.07**|97|97|97|97|97|97|97|
**g0. bad_score 0.08**|35|35|35|35|35|35|35|
**g0. bad_score 0.09**|1|1|1|1|1|1|1|
**g0. bad_score 0.10**|8|8|8|8|8|8|8|
**g0. bad_score 0.11**|33|33|33|33|33|33|33|
**g0. bad_score 0.12**|54|54|54|54|54|54|54|
**g0. bad_score 0.13**|68|68|68|68|68|68|68|
**g0. bad_score 0.14**|68|68|68|68|68|68|68|
**g0. bad_score 0.15**|25|25|25|25|25|25|25|
**g0. bad_score 0.16**|10|10|10|10|10|10|10|
**g0. bad_score 0.17**|3|3|3|3|3|3|3|
||||||||
**BAD_PERCENT**|5.29%|5.29%|5.29%|5.29%|5.29%|5.29%|5.29%|


Basically this table shows the comparison of various builds I have done of fpCalc against the **n2.7** "official release" of ffmpeg versus the **orig_win** build.  One can read it from left to right, top to bottom, and note the following:

- of the 8577 files compared, 1101 gave **different duration**s than *orig_win*.
- regardless of what platform was built, or run, the number of duration differences was still **1101**.
- in 8117 cases, chromaprint received the exact same stream from ffmpeg, in **460 cases** it received a **different stream_md5** from ffmpeg.
- the number of *exact match* fingerprints (**same fingerprint_md5**) differed by build and execution platform.
- the number of **different fingerprint_md5**'s is much greater than the number of stream differences.
- the number of **bad fingerprints is 454** representing about **5.29%** of my audio files.

For those fingerprints that differed from the orig_win build, they were decoded, and compared bitwise as described above. What is interesting about the *f0-f4* section, is that although there were different distributions of "insignficant differences" where the score was *under* **0.01**, that the **number of significant differences** was the **same** across all platforms and builds, at **454 cases** or **5.29%** of my audio files.

This **5.29%** difference is specific to my particular collection of audio files.  One could run this test suite against another collection and receive a *0%* difference.  But what is **scary** is that one could also run this suite against a particular collection and receive **100%** signficant differences from the orig_win build.

There is no rigourous definition of **significant differences**, but looking at the distributions of "bad scores" in the "g0" section of the table, shows some with scores that themselves differed by 10% or more from the orig_win fingerprint.  Surely this is cause for some concern for a system that tries to match acoustid fingerprints to specific musicbrainz release information.  This is significant enough that it very likely could result in a **wrong release** getting a better score than the **correct release** for a given file, and could mess up naive users of *picard*, as well as *polluting* the acoustid fingerprint database.


## B. ffmpeg version 0.11

Running the same tests, but varying only the **ffmpeg version** to *official release* **n0.11** produced the following table.

What is interesting is that the number of **stream differences** has *decreased*, and *correspondingly*, the ultimate number and percentage of **"bad" fingerprints** has likewise decreased to  **33 == 0.38%**:


**ffmpeg_version**|**0.11**|**0.11**|**0.11**|**0.11**|**0.11**|**0.11**|**0.11**|**0.11**|
:---|---:|---:|---:|---:|---:|---:|---:|---:|
**build_platform**|**linux**|**win**|**host**|**linux**|**win**|**linux**|**win**|**linux**|
**exec_platform**|**win**|**win**|**x86**|**x86**|**x86**|**x86s**|**x86s**|**arm7s**|
|||||||||
**a1. total_possible**|8577|8577|8577|8577|8577|8577|8577|8577|
**a3. total compares**|8577|8577|8577|8577|8577|8577|8577|8577|
|||||||||
**b0. same duration**|8577|8577|8577|8577|8577|8577|8577|8577|
**b0. same fingerprint_md5**|8533|8530|6905|7006|7006|7006|7006|7006|
**b0. same stream_md5**|8540|8540|8540|8540|8540|8540|8540|8540|
|||||||||
**c1. diff fingerprint_md5**|44|47|1672|1571|1571|1571|1571|1571|
**c1. diff stream_md5**|37|37|37|37|37|37|37|37|
|||||||||
**f0. actual fingerprint comparisons**|44|47|1672|1571|1571|1571|1571|1571|
**f1. exact match score**|1|1|581|550|550|550|550|550|
**f2. score within threshold(0.001)**|8|11|1055|984|984|984|984|984|
**f3. score within threshold(0.01)**|2|2|3|4|4|4|4|4|
**f4. score over threshold(0.01)**|33|33|33|33|33|33|33|33|
|||||||||
**g0. bad_score 0.05**|2|2|2|2|2|2|2|2|
**g0. bad_score 0.06**|4|4|4|4|4|4|4|4|
**g0. bad_score 0.07**|14|14|14|14|14|14|14|14|
**g0. bad_score 0.08**|6|6|6|6|6|6|6|6|
**g0. bad_score 0.15**|1|1|1|1|1|1|1|1|
**g0. bad_score 0.16**|3|3|3|3|3|3|3|3|
**g0. bad_score 0.17**|3|3|3|3|3|3|3|3|
|||||||||
**BAD_PERCENT**|0.38%|0.38%|0.38%|0.38%|0.38%|0.38%|0.38%|0.38%|


There are still **platform differences**, but in general, the 0.11 build produces **much better results** than the ffmpeg n2.7 builds.


## C. ffmpeg version 0.09

Finally, by analyzing the libraries used in a particular distro of fpCalc (x86 Ubuntu 12.04) I was able to select a version of ffmpeg that I believe most closely matches that used to build the orig_win executable.  The version I selected was ffmpeg *official release* **n0.9**.

*aside: I would **love it** if Lukas has information pertaining to the **exact** version of ffmpeg, and it's libraries, which he used to build the orig_win release.*

First of all, of perhaps highest importance, is that this build has **no significant differences** from the orig_win build.  In my terminology, **there are no "bad" fingerprints** produced by these versions of fpCalc built against ffmpeg n0.9. There are also no differences in the **duration** of the audio files as reported by this version of fpCalc.

And very interestingly, the linux-win build returns the **exact same fingerprints** as the orig_win version ....


**ffmpeg_version**|**0.9**|**0.9**|**0.9**|**0.9**|**0.9**|**0.9**|**0.9**|**0.9**|
:---|---:|---:|---:|---:|---:|---:|---:|---:|
**build_platform**|**linux**|**win**|**host**|**linux**|**win**|**linux**|**win**|**linux**|
**exec_platform**|**win**|**win**|**x86**|**x86**|**x86**|**x86s**|**x86s**|**arm7s**|
|||||||||
**a1. total_possible**|8577|8577|8577|8577|8577|8577|8577|8577|
**a3. total compares**|8577|8577|8577|8577|8577|8577|8577|8577|
|||||||||
**b0. same duration**|8577|8577|8577|8577|8577|8577|8577|8577|
**b0. same fingerprint_md5**|8577|8574|6941|7044|7044|7044|7044|7044|
**b0. same stream_md5**|8577|8577|8577|8577|8577|8577|8577|8577|
|||||||||
**c1. diff fingerprint_md5**||3|1636|1533|1533|1533|1533|1533|
|||||||||
**f0. actual fingerprint comparisons**||3|1636|1533|1533|1533|1533|1533|
**f1. exact match score**|||582|550|550|550|550|550|
**f2. score within threshold(0.001)**||3|1053|981|981|981|981|981|
**f3. score within threshold(0.01)**|||1|2|2|2|2|2|


## D. x86 Ubuntu 12.04 distro fpCalc

For completeness, there is one more results table of interest.  In addition to comparing the versions of fpCalc that can be built using phorton1/chromaprint, I also ran the test suite on the **distro version** of fpCalc that can be obtained within x86 Ubuntu 12.04 using **apt-get**.

There are several interesting observations about this running this *wild* version of fpCalc and comparing it to the *orig_win* release.

- it **failed** (crashed) on four files that worked with orig_win and my builds
- it never reported a different **duration** that the orig_win build
- it produced a significant number of **exact matching fingerprint_md5s** (6929)
- it required a **threshold of 0.001** to "catch" the majority of its differences as *insignifcant*, and
- the one file that was bad was **signficantly bad* with a score of **0.13**


**ffmpeg_version**|*unknown**|
:---|---:|
**build_platform**|**orig**|
**exec_platform**|**x86**|
||
**a1. total_possible**|8577|
**a2. missing results**|4|
**a3. total compares**|8573|
||
**b0. same duration**|8573|
**b0. same fingerprint_md5**|6929|
||
**c1. diff fingerprint_md5**|1644|
||
**f0. actual fingerprint comparisons**|1644|
**f1. exact match score**|583|
**f2. score within threshold(0.001)**|1058|
**f3. score within threshold(0.01)**|2|
**f4. score over threshold(0.01)**|1|
||
**g0. bad_score 0.13**|1|
||
**BAD_PERCENT**|0.01%|


It is interesting that my **linux_win.0.9** version produced *better results* than this release distro.

## Re-iterated Summary

I believe this issue to be important for further analysis and discussion.

In the meantime, I have released **executables and libraries** based on the ffmpeg n0.9 release in my phorton1/fpcalc-release repository.

Interested parties *should* be able to duplicate my results by following the instructions in the phorton1/ffmpeg and phorton1/chromaprint repositories to build the various versions of fpCalc, and by figuring out and/or implementing their own *comparison methodology* as presented in the perl and java scripts and programs here.


## License and Credits

The materials in this repository are (c) Copyright 2015 - Patrick Horton, and are released under the **GNU Public License Version 2**.

Please see COPYING.GPLv2 for more information

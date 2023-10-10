#!/usr/bin/perl
#---------------------------------------------------------------------
# pfDecompress.pm
#---------------------------------------------------------------------
# Implements a routine to convert acoustic_id/chromaprint fingerprints
# from their cross-platform textual representation into their underlying
# reprentation as list of integers in this machines's native Perl format,
# as per the chromaprint objects and methods of the same names.
#
#---------------------------------------------------------------
#
# This file is (c) Copyright 2015 - Patrick Horton.
#
# It is released under the GNU Public License Version 2,
# and you are free to modify it as you wish, as long as
# this header, and the copyright it contains are included
# intact in your modified version of the this file.
#
# Please see COPYING.GPLv2 for more information.

package bitStringReader;
use strict;
use warnings;

use appUtils qw(display warning display_bytes $debug_level);
    # This is a "pure perl" module.
    #
    # My personal appUtils.pm module merely provides some
    # debugging variables and methods. You can safely delete
    # this use statement, and the associated references to
    # these variables and methods from the source without affecting
    # the behavior. Or you could implement your own versions if
	# you wish.

    my $dbg_cmp = 3;

    sub new
    {
        my ($class,$data) = @_;
        display($dbg_cmp+1,1,"bitReader::new() data=".length($data)." bytes");

        my $this = {};
        bless $this,$class;
        $this->{m_value} = $data;
        $this->{m_buffer} = 0;
        $this->{m_buffer_size} = 0;
        $this->{m_eof} = 0;
        $this->{m_iter_pos} = 0;
        return $this;
    }

    sub EOF
    {
        my ($this) = @_;
        display($dbg_cmp+3,1,"bitReader::EOF()=$this->{m_eof}");
        return $this->{m_eof};
    }

    sub Read
    {
        my ($this,$bits) = @_;
        display($dbg_cmp+2,1,"bitReader::Read($bits)");

        if ($this->{m_buffer_size} < $bits)
        {
            if ($this->{m_iter_pos} < length($this->{m_value}))
            {
                my $c = substr($this->{m_value},$this->{m_iter_pos}++,1);
                $this->{m_buffer} |= ord($c) << $this->{m_buffer_size};
                $this->{m_buffer_size} += 8;
            }
            else
            {
                $this->{m_eof} = 1;
            }
        }

        my $mask = (1 << $bits) - 1;
        my $result = $this->{m_buffer} & $mask;
        $this->{m_buffer} >>= $bits;
        $this->{m_buffer_size} -= $bits;
        if ($this->{m_buffer_size} <= 0 &&
            $this->{m_iter_pos} >= length($this->{m_value}))
        {
            $this->{m_eof} = 1;
        }

        display($dbg_cmp+2,1,"bitReader::Read() returning $result");
        return $result;
    }

    sub Reset
    {
        my ($this) = @_;
        display($dbg_cmp+2,1,"bitReader::Reset()");
        $this->{m_buffer} = 0;
		$this->{m_buffer_size} = 0;
	}

    sub AvailableBits
    {
        my ($this) = @_;
        my $retval = 0;
        if (!$this->{m_eof})
        {
            $retval = $this->{m_buffer_size} + 8 * (length($this->{m_value}) - $this->{m_iter_pos});
		}
        display($dbg_cmp+2,1,"bitReader::AvailableBits() returning $retval");
        return $retval;
    }



package fpDecompress;
use strict;
use warnings;
use appUtils qw(display display_bytes $debug_level);


    my $kMaxNormalValue = 7;
    my $kNormalBits = 3;
    my $kExceptionBits = 5;


    sub UnpackBits()
    {
        my ($this) = @_;
        display($dbg_cmp,1,"fpDecompressor::UnpackBits()");
    	my $i = 0;
        my $value = 0;
        my $last_bit = 0;

        for (my $j=0; $j<@{$this->{m_bits}}; $j++)
        {
            my $bit = $this->{m_bits}->[$j];
            if ($bit == 0)
            {
                $this->{m_result}->[$i] = ($i > 0) ? ($value ^ $this->{m_result}->[$i-1]) : $value;
                $value = 0;
                $last_bit = 0;
                $i++;
                next;
            }
            $bit += $last_bit;
            $last_bit = $bit;
            $value |= 1 << ($bit - 1);
        }
	}


    sub ReadNormalBits
    {
        my ($this,$reader) = @_;
        display($dbg_cmp,1,"fpDecompressor::ReadNormalBits(".scalar(@{$this->{m_result}}).")");

        # debugging
        my $last_i = 0;
        my $debug_s = "";

        my $i = 0;
    	while ($i < @{$this->{m_result}})
        {
    		my $bit = $reader->Read($kNormalBits);
            if ($bit == 0)
            {
                $i++;
            }
            push @{$this->{m_bits}},$bit;

            # debugging
            if ($dbg_cmp<$debug_level)
            {
                if ($i != $last_i)
                {
                    display(0,2,"pushed bits($last_i) $debug_s");
                    $debug_s = "";
                }
                $debug_s .= $bit." ";
                $last_i = $i;
            }
        }

        display($dbg_cmp+1,2,"pushed bits($i) $debug_s");
        display($dbg_cmp,1,"ReadNormalBits got ".scalar(@{$this->{m_bits}})." 3-bit-chunks") ;

        # c++ invariantly returned true
    }


    sub ReadExceptionBits
    {
        my ($this,$reader) = @_;
        display($dbg_cmp,1,"fpDecompressor::ReadExceptionBits(".scalar(@{$this->{m_bits}}).")");

        # debugging
        my $last_i = 0;
        my $debug_s = "";

    	for (my $i=0; $i<@{$this->{m_bits}}; $i++)
        {
    		if ($this->{m_bits}->[$i] == $kMaxNormalValue)
            {
                if ($reader->EOF())
                {
                    warning(0,0,"ReadExceptionBits($i) -- Invalid fingerprint (reached EOF while reading exception bits)");
                    return 0;
                }
    			my $add = $reader->Read($kExceptionBits);
                $this->{m_bits}->[$i] += $add;

                if ($dbg_cmp<$debug_level)
                {
                    if ($i != $last_i)
                    {
                        display(0,2,"adding bits($i) $debug_s");
                        $debug_s = "";
                    }
                    $debug_s .= $add ." ";
                    $last_i = $i;
                }
			}
		}
        display($dbg_cmp+1,2,"adding bits(".scalar(@{$this->{m_bits}})." $debug_s");
    	return 1;
    }


    sub Decompress
    {
        my ($class,$fingerprint) = @_;
        display($dbg_cmp,0,"fpDecompressor::Decompress() fingerprint=".length($fingerprint)." bytes");

        my $this = {};
        bless $this,$class;
        $this->{m_bits} = [];

        # first the fingerprint is base64 decoded

        # my $decoded = decode_base64($fingerprint);
        my $decoded = chromaprint_base64decode($fingerprint);
        display($dbg_cmp,1,"length decoded=".length($decoded));
        display_bytes($dbg_cmp+1,0,"decoded",$decoded);

        if (length($decoded) < 4)
        {
            warning(0,0,"fingerprint must be at least 4 bytes");
            return [];
        }

        my $algorithm = ord(substr($decoded,0,1));
        my $num_ints =
            (ord(substr($decoded,1,1))<<16) |
            (ord(substr($decoded,2,1))<<8) |
            ord(substr($decoded,3,1));

        display($dbg_cmp,1,"Decompress() num_ints=$num_ints algorithm=$algorithm");

        my $reader = bitStringReader->new($decoded);
    	$reader->Read(8);
        $reader->Read(8);
        $reader->Read(8);
        $reader->Read(8);

        if ($reader->AvailableBits() < $num_ints * $kNormalBits)
        {
            warning(0,0,"fingerprint() is too short to decompress");
            return [];
        }

        $this->{m_result} = [ (0) x $num_ints ];

    	$reader->Reset();
        $this->ReadNormalBits($reader);
        display($dbg_cmp,1,"available after normal bits=".$reader->AvailableBits()." /5= ".($reader->AvailableBits()/5));

        $reader->Reset();
        if (!$this->ReadExceptionBits($reader))
        {
            warning(0,0,"could not read exception bits ... returning empty result");
            $this->{m_result} = [];
    	}
        else
        {
            $this->UnpackBits();
        }

        display($dbg_cmp,1,"fpDecompressor::Decompress() returning ".scalar(@{$this->{m_result}})." elements");

        # we have to do an extra step to turn the bitwise integers
        # into 2's compliment in perl

        my $rslt = $this->{m_result};
        for (my $i=0; $i<@$rslt; $i++)
        {
            $rslt->[$i] = unpack("l",pack("l",$rslt->[$i]));
        }

        if ($dbg_cmp<=$debug_level)
        {
            for (my $i=0; $i<@$rslt; $i++)
            {
                display(0,1,"$i   $rslt->[$i]");
            }
        }
        return $this->{m_result};
    }




    #-------------------------------------------------------
    # lucas I don't think your base64decode is standard
    #-------------------------------------------------------
    # Got a different result from perl's MIME:Base64 routine
    # so I had to implement your "base64" decoder ... then it worked!

    my $kBase64Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    my @kBase64CharsReversed = (
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 62, 0, 0, 52,
        53, 54, 55, 56, 57, 58, 59, 60, 61, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5,
        6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
        25, 0, 0, 0, 0, 63, 0, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37,
        38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 0, 0, 0, 0, 0
        );


    sub next_char
    {
        my ($string,$pos) = @_;
        my $c = ord(substr($string,$$pos,1));
        $$pos++;
        return $c;
    }

    sub chromaprint_base64decode
    {
        my ($encoded) = @_;
        my $pos = 0;
        my $size = length($encoded);
        my $dest = "";
        while ($size > 0)
        {
            my $b0 = $kBase64CharsReversed[ next_char($encoded,\$pos) ];
            if (--$size)
            {
    			my $b1 = $kBase64CharsReversed[ next_char($encoded,\$pos) ];
                my $r = ($b0 << 2) | ($b1 >> 4);
                $dest .= chr($r);
    			if (--$size)
                {
                    my $b2 = $kBase64CharsReversed[ next_char($encoded,\$pos) ];
                    my $r = (($b1 << 4) & 255) | ($b2 >> 2);
                    $dest .= chr($r);
        			if (--$size)
                    {
                        my $b3 = $kBase64CharsReversed[next_char($encoded,\$pos)];
                        my $r = (($b2 << 6) & 255) | $b3;
                        $dest .= chr($r);
                        --$size;
                    }
				}
			}
		}
        return $dest;
	}



1;

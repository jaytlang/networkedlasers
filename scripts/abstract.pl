#!/usr/bin/perl

use strict;
use warnings;

# TODO: Review/change these things
# Feel free to totally restructure this lol
# Should embed in the bigger skeleton below
my $projecttitle = "Hey Wouldn't It Be Cool if You Could Control Lasers Over The Network?";
my $fischerpart = << "EOM";

implement a full-color laser projector capable of rendering frames delivered to the projector over the network. With a direct connection to the TCP stack through the FPGA, we seek to demonstrate that high-bandwidth communication using existing standards can be accomplished in a novel fashion, with equivalent or better performance relative to a traditional microcontroller implementation.
EOM

# TODO: Feel free to change me
# Like please, my writing skills are awful
my $abstract = << "EOM";
Today, TCP sees wide use across the open internet, but puts extensive
processing load on the host CPU (and on older endpoints, the PCI bus). In response,
we propose a project entitled "$projecttitle", a parallel-stack TCP Offload Engine (TOE) designed
to free up computing power, and to allow auxiliary hardware to interface
with the TCP/IP stack directly. To show the utility of this architecture,
we will $fischerpart We hope to evaluate our networking solution
against existing TCP implementations, and create a clean interface through
which hardware designers can take advantage of TCP's in-order, reliable packet
transport without incurring the runtime costs of a dedicated application processor.
EOM

# shouldn't change below this comment
# this wraps the abstract at 80 chars/line
$abstract =~ s/\n/\ /g;
$abstract =~ s/(.{1,79}\S|\S+)\s+/$1\n/g;

my $fname = "generated_abstract.txt";
open my $AFH, '>', $fname or die "Can't open abstract: $!";
print $AFH "="x10 . $projecttitle . "="x10 . "\n\n$abstract";
close $AFH;


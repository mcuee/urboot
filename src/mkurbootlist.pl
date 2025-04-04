#!/usr/bin/perl -CS

# mkurbootlist.pl
#
# Generates urbootlist.[ch] for AVRDUDE with bootloader stubs from the .h
# files in bootloader-stubs/. These in turn have been generated by running
# ./mkalltemplates
#
# meta-author Stefan Rueger
# Published under GNU General Public License, version 3 (GPL-3.0)
#
# v 1.2
# 31.03.2025

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Basename;
use Math::Cartesian::Product;
# use List::Util qw(first min max sum);
# use File::HomeDir;
# use List::MoreUtils qw(first_index only_index);
# use Scalar::Util qw(looks_like_number);
# use List::Compare;
# use HTML::Entities;
# use String::Scanf; # imports sscanf()

my $progname = basename($0);

my $ver = 'v 1.2';

my $Usage = <<"END_USAGE";
Syntax: $progname
Function: outputs urbootlist.[ch] from bootloader-stubs/*.h templates
Option:
  -help
END_USAGE

my $help;

GetOptions(
  'help' => \$help,
) or die $Usage;

die $Usage if $help;

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();
my $today = sprintf("%02d.%02d.%04d", $mday, $mon+1, 1900+$year);

my @sizelocs = qw(
  size usage
  ldi_brrlo ldi_brrhi ldi_brrshared ldi_linbrrlo ldi_linlbt swio_extra12 ldi_bvalue
  ldi_wdto ldi_stk_insync ldi_stk_ok rjmp_application jmp_application
  sbi_ddrtx cbi_tx sbi_tx sbic_rx_start sbic_rx
  ldi_starthhz ldi_starthi cpi_starthi cpi_startlo
);

my (%uniqbootloaderlist, %bootloaderlist, %nbootloaders, @blpaths,
    %config, %check, %blpathinfo);

my %mcu = ( # #gpio, #in, #out, #isr, #wdt
  m169 => [53, 1, 0, 23, 4],
  m169a => [53, 1, 0, 23, 4],
  m169p => [53, 1, 0, 23, 4],
  m169pa => [54, 0, 0, 23, 4],
  m329 => [53, 1, 0, 23, 4],
  m329a => [53, 1, 0, 23, 4],
  m329p => [53, 1, 0, 23, 4],
  m329pa => [53, 1, 0, 23, 4],
  m3290 => [53, 1, 0, 25, 4],
  m3290a => [53, 1, 0, 25, 4],
  m3290p => [53, 1, 0, 25, 4],
  m3290pa => [53, 1, 0, 25, 4],
  m649 => [53, 1, 0, 23, 4],
  m649a => [53, 1, 0, 23, 4],
  m649p => [53, 1, 0, 23, 4],
  m6490 => [53, 1, 0, 25, 4],
  m6490a => [53, 1, 0, 25, 4],
  m6490p => [53, 1, 0, 25, 4],
  m48 => [23, 0, 0, 26, 6],
  m48a => [23, 0, 0, 26, 6],
  m48p => [23, 0, 0, 26, 6],
  m48pa => [23, 0, 0, 26, 6],
  m48pb => [27, 0, 0, 27, 6],
  m88 => [23, 0, 0, 26, 6],
  m88a => [23, 0, 0, 26, 6],
  m88p => [23, 0, 0, 26, 6],
  m88pa => [23, 0, 0, 26, 6],
  m88pb => [27, 0, 0, 27, 6],
  m168 => [23, 0, 0, 26, 6],
  m168a => [23, 0, 0, 26, 6],
  m168p => [23, 0, 0, 26, 6],
  m168pa => [23, 0, 0, 26, 6],
  m168pb => [27, 0, 0, 27, 6],
  m328 => [23, 0, 0, 26, 6],
  m328p => [23, 0, 0, 26, 6],
  m328pb => [27, 0, 0, 45, 6],
  m406 => [18, 0, 1, 23, 6],
  m165 => [53, 0, 0, 22, 4],
  m165a => [53, 1, 0, 22, 4],
  m165p => [53, 1, 0, 22, 4],
  m165pa => [53, 1, 0, 22, 4],
  m325 => [53, 1, 0, 22, 4],
  m325a => [53, 1, 0, 22, 4],
  m325p => [53, 1, 0, 22, 4],
  m325pa => [53, 1, 0, 22, 4],
  m3250 => [53, 1, 0, 25, 4],
  m3250a => [53, 1, 0, 25, 4],
  m3250p => [53, 1, 0, 25, 4],
  m3250pa => [53, 1, 0, 25, 4],
  m645 => [53, 1, 0, 22, 4],
  m645a => [53, 1, 0, 22, 4],
  m645p => [53, 1, 0, 22, 4],
  m6450 => [53, 1, 0, 25, 4],
  m6450a => [53, 1, 0, 25, 4],
  m6450p => [53, 1, 0, 25, 4],
  m8515 => [35, 0, 0, 17, 4],
  m8535 => [32, 0, 0, 21, 4],
  m164a => [32, 0, 0, 31, 6],
  m164p => [32, 0, 0, 31, 6],
  m164pa => [32, 0, 0, 31, 6],
  m324a => [32, 0, 0, 31, 6],
  m324p => [32, 0, 0, 31, 6],
  m324pa => [32, 0, 0, 31, 6],
  m324pb => [39, 0, 0, 51, 6],
  m644 => [32, 0, 0, 28, 6],
  m644a => [32, 0, 0, 31, 6],
  m644p => [32, 0, 0, 31, 6],
  m644pa => [32, 0, 0, 31, 6],
  m644rfr2 => [54, 0, 0, 77, 6],
  m1284 => [32, 0, 0, 35, 6],
  m1284p => [32, 0, 0, 35, 6],
  m1284rfr2 => [54, 0, 0, 77, 6],
  m2564rfr2 => [54, 0, 0, 77, 6],
  m163 => [32, 0, 0, 18, 4],
  m162 => [35, 0, 0, 28, 4],
  m161 => [35, 0, 0, 21, 4],
  m8 => [23, 0, 0, 19, 4],
  m8a => [23, 0, 0, 19, 4],
  m8hva => [ 7, 0, 0, 21, 6],
  m8u2 => [23, 0, 0, 29, 6],
  m16 => [32, 0, 0, 21, 4],
  m16a => [32, 0, 0, 21, 4],
  m16hva => [ 7, 0, 0, 21, 6],
  m16hvb => [17, 0, 1, 29, 6],
  m16hvbrevb => [17, 0, 1, 29, 6],
  m16m1 => [27, 0, 0, 31, 6],
  m16u2 => [23, 0, 0, 29, 6],
  m16u4 => [26, 0, 0, 43, 6],
  m32 => [32, 0, 0, 21, 4],
  m32a => [32, 0, 0, 21, 4],
  m32c1 => [27, 0, 0, 31, 6],
  m32hvb => [17, 0, 1, 29, 6],
  m32hvbrevb => [17, 0, 1, 29, 6],
  m32m1 => [27, 0, 0, 31, 6],
  m32u2 => [23, 0, 0, 29, 6],
  m32u4 => [26, 0, 0, 43, 6],
  m64 => [40, 8, 0, 35, 4],
  m64a => [40, 8, 0, 35, 4],
  m64c1 => [27, 0, 0, 31, 6],
  m64hve2 => [10, 0, 0, 25, 6],
  m64m1 => [27, 0, 0, 31, 6],
  m64rfr2 => [54, 0, 0, 77, 6],
  m640 => [54, 0, 0, 57, 6],
  m128 => [40, 8, 0, 35, 4],
  m128a => [40, 8, 0, 35, 4],
  m128rfa1 => [54, 0, 0, 72, 6],
  m128rfr2 => [54, 0, 0, 77, 6],
  m1280 => [54, 0, 0, 57, 6],
  m1281 => [54, 0, 0, 57, 6],
  m256rfr2 => [54, 0, 0, 77, 6],
  m2560 => [54, 0, 0, 57, 6],
  m2561 => [54, 0, 0, 57, 6],
  t48 => [28, 0, 0, 20, 6],
  t88 => [28, 0, 0, 20, 6],
  t828 => [28, 0, 0, 26, 6],
  t87 => [16, 0, 0, 20, 6],
  t167 => [16, 0, 0, 20, 6],
  t25 => [ 6, 0, 0, 15, 6],
  t45 => [ 6, 0, 0, 15, 6],
  t85 => [ 6, 0, 0, 15, 6],
  t24 => [12, 0, 0, 17, 6],
  t24a => [12, 0, 0, 17, 6],
  t44 => [12, 0, 0, 17, 6],
  t44a => [12, 0, 0, 17, 6],
  t84 => [12, 0, 0, 17, 6],
  t84a => [12, 0, 0, 17, 6],
  t1634 => [18, 0, 0, 28, 6],
  t13 => [ 6, 0, 0, 10, 6],
  t13a => [ 6, 0, 0, 10, 6],
  t43u => [16, 0, 0, 16, 6],
  t2313 => [18, 0, 0, 19, 6],
  t2313a => [18, 0, 0, 21, 6],
  t4313 => [18, 0, 0, 21, 6],
  t261 => [16, 0, 0, 19, 6],
  t261a => [16, 0, 0, 19, 6],
  t441 => [12, 0, 0, 30, 6],
  t461 => [16, 0, 0, 19, 6],
  t461a => [16, 0, 0, 19, 6],
  t841 => [12, 0, 0, 30, 6],
  t861 => [16, 0, 0, 19, 6],
  t861a => [16, 0, 0, 19, 6],
  c32 => [53, 0, 0, 37, 4],
  c64 => [53, 0, 0, 37, 4],
  c128 => [53, 0, 0, 37, 4],
  pwm1 => [19, 0, 0, 32, 6],
  pwm2 => [27, 0, 0, 32, 6],
  pwm2b => [27, 0, 0, 32, 6],
  pwm3 => [27, 0, 0, 32, 6],
  pwm3b => [27, 0, 0, 32, 6],
  pwm81 => [19, 0, 0, 20, 6],
  pwm161 => [19, 0, 0, 20, 6],
  pwm216 => [27, 0, 0, 32, 6],
  pwm316 => [27, 0, 0, 32, 6],
  usb82 => [23, 0, 0, 29, 6],
  usb162 => [23, 0, 0, 29, 6],
  usb646 => [48, 0, 0, 38, 6],
  usb647 => [48, 0, 0, 38, 6],
  usb1286 => [48, 0, 0, 38, 6],
  usb1287 => [48, 0, 0, 38, 6],
  a5505 => [16, 0, 0, 20, 6],
  a6612c => [23, 0, 0, 26, 6],
  a6613c => [23, 0, 0, 26, 6],
  a6614q => [23, 0, 0, 26, 6],
  a6616c => [16, 0, 0, 20, 6],
  a6617c => [16, 0, 0, 20, 6],
  a664251 => [16, 0, 0, 20, 6],
);

my %io = ( # Number of different bootloaders
  autobaud_uart0 => 1,
  autobaud_uart0_alt1 => 1,
  autobaud_uart1 => 1,
  autobaud_uart2 => 1,
  lin_uart0 => 256,
  u1x8_uart0 => 256,
  u1x8_uart0_alt1 => 256,
  u1x8_uart1 => 256,
  u1x8_uart2 => 256,
  u1x8_uart3 => 256,
  u1x12_uart0 => 4096,
  u1x12_uart0_alt1 => 4096,
  u1x12_uart1 => 4096,
  u1x12_uart2 => 4096,
  u1x12_uart3 => 4096,
  u2x8_uart0 => 256,
  u2x8_uart0_alt1 => 256,
  u2x8_uart1 => 256,
  u2x8_uart2 => 256,
  u2x8_uart3 => 256,
  u2x12_uart0 => 4096,
  u2x12_uart0_alt1 => 4096,
  u2x12_uart1 => 4096,
  u2x12_uart2 => 4096,
  u2x12_uart3 => 4096,
  swio00 => 1,
  swio01 => 1,
  swio02 => 1,
  swio03 => 1,
  swio04 => 1,
  swio05 => 1,
  swio10 => 256,
  swio11 => 256,
  swio12 => 256,
  swio13 => 256,
  swio14 => 256,
  swio15 => 256,
);

@blpaths = glob("bootloader-stubs/*.h");
for my $pp (@blpaths) {
  my $name = basename($pp, ".h") =~ s/^urboot_//r;
  $name =~ s/no-led/noled/;
  $name =~ s/_[rt]x[a-r][0-9]//g;

  # Unique description of the bootloader split into mcu, io, config
  my $desc = "${name}_";
  $desc =~ s/_uart/-uart/;
  $desc =~ s/_alt/-alt/;
  $desc =~ s/ee_ce_hw_$/ee-ce-hw/;
  $desc =~ s/hw_$/hw/;
  $desc =~ s/pr_ce_$/pr-ce/;
  $desc =~ s/pr_ee_ce_$/pr-ee-ce/;
  $desc =~ s/pr_ee_$/pr-ee/;
  $desc =~ s/pr_$/pr/;
  my @desc = split('_', $desc, -1);
  die "unknown format of $name\n" if @desc != 4;
  map { s/^$/min/; s/-/_/g } @desc;
  die "unknown MCU $desc[0]" if !exists $mcu{$desc[0]};
  die "unknown I/O mode $desc[1]" if !exists $io{$desc[1]};
  # $io{$desc[1]}++;
  $config{"$desc[2]_$desc[3]"}++;
  $check{"@desc"}++;
  # print STDERR "@desc $name\n";

  $blpathinfo{$pp} = [$name, $desc[0], $desc[1], "$desc[2]_$desc[3]"];
}

die "Not unique description in \@desc" if 0+keys %check != 0+@blpaths;

open(my $ubc, '>', 'urbootlist.c') or die "$progname: cannot write file urbootlist.c\n";
open(my $ubh, '>', 'urbootlist.h') or die "$progname: cannot write file urbootlist.h\n";

print $ubc <<"END";
/*
 * Do not edit: automatically generated by the urboot project using
 * https://github.com/stefanrueger/urboot/blob/main/src/mkurbootlist.pl
 *
 * urbootlist.c
 *
 * List of template urboot bootloaders
 *
 * Published under GNU General Public License, version 3 (GPL-3.0)
 * Meta-author Stefan Rueger <stefan.rueger\@urclocks.com>
 *
 * $ver
 * $today
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "avrdude.h"
#include <libavrdude.h>
#include "urbootlist.h"
#include "urclock_private.h"

END

print $ubh <<"END";
/*
 * Do not edit: automatically generated by the urboot project using
 * https://github.com/stefanrueger/urboot/blob/main/src/mkurbootlist.pl
 *
 * urbootlist.h
 *
 * Definitions for list of template urboot bootloaders
 *
 * Published under GNU General Public License, version 3 (GPL-3.0)
 * Meta-author Stefan Rueger <stefan.rueger\@urclocks.com>
 *
 * $ver
 * $today
 *
 */

#ifndef urbootlist_h
#define urbootlist_h

END

# MCUs
my @mcus = sort { mcuorder($a) cmp mcuorder($b) } keys %mcu;

printf $ubc "static const char *mcus[%d] = {\n", 0+@mcus;
printf $ubc "%s\"%s\",%s", $_%8==0? "  ": "", $mcus[$_], ($_+1)%8 == 0 || $_ == $#mcus? "\n": " " for (0..$#mcus);
printf $ubc "};\n\n";

# printf $ubh "enum {\n";
# printf $ubh "%s%s,%s", $_%8==0? "  ": "", 'UL_'.uc $mcus[$_], ($_+1)%8 == 0 || $_ == $#mcus? "\n": " " for (0..$#mcus);
# printf $ubh "  UL_MCU_N\n} Ul_mcu;\n\n";

# I/O types
my @iotypes = map { s/zwio/swio/r } map { s/x9/x12/r } sort map { s/swio/zwio/r } map { s/x12/x9/r } keys %io;

printf $ubc "static const char *iotypes[%d] = {", 0+@iotypes;
my $iobeg = 'xxxx';
for (@iotypes) {
  if(substr($_, 0, 5) ne $iobeg) {
    print $ubc "\n ";
    $iobeg = substr($_, 0, 5);
  }
  print $ubc " \"$_\",";
}
print $ubc "\n};\n\n";

# printf $ubh "enum {";
# $iobeg = 'xxxx';
# for (@iotypes) {
#   if(substr($_, 0, 5) ne $iobeg) {
#     print $ubh "\n ";
#     $iobeg = substr($_, 0, 5);
#   }
#   printf $ubh " %s,", 'UL_'.uc $_;
# }
# printf $ubh "\n  UL_IOTYPE_N\n} Ul_iotype;\n\n";

# Configurations
my @configs;
cartesian { push(@configs, join("_", @_)); } [qw(noled lednop dual)], [qw(min pr pr_ee pr_ce pr_ee_ce hw ee_ce_hw)];
die "unforeseen configurations" if join("/", sort @configs) ne join("/", sort keys %config);

printf $ubc "static const char *configs[%d] = {\n", 0+@configs;
printf $ubc "%s\"%s\",%s", $_%7==0? "  ": "", $configs[$_], ($_+1)%7 == 0 || $_ == $#configs? "\n": " " for (0..$#configs);
printf $ubc "};\n\n";

# printf $ubh "enum {\n";
# printf $ubh "%s%s,%s", $_%7==0? "  ": "", 'UL_'.uc $configs[$_], ($_+1)%7 == 0 || $_ == $#configs? "\n": " " for (0..$#configs);
# printf $ubh "  UL_CONFIG_N\n} Ul_config;\n\n";

# Assign a uniqne number bln() to each path and sort @blpaths accordingly
my (%mcun, %iotypen, %confign);
$mcun{$mcus[$_]} = $_ for (0..$#mcus);
$iotypen{$iotypes[$_]} = $_ for (0..$#iotypes);
$confign{$configs[$_]} = $_ for (0..$#configs);
@blpaths = sort { bln(@{$blpathinfo{$a}}[1..3]) <=> bln(@{$blpathinfo{$b}}[1..3]) } @blpaths;

######
# Identify bootloaders with same contents
#
for my $pp (@blpaths) {
  my $name = $blpathinfo{$pp}->[0];
  # next if $name =~ /_swio0/;

  open(my $fh, $pp) or die "cannot open $pp\n";
  my $ppbl = undef;
  open(my $fbl, '>', \$ppbl) or die "$progname: cannot write bootloader $pp to variable ppbl\n";
  local $/;
  my $bootcode = <$fh>;
  print $fbl "$bootcode";
  close($fbl) or die "cannot close variable ppbl\n";
  close($fh) or die "cannot close $pp\n";

  push @{$uniqbootloaderlist{$ppbl}}, $name;
  $bootloaderlist{$name} = $ppbl;
}

######
# Generate frequency table of bootloader words in unique bootloaders
#
my (%freq, @huffq, %huffenc);
for my $blc (keys %uniqbootloaderlist) {
  map { $freq{sprintf "%04x", $_ <= 0? 0: $_}++; } eval "($blc)";
}

######
# Generate Huffman encoding according to frequency table
# Inspired by https://github.com/StefanKarpinski/huffman
#
push @huffq, [$_, $freq{$_}] for sort keys %freq;
while (@huffq > 1) {
  @huffq = @huffq[sort { $huffq[$a]->[1] <=> $huffq[$b]->[1] or $a <=> $b } 0..$#huffq];
  my @x = splice @huffq, 0, 2;
  push @huffq, [[map {$_->[0]} @x], $x[0][1]+$x[1][1]];
}
sub prhuffq {
  my @el = @_;
  ref $el[0] ne '' or return $huffenc{$el[0]} = $el[1];
  for my $bit (0..$#{$el[0]}) {
    prhuffq($el[0][$bit], ($#el > 0? $el[1]: '').$bit);
  }
}
prhuffq($huffq[0][0]);

# print "$_\t$huffenc{$_}\n" for sort { $huffenc{$a} cmp $huffenc{$b} } keys %huffenc;

print $ubc <<"END";

typedef struct {
  uint16_t word;
  uint32_t hcode;
} Ul_huffcode;

// Huffman code table for compression of bootloader templates
static Ul_huffcode hcodes[${\(0+keys %huffenc)}] = {
#define ulhc(n, code) (((n)<<27) | (code))
END

sub huffcode {
  my $cd = shift;
  return hex(unpack('H*', pack('B*', reverse substr(('0' x 32).$cd, -32))));
}

for my $wd (sort {
  length($huffenc{$a}) <=> length($huffenc{$b}) or huffcode($huffenc{$a}) <=> huffcode($huffenc{$b})
  } keys %huffenc) {
  my $cd = $huffenc{$wd};
  printf $ubc "  {0x%s, ulhc(%2d, 0%08o)}, // %s\n", $wd, length($cd), huffcode($cd), $cd;
  die "need to use uint64_t hcode, a different ulhc() macro and huffcode() function" if length($cd) > 27;
}
print $ubc "};\n\n\n// Bootloader templates\n\n";

######
# Some stats
#
# Number of bootloaders in table
my $nbl = keys %bootloaderlist;
# Number of unique b/l, template sizes, b/l sizes, compressed template sizes, derived b/loaders
my ($nubl, $urtmplsizes, $ursizes, $huffsizes, $nvariants) = (0, 0, 0, 0, 0);

my $publ = undef;
open(my $ubl, '>', \$publ) or die "$progname: cannot write to variable publ\n";
for my $pp (@blpaths) {
  my $nm = $blpathinfo{$pp}->[0];
  $nvariants += nderived(@{$blpathinfo{$pp}}[1..3]);
  printf $ubl " {%7d, ur_%s },\n", bln(@{$blpathinfo{$pp}}[1..3]), $uniqbootloaderlist{$bootloaderlist{$nm}}->[0]
    if exists $bootloaderlist{$nm};
}
close($ubl);

for my $pp (@blpaths) {
  my $nm = $blpathinfo{$pp}->[0];
  if(exists $bootloaderlist{$nm}) {
    my @names = @{$uniqbootloaderlist{$bootloaderlist{$nm}}};
    print $ubc commentnames(@names);
    print $ubc "static const uint64_t ur_$names[0]\[\] = {\n ";

    my ($bits, $n, $k, $i64);
    my @words = (eval "($bootloaderlist{$nm})");
    $nubl++;
    $urtmplsizes += 2*(0+@words);
    $ursizes += $words[0];
    $bits .= $_ for (map { $huffenc{sprintf "%04x", $_ <= 0? 0: $_} } @words);
    $n = length($bits);
    $bits .= '0' x (64 - $n%64) if $n%64; # Pad binary string to multiple of 64 bits
    while($bits) {
      $k += 64;
      $i64 = reverse substr($bits, 0, 64);
      substr($bits, 0, 64) = '';
      printf $ubc " 0x%s,%s", unpack('H*', pack('B*', $i64)), $k >= $n? "\n": $k % (64*5) == 0? "\n ": "";
      $huffsizes += 8;
    }
    print $ubc "};\n\n";
    delete $bootloaderlist{$_} for @names;
  }
}

$huffsizes += 6*keys %huffenc;
$huffsizes += 12*$nbl;

# $nubl, $urtmplsizes, $ursizes, $huffsizes

print $ubc <<"END";

/*
 * This is a list of $nbl bootloader templates, each one described by a unique number
 *
 *   n = (mcu*UL_IOTYPE_N + io)*UL_CONFIG_N + config,
 *
 * where mcu [0, $#mcus] specifies the MCU; io in [0, $#iotypes] the iotype; config in [0, $#configs]
 * the configuration type of the bootloader. These values can be obtained from n by
 *
 *     mcu = n/(UL_IOTYPE_N*UL_CONFIG_N) = n/${\((0+@iotypes)*(0+@configs))}
 *      io = (n/UL_CONFIG_N)%UL_IOTYPE_N = (n/${\(0+@configs)})%${\(0+@iotypes)}
 *  config = n%UL_CONFIG_N = n%${\(0+@configs)}
 *
 * This list dispatches to ${\(0+keys %uniqbootloaderlist)} unique/different bootloader templates, which can be parametrised
 * to create specific working bootloaders for a certain baud rate, IO pin, LED pin etc. The data
 * for the bootloader are Huffman-compressed and, after decompression, yield 16-bit words, which
 * are
 *   - Size of the bootloader in bytes (number of code bytes incl 6 bytes for table at flash end)
 *   - Usage of the bootloader in bytes (smallest hardware boot section or multiple of page size)
 *   - ${\(@sizelocs-2)} word indices into the bootloader code where parameters can be set (0 if n/a)
 *   - Size/2 - 3 words of bootloader code
 *   - 3 words of a version table to be put on top of flash
 *
 * These templates need around ${\(sprintf "%.3f MiBi", $huffsizes/1024**2)} read-only storage and can create around ${\(sprintf "%.2f quadrillion", $nvariants/1e15)}
 * different bootloaders.
 */

typedef struct {
  int32_t n;                    // Unique number as described above
  const uint64_t *bl;           // Compressed bootloader template as described above
} Ul_urlist;

static Ul_urlist urbootlist[$nbl] = {
$publ};


static int huffsearch(const void *p1, const void *p2) {
  uint32_t h1 = ((Ul_huffcode *) p1)->hcode, h2 = ((Ul_huffcode *) p2)->hcode;
  return h1 < h2? -1: h1 == h2? 0: 1;
}

// Returns malloc'd urboot template bootloader from Huffman encoded array
static uint16_t *ul_urtemplate(const uint64_t *bl) {
  size_t end = 0, nn = 0;
  uint32_t hc = 0;
  int hcn = 0;
  Ul_huffcode key = { 0, 0 }, *res;
  uint64_t h64 = 0;
  int hn = 64;
  uint16_t *ret = NULL;

  while(!end || nn < end) {
    if(hn >= 64) {
      h64 = *bl++;
      hn = 0;
    }
    // Move 1 bit from Huffman bootloader bit string to a single Huffman code variable
    hc = (hc<<1) | (h64 & 1), hcn++;
    h64 >>= 1, hn++;
    if(hcn > 27) {
      pmsg_error("unexpected problem decoding bootloader code\\n");
      return NULL;
    }
    // Test whether Huffman code variable is in prefix table of codes
    key.hcode = ulhc(hcn, hc);
    if((res = bsearch(&key, hcodes, sizeof hcodes/sizeof *hcodes, sizeof *hcodes, huffsearch))) {
      if(!end) {
        end = ${\(0+@sizelocs)} + res->word/2; // First decoded word is size of b/l incl 6 byte table
        if(end < 32+${\(0+@sizelocs)} || end > 2048+${\(0+@sizelocs)}) {
          pmsg_error("unexpected bootloader code size\\n");
          return NULL;
        }
        ret = mmt_malloc(2*end);
      }
      ret[nn++] = res->word;
      hc = 0, hcn = 0;
    }
  }

  return ret;
}


static int urlistsearch(const void *p1, const void *p2) {
  return ((Ul_urlist *) p1)->n - ((Ul_urlist *) p2)->n;
}

// Returns malloc'd urboot template bootloader for (mcu, iotype, config) or NULL if not possible
uint16_t *urboottemplate(const char *mcu, const char *iotype, const char *config) {
  size_t m, i, c;

  for(m=0; m<UL_MCU_N; m++)
    if(str_eq(mcus[m], mcu))
      break;
  if(m >= UL_MCU_N) {
    pmsg_error("mcu id %s not available for urboot templates\\n", mcu);
    return NULL;
  }

  for(i=0; i<UL_IOTYPE_N; i++)
    if(str_eq(iotypes[i], iotype))
      break;
  if(i >= UL_IOTYPE_N) {
    pmsg_error("io type %s not available for urboot templates\\n", iotype);
    return NULL;
  }

  for(c=0; c<UL_CONFIG_N; c++)
    if(str_eq(configs[c], config))
      break;
  if(c >= UL_CONFIG_N) {
    pmsg_error("configuration %s not available for urboot templates\\n", config);
    return NULL;
  }

  Ul_urlist key = { UL_BLN(m, i, c), NULL }, *res;
  res = bsearch(&key, urbootlist, sizeof urbootlist/sizeof*urbootlist, sizeof *urbootlist, urlistsearch);
  if(!res) {
    pmsg_error("no urboot template available for (%s, %s, %s) combination\\n", mcu, iotype, config);
    return NULL;
  }

  return ul_urtemplate(res->bl);
}
END

my $len = 2;
print $ubh "// Code locations (in words) for urboot parametrisation\nenum {\n  ";
for (2..$#sizelocs) {
  printf $ubh "UL_%s,", uc $sizelocs[$_];
  if($_ == $#sizelocs || ($len += 3+length($sizelocs[$_])) > 72) {
    print $ubh "\n  ";
    $len = 2;
  } else {
    print $ubh " ";
  }
}
print $ubh "UL_CODELOCS_N\n};\n\n";

print $ubh <<"END";
#define UL_MCU_N            ${\(0+@mcus)}
#define UL_IOTYPE_N          ${\(0+@iotypes)}
#define UL_CONFIG_N          ${\(0+@configs)}
#define UL_BLN(mcu, io, config) (((mcu)*UL_IOTYPE_N + (io))*UL_CONFIG_N + (config))

uint16_t *urboottemplate(const char *mcu, const char *iotype, const char *config);

#endif
END

close($ubc);
close($ubh);

exit(0);

######
# Return a nicely formatted comment with a list of names
#

sub commentnames {
  my @names = map { sprintf " %-33s", $_ } @_;
  return "" if @names < 2;

  my $ret = "";
  my $inline = 1;
  my $len = 2;

  # Skip first name as that's used for the variable
  for(my $i = 1; $i < @names; $i++) {
    my $thislen =  length($names[$i]);
    if($thislen + $len > 105) {
      $ret =~ s/ *$//;
      $ret .= "\n *";
      $inline = 0;
      $len = 3;
    }
    $len += $thislen;
    $ret .= $names[$i];
  }

  $ret =~ s/ *$//;
  return $inline? "//$ret\n": "/*\n *$ret\n */\n";
}

######
# How to order the mcus

sub mcuorder {
  my $part = shift;

  return "z" if length($part) < 2;

  my %orderletter = (
    'a' => 'f',
    'c' => 'c',
    'm' => 'a',
    'p' => 'd',   
    't' => 'b',
    'u' => 'e',
  );
  my $ret = $orderletter{substr($part, 0, 1)};
  my $n = $part; $n =~ s/^[a-z]*//; $n =~ s/^([0-9]*).*$/$1/;
  my $m = $n;
  # Order the ATmegas/ATtinys in reverse family group order
  if($ret eq 'a' || $ret eq 'b') {
    $n = substr($n, 0, -1) if $ret eq 'a' && $n > 200 && ($n % 10) < 2;
    $ret .= ($n & ($n-1)) == 0? 'c': 9 - sprintf("%x", substr($n, -1));
  }
  $ret .= sprintf("%04d", $n);
  $ret .= sprintf("%04d", $m);
  $ret .= $part;

  return $ret;
}

######
# Order number of a bootloader
#
sub bln {
  my ($mcu, $iotype, $config) = @_;
  return ($mcun{$mcu}*(0+@iotypes) + $iotypen{$iotype})*(0+@configs) + $confign{$config};
}

######
# Number of distinct bootloader that can be derived from this template
#
sub nderived {
  my ($mcu, $iotype, $config) = @_;

  die "unknown MCU $mcu" if ! exists $mcu{$mcu};
  my ($ngpio, $nin, $nout, $ninterrupts, $nwdt) = @{$mcu{$mcu}};
  die "unknown iotype $iotype" if ! exists $io{$iotype};
  my $ret = $io{$iotype}*$nwdt;

  $ret *= $ninterrupts if $config !~ /_hw/;

  if($config =~ /(lednop|dual)_/) {
    $ret *= 2*($ngpio + $nout) + 1; # LED polarity, output pin config and no LED specified
    $ngpio--;                   # Approximation: fewer GPIO pins available for next signal
  }

  if($config =~ /dual_/) {
    $ret *= $ngpio + $nout;     # CS
    $ngpio--;                   # Approximation: fewer GPIO pins available for next signal
  }

  if($iotype =~ /^swio/) {
    $ret *= $ngpio + $nout;     # TX
    $ret *= $ngpio - 1 + $nin;  # RX
  }

  return $ret;
}

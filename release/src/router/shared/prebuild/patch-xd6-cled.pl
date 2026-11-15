#!/usr/bin/perl
#
# RT-AX82_XD6 links shared/prebuild objects from RT-AX95Q (ZenWiFi XT8).
# The XT8 api-broadcom.o drives the single RGB status LED through the BCM
# CLED controller with LED numbers hardcoded for the BCM47622 board:
#
#   XT8  (47622): R = led14, G = led15, B = led16, activate mask 0x0001C000
#   XD6  (63178): R = led7,  G = led8,  B = led9,  activate mask 0x00000380
#
# On XD6 the RGB LED sits on GPIO 2/3/4, which the 63178 pinmux routes to
# CLED channels 7/8/9 (see boardparms_63178.c / pinmux_table_63178.c).
# Without this patch bcm_cled_ctrl() writes to unused channels, so the LED
# keeps blinking from boot and LED on/off in the web UI has no effect.
#
# The path strings live in fixed-size char arrays, so a one byte shorter
# string padded with NUL keeps every offset intact.
#
# Usage: patch-xd6-cled.pl shared/prebuild/api-broadcom.o

use strict;
use warnings;

my $file = shift or die "usage: $0 <api-broadcom.o>\n";

open(my $in, '<:raw', $file) or die "$file: $!\n";
my $data = do { local $/; <$in> };
close($in);

my $total = 0;
my %map = (14 => 7, 15 => 8, 16 => 9);

foreach my $from (sort keys %map) {
	my $to = $map{$from};
	my $n = ($data =~ s{/proc/bcm_cled/led$from/config(\d)\0}{/proc/bcm_cled/led$to/config$1\0\0}g) || 0;
	if ($n == 0 && $data =~ m{/proc/bcm_cled/led$to/config\d\0}) {
		print "patch-xd6-cled: led$from already mapped to led$to\n";
		next;
	}
	die "patch-xd6-cled: expected 4 config paths for led$from, found $n\n" if $n != 4;
	$total += $n;
}

my $m = ($data =~ s{0x0001C000\0}{0x00000380\0}g) || 0;
if ($m == 0 && index($data, "0x00000380\0") < 0) {
	die "patch-xd6-cled: CLED activate mask 0x0001C000 not found\n";
}
die "patch-xd6-cled: activate mask found $m times, expected 1\n" if $m > 1;
$total += $m;

open(my $out, '>:raw', $file) or die "$file: $!\n";
print $out $data;
close($out);

print "patch-xd6-cled: $file patched ($total replacements)\n";
exit 0;

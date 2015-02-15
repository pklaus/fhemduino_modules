package main;

use strict;
use warnings;

##################################################
# Forward declarations
#
sub FHEMduino_MAX31850_Initialize($);
sub FHEMduino_MAX31850_Define($$);
sub FHEMduino_MAX31850_Undef($$);
sub FHEMduino_MAX31850_Parse($$);
sub FHEMduino_MAX31850_Attr(@);

sub
FHEMduino_MAX31850_Initialize($)
{
  my ($hash) = @_;

  $hash->{Match}     = "^y.........................";
  $hash->{DefFn}     = "FHEMduino_MAX31850_Define";
  $hash->{UndefFn}   = "FHEMduino_MAX31850_Undef";
  $hash->{AttrFn}    = "FHEMduino_MAX31850_Attr";
  $hash->{ParseFn}   = "FHEMduino_MAX31850_Parse";
  $hash->{AttrList}  = "IODev do_not_notify:0,1 showtime:0,1 ".
                       "ignore:0,1 roundTemperatureDecimal:0,1,2 ".$readingFnAttributes;
}

sub
FHEMduino_MAX31850_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  return "wrong syntax: define <name> FHEMduino_MAX31850 <code>".int(@a)
  if(int(@a) != 3);

  $hash->{CODE} = $a[2];
  $modules{FHEMduino_MAX31850}{defptr}{$a[2]} = $hash;
  AssignIoPort($hash);
  return undef;
}

sub
FHEMduino_MAX31850_Undef($$)
{
  my ($hash, $name) = @_;
  delete($modules{FHEMduino_MAX31850}{defptr}{$hash->{CODE}}) if($hash && $hash->{CODE});
  return undef;
}

sub
FHEMduino_MAX31850_Parse($$)
{
  my ($hash,$msg) = @_;
  
  # output format is "y IIIIIIIIIIIIIIII TTTTTTT"
  #                   01234567890123456789012345
  #   I = 64-bit 1-wire ID
  #   T = Signed temperature multiplied with 100
  #
  # for example:
  # y 3b532a18000000b4 +003175
  #   64-bit 1-wire ID   +31.75 deg C

  my @a = split(" ", $msg);

  #my $deviceCode = $a[1];
  my $deviceCode = substr($a[1], 0, 4);
  
  my $def = $modules{FHEMduino_MAX31850}{defptr}{$hash->{NAME} . "." . $deviceCode};
  $def = $modules{FHEMduino_MAX31850}{defptr}{$deviceCode} if(!$def);
  if(!$def) {
    Log3 $hash, 1, "FHEMduino_MAX31850 UNDEFINED sensor detected, code $deviceCode";
    return "UNDEFINED FHEMduino_MAX31850_$deviceCode FHEMduino_MAX31850 $deviceCode";
  }
  
  $hash = $def;
  my $name = $hash->{NAME};
  return "" if(IsIgnored($name));
  
  my $val = "";
  my ($temperature);

  $temperature = sprintf(
    '%.' . AttrVal($hash->{NAME}, 'roundTemperatureDecimal', 1) . 'f',
    int($a[2])/100.0
  );

  $val = "T: $temperature";

  if(!$val) {
    Log3 $name, 1, "FHEMduino_MAX31850 $deviceCode Cannot decode $msg";
    return "";
  }
  $hash->{lastReceive} = time();
  $hash->{lastValues}{temperature} = $temperature;

  Log3 $name, 4, "FHEMduino_MAX31850 $name: $val";

  readingsBeginUpdate($hash);
  readingsBulkUpdate($hash, "state", $val);
  readingsBulkUpdate($hash, "temperature", $temperature);
  readingsEndUpdate($hash, 1);

  return $name;
}

sub
FHEMduino_MAX31850_Attr(@)
{
  my @a = @_;

  # Make possible to use the same code for different logical devices when they
  # are received through different physical devices.
  return if($a[0] ne "set" || $a[2] ne "IODev");
  my $hash = $defs{$a[1]};
  my $iohash = $defs{$a[3]};
  my $cde = $hash->{CODE};
  delete($modules{FHEMduino_MAX31850}{defptr}{$cde});
  $modules{FHEMduino_MAX31850}{defptr}{$iohash->{NAME} . "." . $cde} = $hash;
  return undef;
}

1;


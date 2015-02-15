package main;

use strict;
use warnings;

##################################################
# Forward declarations
#
sub FHEMduino_BMP183_Initialize($);
sub FHEMduino_BMP183_Define($$);
sub FHEMduino_BMP183_Undef($$);
sub FHEMduino_BMP183_Parse($$);
sub FHEMduino_BMP183_Attr(@);

sub
FHEMduino_BMP183_Initialize($)
{
  my ($hash) = @_;

  $hash->{Match}     = "^P................";
  $hash->{DefFn}     = "FHEMduino_BMP183_Define";
  $hash->{UndefFn}   = "FHEMduino_BMP183_Undef";
  $hash->{AttrFn}    = "FHEMduino_BMP183_Attr";
  $hash->{ParseFn}   = "FHEMduino_BMP183_Parse";
  $hash->{AttrList}  = "IODev do_not_notify:0,1 showtime:0,1 ".
                       "ignore:0,1 roundPressureDecimal:0,1,2 ".
                       "roundTemperatureDecimal:0,1,2 ".$readingFnAttributes;
}

sub
FHEMduino_BMP183_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  return "wrong syntax: define <name> FHEMduino_BMP183 <code>".int(@a)
  if(int(@a) != 3);

  $hash->{CODE} = $a[2];
  $modules{FHEMduino_BMP183}{defptr}{$a[2]} = $hash;
  AssignIoPort($hash);
  return undef;
}

sub
FHEMduino_BMP183_Undef($$)
{
  my ($hash, $name) = @_;
  delete($modules{FHEMduino_BMP183}{defptr}{$hash->{CODE}}) if($hash && $hash->{CODE});
  return undef;
}

sub
FHEMduino_BMP183_Parse($$)
{
  my ($hash,$msg) = @_;
  
  # output format is "P II TTTTT PPPPPP"
  #                   01234567890123456
  #     II = ID
  #   TTTT = Signed temperature multiplied with 10
  # PPPPPP = Pressure in Pascal (pa)

  my @a = split(" ", $msg);

  my $deviceCode = $a[1];
  
  my $def = $modules{FHEMduino_BMP183}{defptr}{$hash->{NAME} . "." . $deviceCode};
  $def = $modules{FHEMduino_BMP183}{defptr}{$deviceCode} if(!$def);
  if(!$def) {
    Log3 $hash, 1, "FHEMduino_BMP183 UNDEFINED sensor detected, code $deviceCode";
    return "UNDEFINED FHEMduino_BMP183_$deviceCode FHEMduino_BMP183 $deviceCode";
  }
  
  $hash = $def;
  my $name = $hash->{NAME};
  return "" if(IsIgnored($name));
  
  my $val = "";
  my ($temperature, $pressure, $altitude, $pressureNN);

  $temperature = sprintf(
    '%.' . AttrVal($hash->{NAME}, 'roundTemperatureDecimal', 1) . 'f',
    int($a[2])/100.0
  );

  $pressure = sprintf(
    '%.' . AttrVal($hash->{NAME}, 'roundPressureDecimal', 1) . 'f',
    int($a[3])/100.0
  );

  $altitude = AttrVal('global', 'altitude', 0);
  $pressureNN = sprintf(
    '%.' . AttrVal($hash->{NAME}, 'roundPressureDecimal', 1) . 'f',
    # http://de.wikipedia.org/wiki/Barometrische_H%C3%B6henformel#Reduktion_auf_Meeresh.C3.B6he
    $pressure / ((1. - $altitude/44330.) ** 5.255)
    #$pressure * exp(9.80665/(287.05 * $temperature + 0.12 * E + 0.0065 * $altitude/2 ) * altitude)
  );
  
  $val = "T: $temperature P: $pressure P-NN: $pressureNN";

  if(!$val || $pressure < 300. || $pressure > 1100.0) {
    Log3 $name, 1, "FHEMduino_BMP183 $deviceCode Cannot decode $msg";
    return "";
  }
  $hash->{lastReceive} = time();
  $hash->{lastValues}{temperature} = $temperature;
  $hash->{lastValues}{pressure} = $pressure;
  $hash->{lastValues}{pressureNN} = $pressureNN;

  Log3 $name, 4, "FHEMduino_BMP183 $name: $val";

  readingsBeginUpdate($hash);
  readingsBulkUpdate($hash, "state", $val);
  readingsBulkUpdate($hash, "temperature", $temperature);
  readingsBulkUpdate($hash, "pressure", $pressure);
  readingsBulkUpdate($hash, "pressure-NN", $pressureNN);
  readingsEndUpdate($hash, 1);

  return $name;
}

sub
FHEMduino_BMP183_Attr(@)
{
  my @a = @_;

  # Make possible to use the same code for different logical devices when they
  # are received through different physical devices.
  return if($a[0] ne "set" || $a[2] ne "IODev");
  my $hash = $defs{$a[1]};
  my $iohash = $defs{$a[3]};
  my $cde = $hash->{CODE};
  delete($modules{FHEMduino_BMP183}{defptr}{$cde});
  $modules{FHEMduino_BMP183}{defptr}{$iohash->{NAME} . "." . $cde} = $hash;
  return undef;
}

1;

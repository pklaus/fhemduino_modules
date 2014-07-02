###########################################
# FHEMduino Oregon Scienfific Modul (Remote Weather sensor)
# $Id: 14_FHEMduino_Oregon.pm 0001 2014-06-25 sidey $
##############################################
package main;

use strict;
use warnings;


# TODO
# 
# * reset last reading einbauen

#####################################
sub
FHEMduino_Oregon_Initialize($)
{
# Jörg: Es fehlte das _Orgegon_

  my ($hash) = @_;

#					  9ADC539970205024
#					  EA4C10E45016D083
  # output format is "AAAACRRBTTTS"
  #                   
  # AAAA = Sensor Type on V2.1  **AA on V2.2   Nibble 0-3
  #   C = Channel							   Nibble 4
  #  RR = Rolling ID						   Nibble 5-6
  #   B = Battery							   Nibble 7
  #  TTT = Temperature in BCD Code			   Nibble 8-10
  #   S = Sign								   Nibble 11
  

  $hash->{Match}     = "^K...........";
  $hash->{DefFn}     = "FHEMduino_Oregon_Define";
  $hash->{UndefFn}   = "FHEMduino_Oregon_Undef";
  $hash->{AttrFn}    = "FHEMduino_Oregon_Attr";
  $hash->{ParseFn}   = "FHEMduino_Oregon_Parse";
  $hash->{AttrList}  = "IODev do_not_notify:0,1 showtime:0,1 ignore:0,1 ".$readingFnAttributes;
}


#####################################
sub
FHEMduino_Oregon_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  return "wrong syntax: define <name> FHEMduino_Oregon <code>".int(@a)
  if(int(@a) != 3);

  #return "Define $a[0]: wrong CODE format: valid is 1-8"
  #              if($a[2] !~ m/^[1-8]$/);

  $hash->{CODE} = $a[2];
  $modules{FHEMduino_Oregon}{defptr}{$a[2]} = $hash;
  AssignIoPort($hash);
  return undef;
}

#####################################
sub
FHEMduino_Oregon_Undef($$)
{
  my ($hash, $name) = @_;
  delete($modules{FHEMduino_Oregon}{defptr}{$hash->{CODE}}) if($hash && $hash->{CODE});
  return undef;
}

#########################################
# From xpl-perl/lib/xPL/Util.pm:
=head1
/* Jörg: Funktioniert in Perl nicht. Eigenlich kennt Perl nur # ... =head1 leitet eine Dokumentation ein
sub OREGON_hi_nibble {
  ($_[0]&0xf0)>>4;
}
sub OREGON_lo_nibble {
  $_[0]&0xf;
}
sub OREGON_nibble_sum {
  my $c = $_[0];
  my $s = 0;
  foreach (0..$_[0]-1) {
    $s += OREGON_hi_nibble($_[1]->[$_]);
    $s += OREGON_lo_nibble($_[1]->[$_]);
  }
  $s += OREGON_hi_nibble($_[1]->[$_[0]]) if (int($_[0]) != $_[0]);
  return $s;
}
*/ Jörg: =cut beendet die Doku
=cut
# --------------------------------------------
# The following functions are changed:
#	- some parameter like "parent" and others are removed
#	- @res array return the values directly (no usage of xPL::Message)

sub OREGON_temperature {
  my ($nibble, $dev, $res) = @_;

  my $temp =
    (($nibble->[11]&0x8) ? -1 : 1) *
      ($nibble->[9]*10 + $nibble->[10] +
       $nibble->[8])/10;

  push @$res, {
       		device => $dev,
       		type => 'temp',
       		current => $temp,
		units => 'Grad Celsius'
  	}
} # Jörg: Schliessende Klammer fehlte

sub OREGON_percentage_battery {
  my ($nibble, $dev, $res) = @_;

  my $battery;
  my $battery_level = 100-10*$nibble->[7];
  if ($battery_level > 50) {
    $battery = sprintf("ok %d%%",$battery_level);
  } else {
    $battery = sprintf("low %d%%",$battery_level);
  }

  push @$res, {
		device => $dev,
		type => 'battery',
		current => $battery,
		units => '%',
	}
}
	
#####################################
sub
FHEMduino_Oregon_Parse($$)
{
  my ($hash,$msg) = @_;
  my $deviceCode; # Jörg: muss deklariert sein. Deklaration im if/else funktioniert nicht.

  # -
  my @a = split("", $msg); # # Jörg: Auskommentieren geht nur mit #, nicht mit /
  my @a = unpack("(A2)*", $msg);
  
# Jörg: Was ist d und c, wo kommen die her?  
#  if ( $a[2] == d && $a[3] == c)
#  {
#    $deviceCode = $a[2].$a[3];
#  } else {
#    $deviceCode = $a[0].$a[1].$a[2].$a[3];
#  }
  
  my $def = $modules{FHEMduino_Oregon}{defptr}{$hash->{NAME} . "." . $deviceCode};
  $def = $modules{FHEMduino_Oregon}{defptr}{$deviceCode} if(!$def);
  if(!$def) {
    Log3 $hash, 1, "FHEMduino_Oregon UNDEFINED sensor detected, code $deviceCode";
    return "UNDEFINED FHEMduino_Oregon_$deviceCode FHEMduino_Oregon $deviceCode";
  }
  
  $hash = $def;
  my $name = $hash->{NAME};
  return "" if(IsIgnored($name));
  
  my $val = "";
  my ($tmp, $hum, $bat, $sendMode, $trend);

  
  $bat = int($a[3]) == "0" ? "good" : "critical";

  if (int($a[4]) == 1)
  {
    $trend = "rising";
  }
  elsif (int($a[4]) == 2)
  {
    $trend = "falling";
  }
  else
  {
    $trend = "stable";
  }
  

  $sendMode = int($a[5]) == 0 ? "automatic" : "manual";
  $tmp = int($a[6].$a[7].$a[8].$a[9])/10.0;
  $hum = int($a[10].$a[11]);
  
  $val = "T $tmp H $hum";


  if(!$val) {
    Log3 $name, 1, "FHEMduino_Oregon $deviceCode Cannot decode $msg";
    return "";
  }
  if ($hash->{lastReceive} && (time() - $hash->{lastReceive} < 300)) {
    if ($hash->{lastValues} && (abs(abs($hash->{lastValues}{temperature}) - abs($tmp)) > 5)) {
      Log3 $name, 1, "FHEMduino_Oregon $deviceCode Temperature jump too large";
      return "";
    }


    if ($hash->{lastValues} && (abs(abs($hash->{lastValues}{humidity}) - abs($hum)) > 5)) {
      Log3 $name, 1, "FHEMduino_Oregon $deviceCode Humidity jump too large";
      return "";
    }
  }
  else {
    Log3 $name, 1, "FHEMduino_Oregon $deviceCode Skipping override due to too large timedifference";
  }
  $hash->{lastReceive} = time();
  $hash->{lastValues}{temperature} = $tmp;
  $hash->{lastValues}{humidity} = $hum;


  Log3 $name, 4, "FHEMduino_Oregon $name: $val";

  readingsBeginUpdate($hash);
  readingsBulkUpdate($hash, "state", $val);
  readingsBulkUpdate($hash, "temperature", $tmp);
  readingsBulkUpdate($hash, "humidity", $hum);
  readingsBulkUpdate($hash, "battery", $bat);
  readingsBulkUpdate($hash, "trend", $trend);
  readingsBulkUpdate($hash, "sendMode", $sendMode);
  readingsEndUpdate($hash, 1); # Notify is done by Dispatch

  return $name;
}

sub
FHEMduino_Oregon_Attr(@)
{
  my @a = @_;

  # Make possible to use the same code for different logical devices when they
  # are received through different physical devices.
  return if($a[0] ne "set" || $a[2] ne "IODev");
  my $hash = $defs{$a[1]};
  my $iohash = $defs{$a[3]};
  my $cde = $hash->{CODE};
  delete($modules{FHEMduino_Oregon}{defptr}{$cde});
  $modules{FHEMduino_Oregon}{defptr}{$iohash->{NAME} . "." . $cde} = $hash;
  return undef;
}


1;

=pod
=begin html

<a name="FHEMduino_Oregon"></a>
<h3>FHEMduino_Oregon</h3>
<ul>
  The FHEMduino_Oregon module interprets Oregon Scientific Data of messages received by the FHEMduino.
  <br><br>

  <a name="FHEMduino_Oregondefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; FHEMduino_Oregon &lt;code&gt; [corr1...corr4]</code> <br>
    <br>
  </ul>
  <br>

  <a name="FHEMduino_Oregonset"></a>
  <b>Set</b> <ul>N/A</ul><br>

  <a name="FHEMduino_Oregonget"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a name="FHEMduino_Oregonattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#IODev">IODev (!)</a></li>
    <li><a href="#do_not_notify">do_not_notify</a></li>
    <li><a href="#eventMap">eventMap</a></li>
    <li><a href="#ignore">ignore</a></li>
    <li><a href="#model">model</a> (S300,KS300,ASH2200)</li>
    <li><a href="#showtime">showtime</a></li>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
  </ul>
  <br>
</ul>

=end html
=cut

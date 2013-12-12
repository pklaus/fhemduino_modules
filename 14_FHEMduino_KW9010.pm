##############################################
# $Id: 14_FHEMduino_KW9010.pm 3818 2013-09-22 $
package main;

use strict;
use warnings;


# TODO
# 
# * reset last reading einbauen

#####################################
sub
FHEMduino_KW9010_Initialize($)
{
  my ($hash) = @_;

  # output format is "KIICBFTTTTHH"
  #                   012345678901
  #   II = ID
  #    C = Channel
  #    B = Battery State
  #    F = Forced Send
  # TTTT = Signed temperature multiplied with 10
  #   HH = Humidity

  $hash->{Match}     = "^K...........";
  $hash->{DefFn}     = "FHEMduino_KW9010_Define";
  $hash->{UndefFn}   = "FHEMduino_KW9010_Undef";
  $hash->{AttrFn}    = "FHEMduino_KW9010_Attr";
  $hash->{ParseFn}   = "FHEMduino_KW9010_Parse";
  $hash->{AttrList}  = "IODev do_not_notify:0,1 showtime:0,1 ignore:0,1 ".$readingFnAttributes;
}


#####################################
sub
FHEMduino_KW9010_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  return "wrong syntax: define <name> FHEMduino_KW9010 <code>".int(@a)
  if(int(@a) != 3);

  #return "Define $a[0]: wrong CODE format: valid is 1-8"
  #              if($a[2] !~ m/^[1-8]$/);

  $hash->{CODE} = $a[2];
  $modules{FHEMduino_KW9010}{defptr}{$a[2]} = $hash;
  AssignIoPort($hash);
  return undef;
}

#####################################
sub
FHEMduino_KW9010_Undef($$)
{
  my ($hash, $name) = @_;
  delete($modules{FHEMduino_KW9010}{defptr}{$hash->{CODE}}) if($hash && $hash->{CODE});
  return undef;
}


#####################################
sub
FHEMduino_KW9010_Parse($$)
{
  my ($hash,$msg) = @_;
  
  # -wusel, 2010-01-24: *sigh* No READINGS set, bad for other modules. Trying
  # to add setting READINGS as well as STATE ...

  my @a = split("", $msg);

  # 01234567890
  # KE700+24160
  
  my $deviceCode = $a[1].$a[2];
  
  my $def = $modules{FHEMduino_KW9010}{defptr}{$hash->{NAME} . "." . $deviceCode};
  $def = $modules{FHEMduino_KW9010}{defptr}{$deviceCode} if(!$def);
  if(!$def) {
    Log3 $hash, 1, "FHEMduino_KW9010 UNDEFINED sensor detected, code $deviceCode";
    return "UNDEFINED FHEMduino_KW9010_$deviceCode FHEMduino_KW9010 $deviceCode";
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
  
  $val = "T $tmp H $hum B $bat";


  if(!$val) {
    Log3 $name, 1, "FHEMduino_KW9010 $deviceCode Cannot decode $msg";
    return "";
  }
  if ($hash->{lastReceive} && (time() - $hash->{lastReceive} < 300)) {
    if ($hash->{lastValues} && (abs(abs($hash->{lastValues}{temperature}) - abs($tmp)) > 5)) {
      Log3 $name, 1, "FHEMduino_KW9010 $deviceCode Temperature jump too large";
      return "";
    }


    if ($hash->{lastValues} && (abs(abs($hash->{lastValues}{humidity}) - abs($hum)) > 5)) {
      Log3 $name, 1, "FHEMduino_KW9010 $deviceCode Humidity jump too large";
      return "";
    }
  }
  else {
    Log3 $name, 1, "FHEMduino_KW9010 $deviceCode Skipping override due to too large timedifference";
  }
  $hash->{lastReceive} = time();
  $hash->{lastValues}{temperature} = $tmp;
  $hash->{lastValues}{humidity} = $hum;


  Log3 $name, 4, "FHEMduino_KW9010 $name: $val";

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
FHEMduino_KW9010_Attr(@)
{
  my @a = @_;

  # Make possible to use the same code for different logical devices when they
  # are received through different physical devices.
  return if($a[0] ne "set" || $a[2] ne "IODev");
  my $hash = $defs{$a[1]};
  my $iohash = $defs{$a[3]};
  my $cde = $hash->{CODE};
  delete($modules{FHEMduino_KW9010}{defptr}{$cde});
  $modules{FHEMduino_KW9010}{defptr}{$iohash->{NAME} . "." . $cde} = $hash;
  return undef;
}


1;

=pod
=begin html

<a name="FHEMduino_KW9010"></a>
<h3>FHEMduino_KW9010</h3>
<ul>
  The FHEMduino_KW9010 module interprets S300 type of messages received by the FHEMduino.
  <br><br>

  <a name="FHEMduino_KW9010define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; FHEMduino_KW9010 &lt;code&gt; [corr1...corr4]</code> <br>
    <br>
    &lt;code&gt; is the code which must be set on the S300 device. Valid values
    are 1 through 8.<br>
    corr1..corr4 are up to 4 numerical correction factors, which will be added
    to the respective value to calibrate the device. Note: rain-values will be
    multiplied and not added to the correction factor.
  </ul>
  <br>

  <a name="FHEMduino_KW9010set"></a>
  <b>Set</b> <ul>N/A</ul><br>

  <a name="FHEMduino_KW9010get"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a name="FHEMduino_KW9010attr"></a>
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

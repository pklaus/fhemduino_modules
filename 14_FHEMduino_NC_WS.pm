##############################################
# $Id: 14_FHEMduino_NC_WS.pm 3818 2014-06-13 $
package main;

use strict;
use warnings;

#####################################
sub
FHEMduino_NC_WS_Initialize($)
{
  my ($hash) = @_;

  # output format is "LCAABRFTTTTHH"
  #                   L24c001+29435
  #                   0123456789ABC
  #     C = Channel
  #     A = Address (change every battery change)
  #     B = Battery State
  #     R = Unknown
  #     F = Forced Send
  #  TTTT = Signed temperature multiplied with 10
  #    HH = Humidity

  $hash->{Match}     = "^L............";
  $hash->{DefFn}     = "FHEMduino_NC_WS_Define";
  $hash->{UndefFn}   = "FHEMduino_NC_WS_Undef";
  $hash->{AttrFn}    = "FHEMduino_NC_WS_Attr";
  $hash->{ParseFn}   = "FHEMduino_NC_WS_Parse";
  $hash->{AttrList}  = "IODev do_not_notify:0,1 showtime:0,1 ignore:0,1 ".$readingFnAttributes;
  $hash->{AutoCreate}=
        { "FHEMduino_NC_WS.*" => { GPLOT => "temp4hum4:Temp/Hum,", FILTER => "%NAME" } };
}


#####################################
sub
FHEMduino_NC_WS_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  return "wrong syntax: define <name> FHEMduino_NC_WS <code> <minsecs> <equalmsg>".int(@a)
		if(int(@a) < 3 || int(@a) > 5);

  $hash->{CODE}    = $a[2];
  $hash->{minsecs} = ((int(@a) > 3) ? $a[3] : 0);
  $hash->{equalMSG} = ((int(@a) > 4) ? $a[4] : 0);
  $hash->{lastMSG} =  "";

  $modules{FHEMduino_NC_WS}{defptr}{$a[2]} = $hash;
  $hash->{STATE} = "Defined";

  AssignIoPort($hash);
  return undef;
}

#####################################
sub
FHEMduino_NC_WS_Undef($$)
{
  my ($hash, $name) = @_;
  delete($modules{FHEMduino_NC_WS}{defptr}{$hash->{CODE}}) if($hash && $hash->{CODE});
  return undef;
}

#####################################
sub
FHEMduino_NC_WS_Parse($$)
{
  my ($hash,$msg) = @_;
  my @a = split("", $msg);

  # 0123456789ABC
  # L24c001+29435
  
  my $deviceCode = $a[1]."_".$a[2].$a[3];
  
  my $def = $modules{FHEMduino_NC_WS}{defptr}{$hash->{NAME} . "." . $deviceCode};
  $def = $modules{FHEMduino_NC_WS}{defptr}{$deviceCode} if(!$def);
  if(!$def) {
    Log3 $hash, 1, "FHEMduino_NC_WS UNDEFINED sensor detected, code $deviceCode";
    return "UNDEFINED FHEMduino_NC_WS_$deviceCode FHEMduino_NC_WS $deviceCode";
  }
  
  $hash = $def;
  my $name = $hash->{NAME};
  return "" if(IsIgnored($name));
  
  Log3 $name, 4, "FHEMduino_NC_WS $name ($msg)";  
  
  if($hash->{lastReceive} && (time() - $hash->{lastReceive} < $def->{minsecs} )) {
    if (($def->{lastMSG} ne $msg) && ($def->{equalMSG} > 0)) {
      Log3 $name, 4, "FHEMduino_NC_WS $name: $deviceCode no skipping due unequal message even if to short timedifference";
    } else {
      Log3 $name, 4, "FHEMduino_NC_WS $name: $deviceCode Skipping due to short timedifference";
      return "";
    }
  }

  my $val = "";
  my ($tmp, $hum, $bat, $sendMode, $unknown);

  $bat = int($a[4]) == "0" ? "ok" : "critical";

  $unknown = int($a[5]);
  
  $sendMode = int($a[6]) == 0 ? "automatic" : "manual";
  $tmp = int($a[7].$a[8].$a[9].$a[10])/10.0;
  $hum = int($a[11].$a[12]);
  
  $val = "T: $tmp H: $hum B: $bat";

  if(!$val) {
    Log3 $name, 1, "FHEMduino_NC_WS $deviceCode Cannot decode $msg";
    return "";
  }
  
  if ($hash->{lastReceive} && (time() - $hash->{lastReceive} < 300)) {
    if ($hash->{lastValues} && (abs(abs($hash->{lastValues}{temperature}) - abs($tmp)) > 5)) {
      Log3 $name, 4, "FHEMduino_NC_WS $name: $deviceCode Temperature jump too large";
      return "";
    }

    if ($hash->{lastValues} && (abs(abs($hash->{lastValues}{humidity}) - abs($hum)) > 5)) {
      Log3 $name, 4, "FHEMduino_NC_WS $name: $deviceCode Humidity jump too large";
      return "";
    }
  }
  else {
    Log3 $name, 4, "FHEMduino_NC_WS $name: $deviceCode Skipping override due to too large timedifference";
  }

  $hash->{lastReceive} = time();
  $hash->{lastValues}{temperature} = $tmp;
  $hash->{lastValues}{humidity} = $hum;
  $def->{lastMSG} = $msg;

  Log3 $name, 4, "FHEMduino_NC_WS $name: $val";

  readingsBeginUpdate($hash);
  readingsBulkUpdate($hash, "state", $val);
  readingsBulkUpdate($hash, "temperature", $tmp);
  readingsBulkUpdate($hash, "humidity", $hum);
  readingsBulkUpdate($hash, "battery", $bat);
  readingsBulkUpdate($hash, "sendMode", $sendMode);
  readingsBulkUpdate($hash, "unknown", $unknown);
  readingsEndUpdate($hash, 1); # Notify is done by Dispatch

  return $name;
}

sub
FHEMduino_NC_WS_Attr(@)
{
  my @a = @_;

  # Make possible to use the same code for different logical devices when they
  # are received through different physical devices.
  return if($a[0] ne "set" || $a[2] ne "IODev");
  my $hash = $defs{$a[1]};
  my $iohash = $defs{$a[3]};
  my $cde = $hash->{CODE};
  delete($modules{FHEMduino_NC_WS}{defptr}{$cde});
  $modules{FHEMduino_NC_WS}{defptr}{$iohash->{NAME} . "." . $cde} = $hash;
  return undef;
}

1;

=pod
=begin html

<a name="FHEMduino_NC_WS"></a>
<h3>FHEMduino_NC_WS</h3>
<ul>
  The FHEMduino_NC_WS module interprets LogiLink NC_WS type of messages received by the FHEMduino.
  <br><br>

  <a name="FHEMduino_NC_WSdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; FHEMduino_NC_WS &lt;code&gt; [minsecs] [equalmsg]</code> <br>

    <br>
    &lt;code&gt; is the housecode of the autogenerated address of the NC_WS device and 
	is build by the channelnumber (1 to 3) and an autogenerated address build when including
	the battery (adress will change every time changing the battery).<br>
    minsecs are the minimum seconds between two log entries or notifications
    from this device. <br>E.g. if set to 300, logs of the same type will occure
    with a minimum rate of one per 5 minutes even if the device sends a message
    every minute. (Reduces the log file size and reduces the time to display
    the plots)<br>
	equalmsg set to 1 generates, if even if minsecs is set, a log entrie or notification
	when the msg content has changed.
  </ul>
  <br>

  <a name="FHEMduino_NC_WSset"></a>
  <b>Set</b> <ul>N/A</ul><br>

  <a name="FHEMduino_NC_WSget"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a name="FHEMduino_NC_WSattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#IODev">IODev (!)</a></li>
    <li><a href="#do_not_notify">do_not_notify</a></li>
    <li><a href="#eventMap">eventMap</a></li>
    <li><a href="#ignore">ignore</a></li>
    <li><a href="#model">model</a> (LogiLink NC_WS)</li>
    <li><a href="#showtime">showtime</a></li>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
  </ul>
  <br>
</ul>

=end html

=begin html_DE

<a name="FHEMduino_NC_WS"></a>
<h3>FHEMduino_NC_WS</h3>
<ul>
  Das FHEMduino_NC_WS module dekodiert vom FHEMduino empfangene Nachrichten des LogiLink NC_WS.
  <br><br>

  <a name="FHEMduino_NC_WSdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; FHEMduino_NC_WS &lt;code&gt; [minsecs] [equalmsg]</code> <br>

    <br>
    &lt;code&gt; ist der automatisch angelegte Hauscode des NC_WS und besteht aus der
	Kanalnummer (1..3) und einer Zufallsadresse, die durch das Gerät beim einlegen der
	Batterie generiert wird (Die Adresse ändert sich bei jedem Batteriewechsel).<br>
    minsecs definert die Sekunden die mindesten vergangen sein müssen bis ein neuer
	Logeintrag oder eine neue Nachricht generiert werden.
    <br>
	Z.B. wenn 300, werden Einträge nur alle 5 Minuten erzeugt, auch wenn das Device
    alle paar Sekunden eine Nachricht generiert. (Reduziert die Log-Dateigröße und die Zeit
	die zur Anzeige von Plots benötigt wird.)<br>
	equalmsg gesetzt auf 1 legt fest, dass Einträge auch dann erzeugt werden wenn die durch
	minsecs vorgegebene Zeit noch nicht verstrichen ist, sich aber der Nachrichteninhalt geändert
	hat.
  </ul>
  <br>

  <a name="FHEMduino_NC_WSset"></a>
  <b>Set</b> <ul>N/A</ul><br>

  <a name="FHEMduino_NC_WSget"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a name="FHEMduino_NC_WSattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#IODev">IODev (!)</a></li>
    <li><a href="#do_not_notify">do_not_notify</a></li>
    <li><a href="#eventMap">eventMap</a></li>
    <li><a href="#ignore">ignore</a></li>
    <li><a href="#model">model</a> (LogiLink NC_WS)</li>
    <li><a href="#showtime">showtime</a></li>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
  </ul>
  <br>
</ul>

=end html_DE
=cut

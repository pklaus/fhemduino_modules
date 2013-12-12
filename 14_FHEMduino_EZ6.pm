##############################################
# $Id: 14_RFduino_EZ6.pm 3818 2013-09-22 $
package main;

use strict;
use warnings;

# Supports following devices:
# KS300TH     (this is redirected to the more sophisticated 14_KS300 by 00_RFduino)
# S300TH  
# WS2000/WS7000
#

#####################################
sub
RFduino_EZ6_Initialize($)
{
  my ($hash) = @_;

  # Message is like
  # EZ0A12+164000
  $hash->{Match}     = "^E...........";
  $hash->{DefFn}     = "RFduino_EZ6_Define";
  $hash->{UndefFn}   = "RFduino_EZ6_Undef";
  $hash->{AttrFn}    = "RFduino_EZ6_Attr";
  $hash->{ParseFn}   = "RFduino_EZ6_Parse";
  $hash->{AttrList}  = "IODev do_not_notify:0,1 showtime:0,1 ignore:0,1 ".
                       $readingFnAttributes;
}


#####################################
sub
RFduino_EZ6_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  return "wrong syntax: define <name> RFduino_EZ6 <code>".int(@a)
            if(int(@a) != 3);
			
  #return "Define $a[0]: wrong CODE format: valid is 1-8"
  #              if($a[2] !~ m/^[1-8]$/);

  $hash->{CODE} = $a[2];
  $modules{RFduino_EZ6}{defptr}{$a[2]} = $hash;
  AssignIoPort($hash);
  return undef;
}

#####################################
sub
RFduino_EZ6_Undef($$)
{
  my ($hash, $name) = @_;
  delete($modules{RFduino_EZ6}{defptr}{$hash->{CODE}}) if($hash && $hash->{CODE});
  return undef;
}


#####################################
sub
RFduino_EZ6_Parse($$)
{
  my ($hash,$msg) = @_;
  
  # -wusel, 2010-01-24: *sigh* No READINGS set, bad for other modules. Trying
  # to add setting READINGS as well as STATE ...

  my @a = split("", $msg);
  
  # E0A12+164000
  #  12345678901
  my $cde = $a[1].$a[2].$a[3];
  
  my $def = $modules{RFduino_EZ6}{defptr}{$hash->{NAME} . "." . $cde};
  $def = $modules{RFduino_EZ6}{defptr}{$cde} if(!$def);
  if(!$def) {
    Log3 $hash, 1, "RFduino_EZ6 UNDEFINED sensor detected, code $cde";
    return "UNDEFINED RFduino_EZ6_$cde RFduino_EZ6 $cde";
  }
  
  $hash = $def;
  my $name = $hash->{NAME};
  return "" if(IsIgnored($name));
  
  my $val = "";
  my ($sgn, $tmp, $hum, $bat);

  $bat = $a[4];
  $sgn = $a[5] == "+" ? 1 : -1;
  $tmp = $sgn * (int($a[6].$a[7].$a[8])/10);
  $hum = int($a[9].$a[10].$a[11]);
  
  $val = "T $tmp H $hum B $bat";
	  
  if(!$val) {
    Log3 $name, 1, "RFduino_EZ6 Cannot decode $msg";
    return "";
  }
  Log3 $name, 4, "RFduino_EZ6 $name: $val";

  readingsBeginUpdate($hash);
  readingsBulkUpdate($hash, "state", $val);
  readingsBulkUpdate($hash, "temperature", $tmp);
  readingsBulkUpdate($hash, "humidity", $hum);
  readingsBulkUpdate($hash, "battery", $bat);
  readingsEndUpdate($hash, 1); # Notify is done by Dispatch

  return $name;
}

sub
RFduino_EZ6_Attr(@)
{
  my @a = @_;

  # Make possible to use the same code for different logical devices when they
  # are received through different physical devices.
  return if($a[0] ne "set" || $a[2] ne "IODev");
  my $hash = $defs{$a[1]};
  my $iohash = $defs{$a[3]};
  my $cde = $hash->{CODE};
  delete($modules{RFduino_EZ6}{defptr}{$cde});
  $modules{RFduino_EZ6}{defptr}{$iohash->{NAME} . "." . $cde} = $hash;
  return undef;
}


1;

=pod
=begin html

<a name="RFduino_EZ6"></a>
<h3>RFduino_EZ6</h3>
<ul>
  The RFduino_EZ6 module interprets S300 type of messages received by the RFduino.
  <br><br>

  <a name="RFduino_EZ6define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; RFduino_EZ6 &lt;code&gt; [corr1...corr4]</code> <br>
    <br>
    &lt;code&gt; is the code which must be set on the S300 device. Valid values
    are 1 through 8.<br>
    corr1..corr4 are up to 4 numerical correction factors, which will be added
    to the respective value to calibrate the device. Note: rain-values will be
    multiplied and not added to the correction factor.
  </ul>
  <br>

  <a name="RFduino_EZ6set"></a>
  <b>Set</b> <ul>N/A</ul><br>

  <a name="RFduino_EZ6get"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a name="RFduino_EZ6attr"></a>
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

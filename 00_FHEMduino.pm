##############################################
# $Id: 00_FHEMduino.pm mdorenka $
package main;

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);

sub FHEMduino_Attr(@);
sub FHEMduino_Clear($);
sub FHEMduino_HandleCurRequest($$);
sub FHEMduino_HandleWriteQueue($);
sub FHEMduino_Parse($$$$);
sub FHEMduino_Read($);
sub FHEMduino_ReadAnswer($$$$);
sub FHEMduino_Ready($);
sub FHEMduino_Write($$$);

sub FHEMduino_SimpleWrite(@);

my %gets = (    # Name, Data to send to the FHEMduino, Regexp for the answer
  "version"  => ["V", '^V .*'],
  "raw"      => ["", '.*'],
  "uptime"   => ["t", '^[0-9A-F]{8}[\r\n]*$' ],
  "cmds"     => ["?", '.*Use one of[ 0-9A-Za-z]+[\r\n]*$' ],
);

my %sets = (
  "raw"       => "",
  "led"       => "",
  "patable"   => "",
  "time"      => ""
);

my $clientsSlowRF = ":IT:FHEMduino_EZ6:";

my %matchListSlowRF = (
    "1:IT"              => "^i......\$",
    "2:FHEMduino_EZ6"     => "E...........\$",
    "3:FHEMduino_KW9010"  => "K...........\$",
);

sub
FHEMduino_Initialize($)
{
  my ($hash) = @_;

  require "$attr{global}{modpath}/FHEM/DevIo.pm";

# Provider
  $hash->{ReadFn}  = "FHEMduino_Read";
  $hash->{WriteFn} = "FHEMduino_Write";
  $hash->{ReadyFn} = "FHEMduino_Ready";

# Normal devices
  $hash->{DefFn}   = "FHEMduino_Define";
  $hash->{FingerprintFn} = "FHEMduino_FingerprintFn";
  $hash->{UndefFn} = "FHEMduino_Undef";
  $hash->{GetFn}   = "FHEMduino_Get";
  $hash->{SetFn}   = "FHEMduino_Set";
  $hash->{AttrFn}  = "FHEMduino_Attr";
  $hash->{AttrList}= "do_not_notify:1,0 dummy:1,0 showtime:1,0 sendpool addvaltrigger";

  $hash->{ShutdownFn} = "FHEMduino_Shutdown";

}

sub
FHEMduino_FingerprintFn($$)
{
  my ($name, $msg) = @_;
 
  # Store only the "relevant" part, as the FHEMduino won't compute the checksum
  $msg = substr($msg, 8) if($msg =~ m/^81/ && length($msg) > 8);
 
  return ($name, $msg);
}

#####################################
sub
FHEMduino_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  if(@a != 3) {
    my $msg = "wrong syntax: define <name> FHEMduino {none | devicename[\@baudrate] | devicename\@directio | hostname:port}";
    Log3 undef, 2, $msg;
    return $msg;
  }

  DevIo_CloseDev($hash);

  my $name = $a[0];
  my $dev = $a[2];
  
  $hash->{CMDS} = "";
  $hash->{Clients} = $clientsSlowRF;
  $hash->{MatchList} = \%matchListSlowRF;

  if($dev eq "none") {
    Log3 $name, 1, "$name device is none, commands will be echoed only";
    $attr{$name}{dummy} = 1;
    return undef;
  }
  
  $hash->{DeviceName} = $dev;
  my $ret = DevIo_OpenDev($hash, 0, "FHEMduino_DoInit");
  return $ret;
}

#####################################
sub
FHEMduino_Undef($$)
{
  my ($hash, $arg) = @_;
  my $name = $hash->{NAME};

  foreach my $d (sort keys %defs) {
    if(defined($defs{$d}) &&
       defined($defs{$d}{IODev}) &&
       $defs{$d}{IODev} == $hash)
      {
        my $lev = ($reread_active ? 4 : 2);
        Log3 $name, $lev, "deleting port for $d";
        delete $defs{$d}{IODev};
      }
  }

  FHEMduino_SimpleWrite($hash, "X00"); # Switch reception off, it may hang up the FHEMduino
  DevIo_CloseDev($hash); 
  return undef;
}

#####################################
sub
FHEMduino_Shutdown($)
{
  my ($hash) = @_;
  FHEMduino_SimpleWrite($hash, "X00");
  return undef;
}

#####################################
sub
FHEMduino_Set($@)
{
  my ($hash, @a) = @_;

  return "\"set FHEMduino\" needs at least one parameter" if(@a < 2);
  return "Unknown argument $a[1], choose one of " . join(" ", sort keys %sets)
  	if(!defined($sets{$a[1]}));

  my $name = shift @a;
  my $type = shift @a;
  my $arg = join("", @a);

  return "This command is not valid in the current rfmode"
      if($sets{$type} && $sets{$type} ne AttrVal($name, "rfmode", "SlowRF"));

   ###############################################  raw,led,patable

    return "Expecting a 0-padded hex number"
        if((length($arg)&1) == 1 && $type ne "raw");
    Log3 $name, 3, "set $name $type $arg";
    $arg = "l$arg" if($type eq "led");
    $arg = "x$arg" if($type eq "patable");
    FHEMduino_SimpleWrite($hash, $arg);

  return undef;
}

#####################################
sub
FHEMduino_Get($@)
{
  my ($hash, @a) = @_;
  my $type = $hash->{TYPE};

  return "\"get $type\" needs at least one parameter" if(@a < 2);
  if(!defined($gets{$a[1]})) {
    my @cList = map { $_ =~ m/^(file|raw)$/ ? $_ : "$_:noArg" } sort keys %gets;
    return "Unknown argument $a[1], choose one of " . join(" ", @cList);
  }

  my $arg = ($a[2] ? $a[2] : "");
  my ($msg, $err);
  my $name = $a[0];

  return "No $a[1] for dummies" if(IsDummy($name));

  
    FHEMduino_SimpleWrite($hash, $gets{$a[1]}[0] . $arg);
    ($err, $msg) = FHEMduino_ReadAnswer($hash, $a[1], 0, $gets{$a[1]}[1]);
    if(!defined($msg)) {
      DevIo_Disconnected($hash);
      $msg = "No answer";

    } elsif($a[1] eq "cmds") {       # nice it up
      $msg =~ s/.*Use one of//g;

    } elsif($a[1] eq "uptime") {     # decode it
      $msg =~ s/[\r\n]//g;
      $msg = hex($msg)/125;
      $msg = sprintf("%d %02d:%02d:%02d",
        $msg/86400, ($msg%86400)/3600, ($msg%3600)/60, $msg%60);
    }

    $msg =~ s/[\r\n]//g;

  $hash->{READINGS}{$a[1]}{VAL} = $msg;
  $hash->{READINGS}{$a[1]}{TIME} = TimeNow();

  return "$a[0] $a[1] => $msg";
}

sub
FHEMduino_Clear($)
{
  my $hash = shift;

  # Clear the pipe
  $hash->{RA_Timeout} = 0.1;
  for(;;) {
    my ($err, undef) = FHEMduino_ReadAnswer($hash, "Clear", 0, undef);
    last if($err && $err =~ m/^Timeout/);
  }
  delete($hash->{RA_Timeout});
}

#####################################
sub
FHEMduino_DoInit($)
{
  my $hash = shift;
  my $name = $hash->{NAME};
  my $err;
  my $msg = undef;

  FHEMduino_Clear($hash);
  my ($ver, $try) = ("", 0);
  while ($try++ < 3 && $ver !~ m/^V/) {
    FHEMduino_SimpleWrite($hash, "V");
    ($err, $ver) = FHEMduino_ReadAnswer($hash, "Version", 0, undef);
    return "$name: $err" if($err && ($err !~ m/Timeout/ || $try == 3));
    $ver = "" if(!$ver);
  }

  if($ver !~ m/^V/) {
    $attr{$name}{dummy} = 1;
    $msg = "Not an FHEMduino device, got for V:  $ver";
    Log3 $name, 1, $msg;
    return $msg;
  }
  $ver =~ s/[\r\n]//g;
  $hash->{VERSION} = $ver;

  # Cmd-String feststellen

  my $cmds = FHEMduino_Get($hash, $name, "cmds", 0);
  $cmds =~ s/$name cmds =>//g;
  $cmds =~ s/ //g;
  $hash->{CMDS} = $cmds;
  Log3 $name, 3, "$name: Possible commands: " . $hash->{CMDS};

  $hash->{STATE} = "Initialized";

  # Reset the counter
  delete($hash->{XMIT_TIME});
  delete($hash->{NR_CMD_LAST_H});
  return undef;
}

#####################################
# This is a direct read for commands like get
# Anydata is used by read file to get the filesize
sub
FHEMduino_ReadAnswer($$$$)
{
  my ($hash, $arg, $anydata, $regexp) = @_;
  my $type = $hash->{TYPE};

  while($hash->{TYPE} eq "FHEMduino_RFR") {   # Look for the first "real" FHEMduino
    $hash = $hash->{IODev};
  }

  return ("No FD", undef)
        if(!$hash || ($^O !~ /Win/ && !defined($hash->{FD})));

  my ($mFHEMduinodata, $rin) = ("", '');
  my $buf;
  my $to = 3;                                         # 3 seconds timeout
  $to = $hash->{RA_Timeout} if($hash->{RA_Timeout});  # ...or less
  for(;;) {

    if($^O =~ m/Win/ && $hash->{USBDev}) {
      $hash->{USBDev}->read_const_time($to*1000); # set timeout (ms)
      # Read anstatt input sonst funzt read_const_time nicht.
      $buf = $hash->{USBDev}->read(999);          
      return ("Timeout reading answer for get $arg", undef)
        if(length($buf) == 0);

    } else {
      return ("Device lost when reading answer for get $arg", undef)
        if(!$hash->{FD});

      vec($rin, $hash->{FD}, 1) = 1;
      my $nfound = select($rin, undef, undef, $to);
      if($nfound < 0) {
        next if ($! == EAGAIN() || $! == EINTR() || $! == 0);
        my $err = $!;
        DevIo_Disconnected($hash);
        return("FHEMduino_ReadAnswer $arg: $err", undef);
      }
      return ("Timeout reading answer for get $arg", undef)
        if($nfound == 0);
      $buf = DevIo_SimpleRead($hash);
      return ("No data", undef) if(!defined($buf));

    }

    if($buf) {
      Log3 $hash->{NAME}, 5, "FHEMduino/RAW (ReadAnswer): $buf";
      $mFHEMduinodata .= $buf;
    }
    $mFHEMduinodata = FHEMduino_RFR_DelPrefix($mFHEMduinodata) if($type eq "FHEMduino_RFR");

    # \n\n is socat special
    if($mFHEMduinodata =~ m/\r\n/ || $anydata || $mFHEMduinodata =~ m/\n\n/ ) {
      if($regexp && $mFHEMduinodata !~ m/$regexp/) {
        FHEMduino_Parse($hash, $hash, $hash->{NAME}, $mFHEMduinodata);
      } else {
        return (undef, $mFHEMduinodata)
      }
    }
  }

}

#####################################
# Check if the 1% limit is reached and trigger notifies
sub
FHEMduino_XmitLimitCheck($$)
{
  my ($hash,$fn) = @_;
  my $now = time();

  if(!$hash->{XMIT_TIME}) {
    $hash->{XMIT_TIME}[0] = $now;
    $hash->{NR_CMD_LAST_H} = 1;
    return;
  }

  my $nowM1h = $now-3600;
  my @b = grep { $_ > $nowM1h } @{$hash->{XMIT_TIME}};

  if(@b > 163) {          # Maximum nr of transmissions per hour (unconfirmed).

    my $name = $hash->{NAME};
    Log3 $name, 2, "FHEMduino TRANSMIT LIMIT EXCEEDED";
    DoTrigger($name, "TRANSMIT LIMIT EXCEEDED");

  } else {

    push(@b, $now);

  }
  $hash->{XMIT_TIME} = \@b;
  $hash->{NR_CMD_LAST_H} = int(@b);
}


#####################################
sub
FHEMduino_Write($$$)
{
  my ($hash,$fn,$msg) = @_;

  my $name = $hash->{NAME};

  Log3 $name, 5, "$hash->{NAME} sending $fn$msg";
  my $bstring = "$fn$msg";

  FHEMduino_SimpleWrite($hash, $bstring);

}

sub
FHEMduino_SendFromQueue($$)
{
  my ($hash, $bstring) = @_;
  my $name = $hash->{NAME};

  if($bstring ne "") {
	FHEMduino_XmitLimitCheck($hash,$bstring);
    FHEMduino_SimpleWrite($hash, $bstring);
  }

  ##############
  # Write the next buffer not earlier than 0.23 seconds
  # = 3* (12*0.8+1.2+1.0*5*9+0.8+10) = 226.8ms
  # else it will be sent too early by the FHEMduino, resulting in a collision
  InternalTimer(gettimeofday()+0.3, "FHEMduino_HandleWriteQueue", $hash, 1);
}

#####################################
sub
FHEMduino_HandleWriteQueue($)
{
  my $hash = shift;
  my $arr = $hash->{QUEUE};
  if(defined($arr) && @{$arr} > 0) {
    shift(@{$arr});
    if(@{$arr} == 0) {
      delete($hash->{QUEUE});
      return;
    }
    my $bstring = $arr->[0];
    if($bstring eq "") {
      FHEMduino_HandleWriteQueue($hash);
    } else {
      FHEMduino_SendFromQueue($hash, $bstring);
    }
  }
}

#####################################
# called from the global loop, when the select for hash->{FD} reports data
sub
FHEMduino_Read($)
{
  my ($hash) = @_;

  my $buf = DevIo_SimpleRead($hash);
  return "" if(!defined($buf));
  my $name = $hash->{NAME};

  my $FHEMduinodata = $hash->{PARTIAL};
  Log3 $name, 5, "FHEMduino/RAW: $FHEMduinodata/$buf"; 
  $FHEMduinodata .= $buf;

  while($FHEMduinodata =~ m/\n/) {
    my $rmsg;
    ($rmsg,$FHEMduinodata) = split("\n", $FHEMduinodata, 2);
    $rmsg =~ s/\r//;
    FHEMduino_Parse($hash, $hash, $name, $rmsg) if($rmsg);
  }
  $hash->{PARTIAL} = $FHEMduinodata;
}

sub
FHEMduino_Parse($$$$)
{
  my ($hash, $iohash, $name, $rmsg) = @_;

  my $rssi;

  my $dmsg = $rmsg;
  if($dmsg =~ m/^[AFTKEHRStZri]([A-F0-9][A-F0-9])+$/) { # RSSI
    my $l = length($dmsg);
    $rssi = hex(substr($dmsg, $l-2, 2));
    $dmsg = substr($dmsg, 0, $l-2);
    $rssi = ($rssi>=128 ? (($rssi-256)/2-74) : ($rssi/2-74));
    Log3 $name, 5, "$name: $dmsg $rssi";
  } else {
    Log3 $name, 5, "$name: $dmsg";
  }

  ###########################################
  #Translate Message from FHEMduino to FHZ
  next if(!$dmsg || length($dmsg) < 1);            # Bogus messages

  if($dmsg =~ m/^[0-9A-F]{4}U./) {                 # RF_ROUTER
    Dispatch($hash, $dmsg, undef);
    return;
  }

  my $fn = substr($dmsg,0,1);
  my $len = length($dmsg);

  if($fn eq "i" && $len >= 7) {              # IT
    $dmsg = lc($dmsg);
  } elsif($fn eq "E" && $len >= 2) {
	### implement error checking here!
	;
  }

  elsif($fn eq "K" && $len >= 2) {
  ### implement error checking here!
  ;
  }

  else {
    DoTrigger($name, "UNKNOWNCODE $dmsg");
    Log3 $name, 2, "$name: unknown message $dmsg";
    return;
  }

  $hash->{"${name}_MSGCNT"}++;
  $hash->{"${name}_TIME"} = TimeNow();
  $hash->{RAWMSG} = $rmsg;
  my %addvals = (RAWMSG => $rmsg);
  if(defined($rssi)) {
    $hash->{RSSI} = $rssi;
    $addvals{RSSI} = $rssi;
  }
  Dispatch($hash, $dmsg, \%addvals);
}


#####################################
sub
FHEMduino_Ready($)
{
  my ($hash) = @_;

  return DevIo_OpenDev($hash, 1, "FHEMduino_DoInit")
                if($hash->{STATE} eq "disconnected");

  # This is relevant for windows/USB only
  my $po = $hash->{USBDev};
  my ($BlockingFlags, $InBytes, $OutBytes, $ErrorFlags);
  if($po) {
    ($BlockingFlags, $InBytes, $OutBytes, $ErrorFlags) = $po->status;
  }
  return ($InBytes && $InBytes>0);
}

########################
sub
FHEMduino_SimpleWrite(@)
{
  my ($hash, $msg, $nonl) = @_;
  return if(!$hash);
  if($hash->{TYPE} eq "FHEMduino_RFR") {
    # Prefix $msg with RRBBU and return the corresponding FHEMduino hash.
    ($hash, $msg) = FHEMduino_RFR_AddPrefix($hash, $msg); 
  }

  my $name = $hash->{NAME};
  Log3 $name, 5, "SW: $msg";

  $msg .= "\n" unless($nonl);

  $hash->{USBDev}->write($msg)    if($hash->{USBDev});
  syswrite($hash->{TCPDev}, $msg) if($hash->{TCPDev});
  syswrite($hash->{DIODev}, $msg) if($hash->{DIODev});

  # Some linux installations are broken with 0.001, T01 returns no answer
  select(undef, undef, undef, 0.01);
}

sub
FHEMduino_Attr(@)
{
  my @a = @_;

  return undef;
}

1;

=pod
=begin html

<a name="FHEMduino"></a>
<h3>FHEMduino</h3>
<ul>

  <table>
  <tr><td>
  The FHEMduino/CUR/CUN is a family of RF devices sold by <a
  href="http://www.busware.de">busware.de</a>.

  With the opensource firmware (see this <a
  href="http://FHEMduinofw.de/FHEMduinofw.html">link</a>) they are capable
  to receive and send different 868MHz protocols (FS20/FHT/S300/EM/HMS).
  It is even possible to use these devices as range extenders/routers, see the
  <a href="#FHEMduino_RFR">FHEMduino_RFR</a> module for details.
  <br> <br>

  Some protocols (FS20, FHT and KS300) are converted by this module so that
  the same logical device can be used, irrespective if the radio telegram is
  received by a FHEMduino or an FHZ device.<br> Other protocols (S300/EM) need their
  own modules. E.g. S300 devices are processed by the FHEMduino_WS module if the
  signals are received by the FHEMduino, similarly EMWZ/EMGZ/EMEM is handled by the
  FHEMduino_EM module.<br><br>

  It is possible to attach more than one device in order to get better
  reception, fhem will filter out duplicate messages.<br><br>

  Note: this module may require the Device::SerialPort or Win32::SerialPort
  module if you attach the device via USB and the OS sets strange default
  parameters for serial devices.


  </td><td>
  <img src="ccc.jpg"/>
  </td></tr>
  </table>

  <a name="FHEMduinodefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; FHEMduino &lt;device&gt; &lt;FHTID&gt;</code> <br>
    <br>
    USB-connected devices (FHEMduino/CUR/CUN):<br><ul>
      &lt;device&gt; specifies the serial port to communicate with the FHEMduino or
      CUR.  The name of the serial-device depends on your distribution, under
      linux the cdc_acm kernel module is responsible, and usually a
      /dev/ttyACM0 device will be created. If your distribution does not have a
      cdc_acm module, you can force usbserial to handle the FHEMduino by the
      following command:<ul>modprobe usbserial vendor=0x03eb
      product=0x204b</ul>In this case the device is most probably
      /dev/ttyUSB0.<br><br>

      You can also specify a baudrate if the device name contains the @
      character, e.g.: /dev/ttyACM0@38400<br><br>

      If the baudrate is "directio" (e.g.: /dev/ttyACM0@directio), then the
      perl module Device::SerialPort is not needed, and fhem opens the device
      with simple file io. This might work if the operating system uses sane
      defaults for the serial parameters, e.g. some Linux distributions and
      OSX.  <br><br>

    </ul>
    Network-connected devices (CUN):<br><ul>
    &lt;device&gt; specifies the host:port of the device. E.g.
    192.168.0.244:2323
    </ul>
    <br>
    If the device is called none, then no device will be opened, so you
    can experiment without hardware attached.<br>

    The FHTID is a 4 digit hex number, and it is used when the FHEMduino/CUR talks to
    FHT devices or when CUR requests data. Set it to 0000 to avoid answering
    any FHT80b request by the FHEMduino.
  </ul>
  <br>

  <a name="FHEMduinoset"></a>
  <b>Set </b>
  <ul>
    <li>raw<br>
        Issue a FHEMduino firmware command.  See the <a
        href="http://FHEMduinofw.de/commandref.html">this</a> document
        for details on FHEMduino commands.
        </li><br>

    <li>freq / bWidth / rAmpl / sens<br>
        <a href="#rfmode">SlowRF</a> mode only.<br>
        Set the FHEMduino frequency / bandwidth / receiver-amplitude / sensitivity<br>

        Use it with care, it may destroy your hardware and it even may be
        illegal to do so. Note: the parameters used for RFR transmission are
        not affected.<br>
        <ul>
        <li>freq sets both the reception and transmission frequency. Note:
            although the CC1101 can be set to frequencies between 315 and 915
            MHz, the antenna interface and the antenna of the FHEMduino is tuned for
            exactly one frequency. Default is 868.3MHz (or 433MHz)</li>
        <li>bWidth can be set to values between 58kHz and 812kHz. Large values
            are susceptible to interference, but make possible to receive
            inaccurate or multiple transmitters. It affects tranmission too.
            Default is 325kHz.</li>
        <li>rAmpl is receiver amplification, with values between 24 and 42 dB.
            Bigger values allow reception of weak signals. Default is 42.
            </li>
        <li>sens is the decision boundery between the on and off values, and it
            is 4, 8, 12 or 16 dB.  Smaller values allow reception of less clear
            signals. Default is 4dB.</li>
        </ul>
        </li><br>
    <li>led<br>
        Set the FHEMduino led off (00), on (01) or blinking (02).
        </li><br>
  </ul>

  <a name="FHEMduinoget"></a>
  <b>Get</b>
  <ul>
    <li>version<br>
        return the FHEMduino firmware version
        </li><br>
    <li>uptime<br>
        return the FHEMduino uptime (time since FHEMduino reset).
        </li><br>
    <li>raw<br>
        Issue a FHEMduino firmware command, and wait for one line of data returned by
        the FHEMduino. See the FHEMduino firmware README document for details on FHEMduino
        commands.
        </li><br>
    <li>fhtbuf<br>
        FHEMduino has a message buffer for the FHT. If the buffer is full, then newly
        issued commands will be dropped, and an "EOB" message is issued to the
        fhem log.
        <code>fhtbuf</code> returns the free memory in this buffer (in hex),
        an empty buffer in the FHEMduino-V2 is 74 bytes, in FHEMduino-V3/CUN 200 Bytes.
        A message occupies 3 + 2x(number of FHT commands) bytes,
        this is the second reason why sending multiple FHT commands with one
        <a href="#set">set</a> is a good idea. The first reason is, that
        these FHT commands are sent at once to the FHT.
        </li> <br>

    <li>ccconf<br>
        Read some FHEMduino radio-chip (cc1101) registers (frequency, bandwidth, etc),
        and display them in human readable form.
        </li><br>

    <li>cmds<br>
        Depending on the firmware installed, FHEMduinos have a different set of
        possible commands. Please refer to the README of the firmware of your
        FHEMduino to interpret the response of this command. See also the raw-
        command.
        </li><br>
    <li>credit10ms<br>
        One may send for a duration of credit10ms*10 ms before the send limit is reached and a LOVF is
        generated.
        </li><br>
  </ul>

  <a name="FHEMduinoattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#do_not_notify">do_not_notify</a></li>
    <li><a href="#attrdummy">dummy</a></li>
    <li><a href="#showtime">showtime</a></li>
    <li><a href="#model">model</a> (FHEMduino,CUN,CUR)</li>
    <li><a name="sendpool">sendpool</a><br>
        If using more than one FHEMduino/CUN for covering a large area, sending
        different events by the different FHEMduino's might disturb each other. This
        phenomenon is also known as the Palm-Beach-Resort effect.
        Putting them in a common sendpool will serialize sending the events.
        E.g. if you have three CUN's, you have to specify following
        attributes:<br>
        attr CUN1 sendpool CUN1,CUN2,CUN3<br>
        attr CUN2 sendpool CUN1,CUN2,CUN3<br>
        attr CUN3 sendpool CUN1,CUN2,CUN3<br>
        </li><br>
    <li><a name="addvaltrigger">addvaltrigger</a><br>
        Create triggers for additional device values. Right now these are RSSI
        and RAWMSG for the FHEMduino family and RAWMSG for the FHZ.
        </li><br>
    <li><a name="rfmode">rfmode</a><br>
        Configure the RF Transceiver of the FHEMduino (the CC1101). Available
        arguments are:
        <ul>
        <li>SlowRF<br>
            To communicate with FS20/FHT/HMS/EM1010/S300/Hoermann devices @1kHz
            datarate. This is the default.</li>

        <li>HomeMatic<br>
            To communicate with HomeMatic type of devices @20kHz datarate</li>

        <li>MAX<br>
            To communicate with MAX! type of devices @20kHz datarate</li>

        </ul>
        </li><br>
  
  </ul>
  <br>
</ul>

=end html
=cut

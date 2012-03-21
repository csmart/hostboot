#!/usr/bin/perl
#  IBM_PROLOG_BEGIN_TAG
#  This is an automatically generated prolog.
#
#  $Source: src/usr/targeting/xmltohb/genTuletaMrwXml.pl $
#
#  IBM CONFIDENTIAL
#
#  COPYRIGHT International Business Machines Corp. 2012
#
#  p1
#
#  Object Code Only (OCO) source materials
#  Licensed Internal Code Source Materials
#  IBM HostBoot Licensed Internal Code
#
#  The source code for this program is not published or other-
#  wise divested of its trade secrets, irrespective of what has
#  been deposited with the U.S. Copyright Office.
#
#  Origin: 30
#
#  IBM_PROLOG_END

#
# Author:   Van Lee    vanlee@us.ibm.com
#
# Usage:
#
#    genTuletaMrwXml.pl --mrwdir=pathname [--outfile=XmlFilename]
#        --mrwdir=pathname
#              Specify the complete dir pathname of the MRW.
#        --outfile=XmlFilename
#              Specify the filename for the output XML. If omitted, the output
#              is written to STDOUT which can be saved by redirection.
#
# Purpose:
#
#   This perl script processes the various xml files of the Tuleta MRW to
#   extract the needed information for generating the final xml file.
#

use constant SYSTEM => "TULETA";
use strict;
use XML::Simple;
use Data::Dumper;

my $mrwdir = "";
my $usage = 0;
my $outFile = "";
use Getopt::Long;
GetOptions( "mrwdir:s"  => \$mrwdir,
            "outfile:s" => \$outFile,
            "help"      => \$usage, );

if ($usage || ($mrwdir eq ""))
{
    display_help();
    exit 0;
}

if ($outFile ne "")
{
    open OUTFILE, '+>', $outFile ||
                die "ERROR: unable to create $outFile\n";
    select OUTFILE;
}

open (FH, "<$mrwdir/" . lc(SYSTEM) . "-system-policy.xml") ||
    die "ERROR: unable to open $mrwdir/" . lc(SYSTEM) . "-system-policy.xml\n";
close (FH);

my $policy = XMLin("$mrwdir/" . lc(SYSTEM) . "-system-policy.xml");

open (FH, "<$mrwdir/" . lc(SYSTEM) . "-targets.xml") ||
    die "ERROR: unable to open $mrwdir/" . lc(SYSTEM) . "-targets.xml\n";
close (FH);

my $eTargets = XMLin("$mrwdir/" . lc(SYSTEM) . "-targets.xml");
 
# Capture all targets into the @Targets array
use constant NAME_FIELD => 0;
use constant NODE_FIELD => 1;
use constant POS_FIELD  => 2;
use constant UNIT_FIELD => 3;
use constant LOC_FIELD  => 4;
my @Targets;
foreach my $i (@{$eTargets->{target}}) 
{
    push @Targets, [ $i->{'ecmd-common-name'}, $i->{node}, $i->{position},
                     $i->{'chip-unit'}, $i->{location} ];
}

open (FH, "<$mrwdir/" . lc(SYSTEM) . "-fsi-busses.xml") ||
    die "ERROR: unable to open $mrwdir/" . lc(SYSTEM) . "-fsi-busses.xml\n";
close (FH);

my $fsiBus = XMLin("$mrwdir/" . lc(SYSTEM) . "-fsi-busses.xml");

# Capture all FSI connections into the @Fsis array
use constant FSI_TYPE_FIELD   => 0;
use constant FSI_LINK_FIELD   => 1;
use constant FSI_TARGET_FIELD => 2;
my @Fsis;
foreach my $i (@{$fsiBus->{'fsi-bus'}}) 
{
    push @Fsis, [ $i->{master}->{type}, $i->{master}->{link},
        "n$i->{slave}->{target}->{node}:p$i->{slave}->{target}->{position}" ];
}

open (FH, "<$mrwdir/" . lc(SYSTEM) . "-memory-busses.xml") ||
    die "ERROR: unable to open $mrwdir/" . lc(SYSTEM) . "-memory-busses.xml\n";
close (FH);

my $memBus = XMLin("$mrwdir/" . lc(SYSTEM) . "-memory-busses.xml");

# Capture all memory buses info into the @Membuses array
use constant MCS_TARGET_FIELD     => 0;
use constant CENTAUR_TARGET_FIELD => 1;
use constant DIMM_TARGET_FIELD    => 2;
use constant DIMM_PATH_FIELD      => 3;
use constant CFSI_LINK_FIELD      => 4;
my @Membuses;
foreach my $i (@{$memBus->{'memory-bus'}}) 
{
    push @Membuses, [
         "n$i->{mcs}->{target}->{node}:p$i->{mcs}->{target}->{position}:mcs" .
         $i->{mcs}->{target}->{chipUnit},
         "n$i->{mba}->{target}->{node}:p$i->{mba}->{target}->{position}:mba" .
         $i->{mba}->{target}->{chipUnit},
         "n$i->{dimm}->{target}->{node}:p$i->{dimm}->{target}->{position}",
         $i->{dimm}->{'instance-path'}, $i->{'fsi-link'} ];
}

# Sort physical DIMM order
my @Memfields;
my @SMembuses;
for my $i ( 0 .. $#Membuses )
{
    for (my $j = 0; $j <= $#Membuses; $j++ )
    {
        my $k = $Membuses[$j][DIMM_PATH_FIELD];
        $k =~ s/.*dimm-(.*).*$/$1/;
        if ($k == $i)
        {
            for my $l ( 0 .. CFSI_LINK_FIELD )
            {
                $Memfields[$l] = $Membuses[$j][$l];
            }
            push @SMembuses, [ @Memfields ];
            $j = $#Membuses;
        }
    }
}

# Find master processor's node and proc. The FSP master is always connected to
# the msater processor. The master processor's node is used as the system node

my $node = 0;
my $Mproc = 0;
for my $i ( 0 .. $#Fsis )
{
    if ((lc($Fsis[$i][FSI_TYPE_FIELD]) eq "fsp master") &&
        (lc($Fsis[$i][FSI_TARGET_FIELD]) eq "n[0-9]+:p[0-9]+"))
    {
        $node = $Fsis[$i][FSI_TARGET_FIELD];
        $Mproc = $node;
        $node =~ s/n(.*):p.*/$1/;
        $Mproc =~ s/.*p(.*)/$1/;
    }
}

# Generate @STargets array from the @Targets array to have the order as shown
# belows. The rest of the codes assume that this order is in place
#
#   pu
#   ex  (one or more EX of pu before it)
#   mcs (one or more MCS of pu before it)
#   (Repeat for remaining pu)
#   memb
#   mba (to for membuf before it)
#   (Repeat for remaining membuf)
#

my @fields;
my @STargets;
for my $i ( 0 .. $#Targets )
{
    if ($Targets[$i][NAME_FIELD] eq "pu")
    {
        for my $k ( 0 .. LOC_FIELD )
        {
            $fields[$k] = $Targets[$i][$k];
        }
        push @STargets, [ @fields ];

        my $position = $Targets[$i][POS_FIELD];

        for my $j ( 0 .. $#Targets )
        {
            if (($Targets[$j][NAME_FIELD] eq "ex") &&
                ($Targets[$j][POS_FIELD] eq $position))
            {
                for my $k ( 0 .. LOC_FIELD )
                {
                    $fields[$k] = $Targets[$j][$k];
                }
                push @STargets, [ @fields ];
            }
        }

        for my $j ( 0 .. $#Targets )
        {
            if (($Targets[$j][NAME_FIELD] eq "mcs") &&
                ($Targets[$j][POS_FIELD] eq $position))
            {
                for my $k ( 0 .. LOC_FIELD )
                {
                    $fields[$k] = $Targets[$j][$k];
                }
                push @STargets, [ @fields ];
            }
        }
    }
}

for my $i ( 0 .. $#Targets )
{
    if ($Targets[$i][NAME_FIELD] eq "memb")
    {
        for my $k ( 0 .. LOC_FIELD )
        {
            $fields[$k] = $Targets[$i][$k];
        }
        push @STargets, [ @fields ];

        my $position = $Targets[$i][POS_FIELD];

        for my $j ( 0 .. $#Targets )
        {
            if (($Targets[$j][NAME_FIELD] eq "mba") &&
                ($Targets[$j][POS_FIELD] eq $position))
            {
                for my $k ( 0 .. LOC_FIELD )
                {
                    $fields[$k] = $Targets[$j][$k];
                }
                push @STargets, [ @fields ];
            }
        }
    }
}

# Finally, generate the xml file.

print "<attributes>\n";

# First, generate system target (always sys0)
my $sys = 0;
generate_sys();

# Second, generate system node using the master processor's node
generate_system_node();

# Third, generate the proc, ex-chiplet, mcs-chiplet, pervasive-bus, powerbus,
# pcie bus and A/X-bus.
my $ex_count = 0;
my $mcs_count = 0;
for (my $do_core = 0, my $i = 0; $i <= $#STargets; $i++)
{
    if ($STargets[$i][NAME_FIELD] eq "pu")
    {
        my $proc = $STargets[$i][POS_FIELD];
        if ($proc eq $Mproc)
        {
            generate_master_proc($Mproc);
        }
        else
        {
            my $fsi;
            for (my $j = 0; $j <= $#Fsis; $j++)
            {
                if ($Fsis[$j][FSI_TARGET_FIELD] eq "n${node}:p$proc")
                {
                    $fsi = $Fsis[$j][FSI_LINK_FIELD];
                    $j = $#Fsis;
                }
            }
            generate_slave_proc($proc, $fsi);
        }
    }
    elsif ($STargets[$i][NAME_FIELD] eq "ex")
    {
        my $proc = $STargets[$i][POS_FIELD];
        my $ex = $STargets[$i][UNIT_FIELD];
        if ($do_core == 0)
        {
            if ($ex_count == 0)
            {
                print "\n<!-- " . SYSTEM .  " n${node}p$proc EX units -->\n";
            }
            generate_ex($proc, $ex);
            $ex_count++;
            if ($STargets[$i+1][NAME_FIELD] eq "mcs")
            {
                $do_core = 1;
                $i -= $ex_count;
                $ex_count = 0;
            }
        }
        else
        {
            if ($ex_count == 0)
            {
                print "\n<!-- " . SYSTEM .  " n${node}p$proc core units -->\n";
            }
            generate_ex_core($proc,$ex);
            $ex_count++;
            if ($STargets[$i+1][NAME_FIELD] eq "mcs")
            {
                $do_core = 0;
                $ex_count = 0;
            }
        }
    }
    elsif ($STargets[$i][NAME_FIELD] eq "mcs")
    {
        my $proc = $STargets[$i][POS_FIELD];
        my $mcs = $STargets[$i][UNIT_FIELD];
        if ($mcs_count == 0)
        {
            print "\n<!-- " . SYSTEM .  " n${node}p$proc MCS units -->\n";
        }
        generate_mcs($proc,$mcs);
        $mcs_count++;
        if (($STargets[$i+1][NAME_FIELD] eq "pu") ||
            ($STargets[$i+1][NAME_FIELD] eq "memb"))
        {
            $mcs_count = 0;
            generate_pervasive_bus($proc);
            generate_powerbus($proc);
            generate_pcies($proc);
            generate_ax_buses($proc, "A");
            generate_ax_buses($proc, "X");
        }
    }
}

# Fourth, generate the Centaur, MBS, and MBA

my $memb;
my $membMcs;

for my $i ( 0 .. $#STargets )
{
    if ($STargets[$i][NAME_FIELD] eq "memb")
    {
        $memb = $STargets[$i][POS_FIELD];
        my $centaur = "n${node}:p${memb}";
        my $found = 0;
        my $cfsi;
        for my $j ( 0 .. $#Membuses )
        {
            my $mba = $Membuses[$j][CENTAUR_TARGET_FIELD];
            $mba =~ s/(.*):mba.*$/$1/;
            if ($mba eq $centaur)
            {
                $membMcs = $Membuses[$j][MCS_TARGET_FIELD];
                $cfsi = $Membuses[$j][CFSI_LINK_FIELD];
                $found = 1;
            }
        }
        if ($found == 0)
        {
            die "ERROR. Can't locate Centaur from memory bus table\n";
        }
        generate_centaur( $memb, $membMcs, $cfsi );
    }
    elsif ($STargets[$i][NAME_FIELD] eq "mba")
    {
        my $mba = $STargets[$i][UNIT_FIELD];
        generate_mba( $memb, $membMcs, $mba );
        if ($mba == 1)
        {
            print "\n<!-- " . SYSTEM .  " Centaur n${node}p${memb} : end -->\n"
        }
    }
}

# Fifth, generate DIMM targets

print "\n<!-- " . SYSTEM . " Centaur DIMMs -->\n";

for my $i ( 0 .. $#SMembuses )
{
    my $proc = $SMembuses[$i][MCS_TARGET_FIELD];
    my $mcs = $proc;
    $proc =~ s/.*:p(.*):.*/$1/;
    $mcs =~ s/.*mcs(.*)/$1/;
    my $ctaur = $SMembuses[$i][CENTAUR_TARGET_FIELD];
    my $mba = $ctaur;
    $ctaur =~ s/.*:p(.*):mba.*$/$1/;
    $mba =~ s/.*:mba(.*)$/$1/;
    my $pos = $SMembuses[$i][DIMM_TARGET_FIELD];
    $pos =~ s/.*:p(.*)/$1/;
    my $dimm = $SMembuses[$i][DIMM_PATH_FIELD];
    $dimm =~ s/.*dimm-(.*)/$1/;
    print "\n<!-- C-DIMM n${node}:p${pos} -->\n";
    for my $id ( 0 .. 7 )
    {
        my $dimmid = $dimm;
        $dimmid <<= 3;
        $dimmid |= $id;
        $dimmid = sprintf ("%d", $dimmid);
        generate_dimm( $proc, $mcs, $ctaur, $pos, $dimmid, $id );
    }
}

print "\n</attributes>";

# All done!
#close ($outFH);
exit 0;

##########   Subroutines    ##############

sub generate_sys
{
    my $proc_refclk = $policy->{'required-policy-settings'}->{'processor-refclock-frequency'}->{content};
    my $mem_refclk = $policy->{'required-policy-settings'}->{'memory-refclock-frequency'}->{content};

    print "
<!-- " . SYSTEM . " System -->

<targetInstance>
    <id>sys$sys</id>
    <type>sys-sys-power8</type>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys</default>
    </attribute>
    <attribute>
        <id>PROC_EPS_TABLE_TYPE</id>
        <default>EPS_TYPE_LE</default>
    </attribute>
    <attribute>
        <id>PROC_FABRIC_PUMP_MODE</id>
        <default>MODE1</default>
    </attribute>
    <attribute>
        <id>PROC_X_BUS_WIDTH</id>
        <default>W8BYTE</default>
    </attribute>
    <attribute>
        <id>ALL_MCS_IN_INTERLEAVING_GROUP</id>
        <default>1</default>
    </attribute>
    <attribute>
        <id>FREQ_PROC_REFCLOCK</id>
        <default>$proc_refclk</default>
    </attribute>
    <attribute>
        <id>FREQ_MEM_REFCLOCK</id>
        <default>$mem_refclk</default>
    </attribute>
    <attribute>
        <id>FREQ_CORE_FLOOR</id>
        <default>2500</default>
    </attribute>
</targetInstance>
";
}

sub generate_system_node
{
    print "
<!-- " . SYSTEM . " System node $node -->

<targetInstance>
    <id>sys${sys}node${node}</id>
    <type>enc-node-power8</type>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node</default>
    </attribute>
</targetInstance>
";
}

sub generate_master_proc
{
    print "
<!-- " . SYSTEM . " n${node}p${Mproc} processor chip -->

<targetInstance>
    <id>sys${sys}node${node}proc${Mproc}</id>
    <type>chip-processor-murano</type>
    <attribute><id>POSITION</id><default>${Mproc}</default></attribute>
    <attribute><id>SCOM_SWITCHES</id>
        <default>
            <field><id>useFsiScom</id><value>0</value></field>
            <field><id>useXscom</id><value>1</value></field>
            <field><id>useInbandScom</id><value>0</value></field>
            <field><id>reserved</id><value>0</value></field>
        </default>
    </attribute>
    <attribute>
        <id>XSCOM_CHIP_INFO</id>
        <default>
            <field><id>nodeId</id><value>$node</value></field>
            <field><id>chipId</id><value>$Mproc</value></field>
        </default>
    </attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$Mproc</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node/proc-$Mproc</default>
    </attribute>
    <attribute>
        <id>FABRIC_NODE_ID</id>
        <default>$node</default>
    </attribute>
    <attribute>
        <id>FABRIC_CHIP_ID</id>
        <default>$Mproc</default>
    </attribute>
</targetInstance>
";
}

sub generate_slave_proc
{
    my ($proc, $fsi) = @_;
    print "
<!-- " . SYSTEM . " n${node}p$proc processor chip -->

<targetInstance>
    <id>sys${sys}node${node}proc$proc</id>
    <type>chip-processor-murano</type>
    <attribute><id>POSITION</id><default>$proc</default></attribute>
    <attribute><id>SCOM_SWITCHES</id>
        <default>
            <field><id>useFsiScom</id><value>1</value></field>
            <field><id>useXscom</id><value>0</value></field>
            <field><id>useInbandScom</id><value>0</value></field>
            <field><id>reserved</id><value>0</value></field>
        </default>
    </attribute>
    <attribute>
        <id>XSCOM_CHIP_INFO</id>
        <default>
            <field><id>nodeId</id><value>$node</value></field>
            <field><id>chipId</id><value>$Mproc</value></field>
        </default>
    </attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node/proc-$proc</default>
    </attribute>
    <attribute>
        <id>FABRIC_NODE_ID</id>
        <default>$node</default>
    </attribute>
    <attribute>
        <id>FABRIC_CHIP_ID</id>
        <default>$proc</default>
    </attribute>
    <!-- FSI is connected via proc${Mproc}:MFSI-$fsi -->
    <attribute>
        <id>FSI_MASTER_CHIP</id>
        <default>physical:sys-$sys/node-$node/proc-$Mproc</default>
    </attribute>
    <attribute>
        <id>FSI_MASTER_TYPE</id>
        <default>MFSI</default>
    </attribute>
    <attribute>
        <id>FSI_MASTER_PORT</id>
        <default>$fsi</default>
    </attribute>
    <attribute>
        <id>FSI_SLAVE_CASCADE</id>
        <default>0</default>
    </attribute>
    <attribute>
        <id>FSI_OPTION_FLAGS</id>
        <default>0</default>
    </attribute>
</targetInstance>
";
}

sub generate_ex
{
    my ($proc, $ex) = @_;
    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}ex$ex</id>
    <type>unit-ex-murano</type>
        <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/ex-$ex</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node/proc-$proc/ex-$ex</default>
    </attribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$ex</default>
    </attribute>
</targetInstance>
";
}

sub generate_ex_core
{
    my ($proc, $ex) = @_;
    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}ex${ex}core0</id>
    <type>unit-core-murano</type>
        <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/ex-$ex/core-0</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node/proc-$proc/ex-$ex/core-0</default>
    </attribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$ex</default>
    </attribute>
</targetInstance>
";
}

sub generate_mcs
{
    my ($proc, $mcs) = @_;
    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}mcs$mcs</id>
    <type>unit-mcs-murano</type>
        <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/mcs-$mcs</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node/proc-$proc/mcs-$mcs</default>
    </attribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$mcs</default>
    </attribute>
</targetInstance>
";
}

sub generate_pervasive_bus
{
    my $proc = shift;
    print "
<!-- " . SYSTEM . " n${node}p$proc pervasive unit -->

<targetInstance>
    <id>sys${sys}node${node}proc${proc}pervasive0</id>
    <type>unit-pervasive-murano</type>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/pervasive-0</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node/proc-$proc/pervasive-0</default>
    </attribute>
</targetInstance>
";
}

sub generate_powerbus
{
    my $proc = shift;
    print "
<!-- " . SYSTEM . " n${node}p$proc powerbus unit -->

<targetInstance>
    <id>sys${sys}node${node}proc${proc}powerbus0</id>
    <type>unit-powerbus-murano</type>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/powerbus-0</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node/proc-$proc/powerbus-0</default>
    </attribute>
</targetInstance>
";
}

sub generate_pcies
{
    my $proc = shift;
    my $proc_name = "n${node}:p${proc}";
    print "\n<!-- " . SYSTEM . " n${node}p${proc} PCI units -->\n";
    for my $i ( 0 .. 2 )
    {
        generate_a_pcie( $proc, $i );
    }
}

sub generate_a_pcie
{
    my ($proc, $phb) = @_;
    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}pci${phb}</id>
    <type>unit-pci-murano</type>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/pci-$phb</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node/proc-$proc/pci-$phb</default>
    </attribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$phb</default>
    </attribute>
</targetInstance>
";
}

sub generate_ax_buses
{
    my ($proc, $type) = @_;

    my $proc_name = "n${node}p${proc}";
    print "\n<!-- " . SYSTEM . " $proc_name ${type}BUS units -->\n";
    my $maxbus = ($type eq "A") ? 2 : 3;
    $type = lc( $type );
    for my $i ( 0 .. $maxbus )
    {
        print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}${type}bus$i</id>
    <type>unit-${type}bus-murano</type>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/${type}bus-$i</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node/proc-$proc/${type}bus-$i</default>
    </attribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$i</default>
    </attribute>
</targetInstance>
";
    }
}

sub generate_centaur
{
    my ($ctaur, $mcs, $cfsi) = @_;
    my $proc = $mcs;
    $proc =~ s/.*:p(.*):.*/$1/g;
    $mcs =~ s/.*:.*:mcs(.*)/$1/g;

    print "
<!-- " . SYSTEM . " Centaur n${node}p${ctaur} : start -->

<targetInstance>
    <id>sys${sys}node${node}membuf${ctaur}</id>
    <type>chip-membuf-centaur</type>
    <attribute><id>POSITION</id><default>$ctaur</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/membuf-$ctaur</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node/proc-$proc/mcs-$mcs/membuf-$ctaur</default>
    </attribute>

    <!-- FSI is connected via proc$proc:cMFSI-$cfsi -->
    <attribute>
        <id>FSI_MASTER_CHIP</id>
        <default>physical:sys-$sys/node-$node/proc-$proc</default>
    </attribute>
    <attribute>
        <id>FSI_MASTER_TYPE</id>
        <default>CMFSI</default>
    </attribute>
    <attribute>
        <id>FSI_MASTER_PORT</id>
        <default>$cfsi</default>
    </attribute>
    <attribute>
        <id>FSI_SLAVE_CASCADE</id>
        <default>0</default>
    </attribute>
    <attribute>
        <id>FSI_OPTION_FLAGS</id>
        <default>0</default>
    </attribute>
</targetInstance>
";

    print "
<!-- " . SYSTEM . " Centaur MBS affiliated with membuf$ctaur -->

<targetInstance>
    <id>sys${sys}node${node}membuf${ctaur}mbs0</id>
    <type>unit-mbs-centaur</type>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/membuf-$ctaur/mbs-0</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node/proc-$proc/mcs-$mcs/membuf-$ctaur/mbs-0</default>
    </attribute>
</targetInstance>
";
}

sub generate_mba
{
    my ($ctaur, $mcs, $mba) = @_;
    my $proc = $mcs;
    $proc =~ s/.*:p(.*):.*/$1/g;
    $mcs =~ s/.*:.*:mcs(.*)/$1/g;

    if ($mba == 0)
    {
        print "\n<!-- " . SYSTEM .
                     " Centaur MBAs affiliated with membuf$ctaur -->\n";
    }

    print "
<targetInstance>
    <id>sys${sys}node${node}membuf${ctaur}mbs0mba$mba</id>
    <type>unit-mba-centaur</type>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/membuf-$ctaur/mbs-0/mba-$mba</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node/proc-$proc/mcs-$mcs/membuf-$ctaur/mbs-0/mba-$mba</default>
    </attribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$mba</default>
    </attribute>
</targetInstance>
";
}

# Since each Centaur has only one dimm, it is assumed to be attached to port 0
# of the MBA0 chiplet.
sub generate_dimm
{
    my ($proc, $mcs, $ctaur, $pos, $dimm, $id) = @_;

    my $x = $id;
    $x = int ($x / 4);
    my $y = $id;
    $y = int(($y - 4 * $x) / 2);
    my $z = $id;
    $z = $z % 2;
    #$x = sprintf ("%d", $x);
    #$y = sprintf ("%d", $y);
    #$z = sprintf ("%d", $z);

    print "
<targetInstance>
    <id>sys${sys}node${node}dimm$dimm</id>
    <type>lcard-dimm-cdimm</type>
    <attribute>
        <id>POSITION</id>
        <default>$dimm</default>
    </attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/dimm-$dimm</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node/proc-$proc/mcs-$mcs/membuf-$pos/mbs-0/mba-$x/mem_port-$y/dimm-$z</default>
    </attribute>
    <attribute>
        <id>MBA_PORT</id>
        <default>$y</default>
    </attribute>
    <attribute>
        <id>MBA_DIMM</id>
        <default>$z</default>
    </attribute>
</targetInstance>
";
}

sub display_help
{
    use File::Basename;
    my $scriptname = basename($0);
    print STDERR "
Usage:

    $scriptname --help
    $scriptname --mrwdir=pathname [--outfile=XmlFilename]
        --mrwdir=pathname
              Specify the complete dir pathname of the MRW.
        --outfile=XmlFilename
              Specify the filename for the output XML. If omitted, the output
              is written to STDOUT which can be saved by redirection.
\n";
}

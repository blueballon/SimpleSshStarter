#!/usr/bin/perl
# This program is licensed under GPL v2
# final program version 2017/01/03

use strict;
use warnings;
use Tk;
use XML::Simple;
#debug use Data::Dumper;

### Examine User
my $USER=examineUser();

### MAIN PROGRAM SETTINGS ###########################################################
### please edit the following lines to meet your own needs


#debug print ("user: <$USER>");
my $USERSETTING=".sss_user.xml";                             # user-specific settings
my $SYSSETTINGUNIX="/i/dont/know/where/sss_unix.xml";          # department-wide unix
my $SYSSETTINGWIN="I:/DONT/KNOW/WHERE/sss_win.xml";              #department-wide win
#my $MASTERSETTINGUNIX="/i/dont/know/where/sss_master.xml";   # master file, unix path
my $MASTERSETTINGUNIX="./sss.xml";
my $MASTERSETTINGWIN="I:/DONT/KNOW/WHERE/sss_master.xml";     # master file, win path
my $EXECLOCALUNIX=" ";             # local execution command for unix (usually empty)
my $EXECSSHUNIX="ssh -X ";                           # ssh execution command for unix 
my $EXECLOCALWIN="cmd ";             # local execution command for unix (usually cmd)
my $EXECSSHWIN="plink -X ";         # ssh execution command for win (eg PuTTYs plink)


my $WINLISTHEIGHT=31;
my $UNIXLISTHEIGHT=21;
my $TEXTHEIGHT=31;
my $TEXTWIDTH=80;

### END MAIN PROGRAM SETTINGS #######################################################

# configfile settings
my $XMLfile="NO_HOME_DEFINED/".$USERSETTING;
if ($ENV{'HOME'})
{
   #debug print("es gibt home: $ENV{'HOME'}\n");
   $XMLfile=$ENV{'HOME'}."/".$USERSETTING;                      
}
my $XMLmasterfile=$MASTERSETTINGUNIX;  
my $XMLmastersys=$SYSSETTINGUNIX; 

# execution settings
my $remoteExec=$EXECSSHUNIX;
my $localExec=$EXECLOCALUNIX;

# gui settings
my $listheight=$UNIXLISTHEIGHT;

# windows-specific settings
if ($^O=~/MSWin32/)
{
    $remoteExec=$EXECSSHWIN;
    $localExec=$EXECLOCALWIN;
    $XMLmastersys=$SYSSETTINGWIN; 
    $XMLmasterfile=$MASTERSETTINGWIN;
    $listheight=$WINLISTHEIGHT;
}



#readXMLsettings

my @displayList;
my @commandList;
my @machineList;

# settings ar put to the lists, and the status is put to the strings (to be displayed later)
my $localXMLstatus=readXMLsettings($XMLfile,\@displayList,\@commandList,\@machineList);
my $masterXMLstatus=readXMLsettings($XMLmasterfile,\@displayList,\@commandList,\@machineList);
my $sysXMLstatus=readXMLsettings($XMLmastersys,\@displayList,\@commandList,\@machineList);

# set up window
my $mw = MainWindow->new;
$mw->title("SSS - Simple SSH Starter for User $USER");
my $outputfield;

# build and display the labels
$mw->Label(-text => "Choose command")->grid(-sticky => "n",-row=>0, -column=>0);
$mw->Label(-text => "Command output")->grid(-sticky => "nw", -row=>0, -column=>1);

# build and display the list contents (orig height 16, 24)
my $lb = $mw->Scrolled( "Listbox", 
                        -scrollbars => "e", 
                        -height => $listheight,  
                        -width => 0, 
                        -selectmode => "single" )->grid(-sticky => "n",
			                                -row=>1, 
                                                        -column=>0, 
                                                        -rowspan=>1);
#my @starterList=getStarterList(); 
my @starterList=@displayList;
$lb->insert('end', @starterList);

# build and display the output window (orig height 20)
# ->pack(-fill=>"both");
$outputfield = $mw->Scrolled( "Text", 
                              -scrollbars => "e",
                              -relief => "groove",
                              -width => $TEXTWIDTH, 
                              -height => $TEXTHEIGHT, 
                              -state => 'normal' )->grid(-row=>1, 
                                                         -column=>1, 
                                                         -columnspan=>2);
$outputfield->insert('end', "Simple SSH/Script Starter Version 0.2etf (2006/05/09)\n");
$outputfield->insert('end', "Report bugs, comments, etc to blue.balloon\@gmx.net\n");
$outputfield->insert('end', "-----------------------------------------------------\n");
$outputfield->insert('end', "Local settings: $localXMLstatus\n");
$outputfield->insert('end', "Master settings: $masterXMLstatus\n");
$outputfield->insert('end', "System settings: $sysXMLstatus\n");
$outputfield->insert('end', "-----------------------------------------------------\n");
$outputfield->configure(-state => 'disabled');

# build and display the buttones 
$mw->Button(-text => "Execute", 
            -command => sub { execSSH($lb,
	                                  $outputfield,
	                                  \@commandList,
	                                  \@machineList,
	                                  $remoteExec,
                                      $localExec),})->grid(-row=>2,
	                                                       -column => 0);
$mw->Button(-text => "Clear output", 
            -command => sub { clearOutput($outputfield) })-> grid(-sticky=>"e", 
                                                                 -row=>0, 
                                                                 -column => 2);
$mw->Button(-text => "Exit", 
            -command => sub { exit })->grid(-sticky=>"e", 
                                            -row=>2,
                                            -column => 2);

# scale behavoir (taken from Mastering Perl/Tk)
my $i;
my ($columns, $rows) = $mw->gridSize( );
for ($i = 0; $i < $columns; $i++) {
  $mw->gridColumnconfigure($i, -weight => 1);
}
for ($i = 0; $i < $rows; $i++) {
  $mw->gridRowconfigure($i, -weight => 1);
}

# the main program
MainLoop;

#####################################################################################

sub clearOutput
{
	my $outputfield=$_[0];
	$outputfield->configure(-state => 'normal');
	$outputfield->delete("1.0", 'end');
	$outputfield->configure(-state => 'disabled');
}

sub execSSH
{
    my $listbox=$_[0];
    my $outtext=$_[1];
    my $cmdListRef=$_[2];
    my $mchListRef=$_[3];
    my $remCmd=$_[4];
    my $locCmd=$_[5];
    my @cmdList = $lb->curselection();
    #cmdList should ony contain 1 item
    my $command=pop(@cmdList);
    my $aktCmd=$$cmdListRef[$command];
    my $aktMch=$$mchListRef[$command];
    if (!$aktCmd)
    {
    	   $aktMch="local";
    }

    #print("command was: <$aktCmd> on <$aktMch>\n");	
    $outtext->configure(-state => 'normal');
    $outtext->insert('end', "Running command  <$aktCmd> on <$aktMch>\n");
    $outtext->configure(-state => 'disabled');

    # build execution string
    my $execString;
    if ($aktMch eq "local")
    {
            $execString=$locCmd . " " . $aktCmd . " 2>&1 &";		
    }
    else
    {
            $execString=$remCmd . " " . $aktMch . " " . $aktCmd . " 2>&1 &";	
    }

    # ist blockierend, geht f. uns nicht
    #my @result=`$execString`;
    #printListToText($outtext,\@result);

    # asynchronous execution with system needs different handling on win32
    if ($^O=~/MSWin32/)
    {
       system(1,$execString);
    }
    else
    {
       system($execString);
    }
    

    $outtext->configure(-state => 'normal');
    $outtext->insert('end', "Command  <$aktCmd> on <$aktMch> was started\n");
    $outtext->configure(-state => 'disabled');
}

sub printListToText
{
    my $textfield=$_[0];
    my $textListRef=$_[1];
    
    my $aktLine;
    $textfield->configure(-state => 'normal');
    foreach $aktLine (@$textListRef)
    {		
    	chomp($aktLine);
        $textfield->insert('end', "$aktLine\n");	
    }
    $textfield->configure(-state => 'disabled');
}

sub readXMLsettings
{
    my $XMLfile=$_[0];
    my $dspListRef=$_[1];
    my $cmdListRef=$_[2];
    my $mchListRef=$_[3];
    
    # return value
    my $status;
    
    #check if XMLfile defined
    if (! $XMLfile)
    {
    	$status="no xml file given!";
    	return $status;
    }
    #check if XMLfile exists
    if (! -e $XMLfile)
    {
    	$status="configfile <$XMLfile> does not exist!";
    	return $status;
    }
    my $xmlSettings = XMLin($XMLfile, forcearray=>1);
    #print Dumper($xmlSettings);
    my $sssItemListRef=${$xmlSettings}{'sssitem'};
    my $aktItem;
    foreach $aktItem (@$sssItemListRef)
    {
    	push(@$dspListRef,${${$aktItem}{'display'}}[0]);
    	push(@$cmdListRef,${${$aktItem}{'command'}}[0]);
    	push(@$mchListRef,${${$aktItem}{'machine'}}[0]);
    	#print("${${$aktItem}{'display'}}[0]\n");	
    }
    
    #return value;
    $status="configfile <$XMLfile> read";
}

# works directly with ENV and ARGV
# usage: $USER=examineUser()
sub examineUser
{
   my $USER=undef; 
   # if arg is given, treat the arg as username
   if (@ARGV)
   {
      $USER=shift(@ARGV);
   }
   else
   {
      # if no arg is given, try to get it from env
      $USER=$ENV{'USERNAME'};
      if (!$USER)
      {
         $USER=$ENV{'USER'}; 
      }
      if (!$USER)
      {
         $USER=$ENV{'BSYSUSER'};
      }
   }
   
   if (!$USER)
   {
      die("SSS startup error: USER not defined");
   }
   else
   {
      #debug print("debug: <$USER> \n");
      return($USER);
   }
}

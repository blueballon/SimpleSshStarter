#!/usr/bin/perl
# This program is licensed under GPL v2
# program version 2006/02/02
use strict;
use warnings;
use Tk;
use XML::Simple;
#debug  
use Data::Dumper;

### MAIN PROGRAM SETTINGS ###########################################################
### please edit the following lines to meet your own needs

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

### END MAIN PROGRAM SETTINGS #######################################################

# configfile settings
my $XMLfile="~/".$USERSETTING;
if ($ENV{'HOME'})
{
   $XMLfile=$ENV{'HOME'}."/".$USERSETTING;                      
}
my $XMLmasterfile=$MASTERSETTINGUNIX;  
my $XMLmastersys=$SYSSETTINGUNIX; 

# execution settings
my $remoteExec=$EXECSSHUNIX;
my $localExec=$EXECLOCALUNIX;

# windows-specific settings
if ($^O=~/MSWin32/)
{
	$remoteExec=$EXECSSHWIN;
	$localExec=$EXECLOCALWIN;
	$XMLmastersys=$SYSSETTINGWIN; 
	$XMLmasterfile=$MASTERSETTINGWIN;
}



#readXMLsettings

my @displayList;
my @commandList;
my @machineList;
my @descriptionList;
my @defaultArgList;
my @needArgList;

# settings ar put to the lists, and the status is put to the strings (to be displayed later)
my $localXMLstatus=readXMLsettings($XMLfile,\@displayList,\@commandList,\@machineList,
        \@descriptionList,\@defaultArgList,\@needArgList);
my $masterXMLstatus=readXMLsettings($XMLmasterfile,\@displayList,\@commandList,
        \@machineList,\@descriptionList,\@defaultArgList,\@needArgList);
my $sysXMLstatus=readXMLsettings($XMLmastersys,\@displayList,\@commandList,
        \@machineList,\@descriptionList,\@defaultArgList,\@needArgList);

#debug print Dumper(\@descriptionList);

# set up windows
my $mw = MainWindow->new;
$mw->title("SSS");
my $infoWin=undef;      # the handle for the information window
my $argsWin=undef;      # the handle for the argument input window
my $execOutputString="";   # the big string for all exec outputs
my $outputField=undef;  # info output file, only to keep the reference between button events
my $argEntry=undef;     # arg input field, only to keep the reference between button events


# build and display the list contents (orig height 16)
my $lb = $mw->Scrolled( "Listbox", 
                        -scrollbars => "e", 
                        -height => 24,  
                        -width => 0,
                        -selectmode => "single" )->grid(-sticky=>"nsew",
                                                        -row=>0, 
                                                        -column=>0);
#my @starterList=getStarterList(); 
my @starterList=@displayList;
$lb->insert('end', @starterList);


# build and display the buttones 
$mw->Button(-text => "Execute", 
            -command => sub { execSSH($lb,
	                                  \$execOutputString,
	                                  \@commandList,
	                                  \@machineList,
	                                  $remoteExec,
                                      $localExec)})->grid(-sticky=>"nsew",-row=>1,
	                                                       -column => 0);
	                                                       
$mw->Button(-text => "Execute with args", 
            -command => sub { handleExec("true",
            	                          $lb,
                                       \$execOutputString,
                                       \@commandList,
                                       \@machineList,
                                       \@defaultArgList,
                                       \@needArgList,
                                       $remoteExec,
                                       $localExec,
                                       \$argsWin,
                                       \$argEntry,
                                       $mw)})->grid(-sticky=>"nsew",-row=>2,
	                                                       -column => 0);
# TODO exec with args
# TODO if needargs, always take exec with args	                                                       
$mw->Button(-text => "Item information", 
            -command => sub { handleInfoWindow(\$infoWin, 
            	                                  $mw, 
            	                                  "item",
            	                                  $lb,
            	                                  \@descriptionList,
            	                                  \$outputField,
            	                                  \$execOutputString) })->grid(-sticky=>"nsew", 
                                                                           -row=>3,
                                                                           -column => 0); 	  
                                            
$mw->Button(-text => "SSS information", 
            -command => sub { handleInfoWindow(\$infoWin, 
            	                                  $mw, 
            	                                  "program",
            	                                  $lb,
            	                                  \@descriptionList,
            	                                  \$outputField,
            	                                  \$execOutputString) })->grid(-sticky=>"nsew", 
                                                                           -row=>4,
                                                                           -column => 0);                                                                                                  

$mw->Button(-text => "Exit", 
            -command => sub { exit })->grid(-sticky=>"nsew", 
                                            -row=>5,
                                            -column => 0);


# the main program loop
MainLoop;

#####################################################################################

sub handleExec
{
	my $userWantsArg=$_[0];
	my $listbox=$_[1];
	my $outTextRef=$_[2];
        my $cmdListRef=$_[3];
	my $mchListRef=$_[4];
	my $defaultArgListRef=$_[5];
	my $needsArgListRef=$_[6];
	my $remCmd=$_[7];
	my $locCmd=$_[8];
	my $argsWinHandleRef=$_[9];
        my $argEntryRef=$_[10];
	my $mainWinHandle=$_[11];
	
	my $date = localtime();
	my @cmdList = $lb->curselection();
	#cmdList should ony contain 1 item
    my $command=pop(@cmdList);
    if (!defined($command))
    {
   	   $$outTextRef=$$outTextRef . "Nothing selected at <$date>\n";
    	   return(0);
    }
    
    # get the values for the actual command from the lists
    my $aktCmd=$$cmdListRef[$command];
    my $aktMch=$$mchListRef[$command];
    my $aktNeedArg=$$needsArgListRef[$command];
    # TODO entscheiden, ob immer zumindest mit defaultArg oder bei normalem exec komplett ohne arg ausgefuehrt wird
	#debug 	
	print Dumper($defaultArgListRef);
    my $actArg=$$defaultArgListRef[$command];
    #debug
    print("actArg=<$actArg>\n");
    if (!$aktMch)
    {
    	   $aktMch="local";
    }
    
    # check if we exec with or without args
    my $requireArgs="false";
    if (($userWantsArg eq "true") || (defined($aktNeedArg)))
    {
        $requireArgs="true";
    }
    
    if ($requireArgs eq "true")
    {
        # let user redefine aktArg  
	    handleArgsWindow($argsWinHandleRef, 
               	        $mainWinHandle, 
               	        $argEntryRef,
             	        \$actArg);
    }
    
    # now actArg is correct defined, so we can start the execution
}

sub execSSH
{
	my $listbox=$_[0];
	my $outTextRef=$_[1];
        my $cmdListRef=$_[2];
	my $mchListRef=$_[3];
	my $remCmd=$_[4];
	my $locCmd=$_[5];
	
	
	my $date = localtime();
	my @cmdList = $lb->curselection();
	#cmdList should ony contain 1 item
    my $command=pop(@cmdList);
    if (!$command)
    {
    	   $$outTextRef=$$outTextRef . "Nothing selected at <$date>\n";
    	   return(0);
    }
    my $aktCmd=$$cmdListRef[$command];
    my $aktMch=$$mchListRef[$command];
    if (!$aktMch)
    {
    	   $aktMch="local";
    }
	#print("command was: <$command>\n");	
	
	$$outTextRef=$$outTextRef . "Running command  <$aktCmd> on <$aktMch> at <$date>\n";
	#TODO: add passed exec arguments, feature exec with args exists

	my $execString;
	if ($aktMch eq "local")
	{
		$execString=$locCmd . " " . $aktCmd . " 2>&1";		
	}
	else
	{
		$execString=$remCmd . " " . $aktMch . " " . $aktCmd . " 2>&1";	
	}
	my @result=`$execString`;
#	TODO aendern von outtext auf outTextRef+Anpassung von printListToText
#	ausserdem vergleichen mit etf version, imho hat sich da was geaendert!!
#	printListToText($outtext,\@result);
}


sub readXMLsettings
{
	my $XMLfile=$_[0];
	my $dspListRef=$_[1];
	my $cmdListRef=$_[2];
	my $mchListRef=$_[3];
	my $descListRef=$_[4];
	my $defaultArgListRef=$_[5];
	my $needArgListRef=$_[6];
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
	#debug 	
	print Dumper($xmlSettings);
	my $sssItemListRef=${$xmlSettings}{'sssitem'};
	my $aktItem;
	foreach $aktItem (@$sssItemListRef)
	{
		push(@$dspListRef,${${$aktItem}{'display'}}[0]);
		push(@$cmdListRef,${${$aktItem}{'command'}}[0]);
		push(@$mchListRef,${${$aktItem}{'machine'}}[0]);
		push(@$descListRef,${${$aktItem}{'desc'}}[0]);
		push(@$defaultArgListRef,${${$aktItem}{'defaultarg'}}[0]);
		push(@$needArgListRef,${${$aktItem}{'needsarg'}}[0]);
		#print("${${$aktItem}{'display'}}[0]\n");	
	}
	
	#return value;
	$status="configfile <$XMLfile> read";
}


# usage: handleInfoWindow($infoWinHandle, $mainWinHandle);
sub handleInfoWindow 
{
	my $infoHandleRef=$_[0];
	my $mainWinHandle=$_[1];
	my $outputMode=$_[2];
	my $listbox=$_[3];
	my $descListRef=$_[4];
	my $outFieldRef=$_[5];
	my $execOutStrRef=$_[6];
	
	#print $execOutputString;
	
    if (! Exists($$infoHandleRef))    # the window is closed at the moment
    {
        $$infoHandleRef = $mainWinHandle->Toplevel( );
        $$infoHandleRef->title("SSS information window");
        $$outFieldRef = $$infoHandleRef->Scrolled( "Text", 
                              -scrollbars => "e",
                              -relief => "groove",
                              -width => 80, 
                              -height => 31, 
                              -state => 'disabled' )->grid(-row=>0, 
                                                         -column=>0);
                      
        $$infoHandleRef->Button(-text => "OK", 
            -command => sub { $$infoHandleRef->withdraw })->grid(-row=>1, 
                                                         -column=>0);
                                                         
        if ($outputMode eq "program")         
        {
        	    DoProgramInfoOutput($outFieldRef,$execOutStrRef);  
        }
        else
        {
        	    DoItemInfoOutput($outFieldRef,$listbox,$descListRef);
        }                                                 
    } 
    else # the window is already open
    {
    	    if ($outputMode eq "program")         
        {
        	    DoProgramInfoOutput($outFieldRef,$execOutStrRef);
        }
        else
        {
        	    DoItemInfoOutput($outFieldRef,$listbox,$descListRef);
        }
        
        $$infoHandleRef->deiconify( );
        $$infoHandleRef->raise( );
    }
}


# usage: handleInfoWindow($infoWinHandle, $mainWinHandle);
sub handleArgsWindow 
{
    my $argsHandleRef=$_[0];
    my $mainWinHandle=$_[1];
    my $argEntryRef=$_[2];
    my $actArgRef=$_[3];
	
    print("actArg(Window, before)=<$$actArgRef>\n");  
	#print $execOutputString;
	
    if (! Exists($$argsHandleRef))    # the window is closed at the moment
    {
        $$argsHandleRef = $mainWinHandle->Toplevel( );
        $$argsHandleRef->title("Enter arguments");
        $$argEntryRef =  $$argsHandleRef->Entry(-relief => "groove",
                              -width => 80, 
                              -textvariable => $actArgRef,
                              -state => 'disabled' )->grid(-row=>0, 
                                                         -column=>0,
                                                         -columnspan => 2,
                                                         -sticky=>"nsew");
                      
        $$argsHandleRef->Button(-text => "OK", 
            -command => sub { $$argsHandleRef->destroy })->grid(-row=>1, 
                                                         -column=>0,
                                                         -sticky=>"w");
                                                         
        $$argsHandleRef->Button(-text => "Cancel", 
            -command => sub { $$argsHandleRef->destroy })->grid(-row=>1, 
                                                         -column=>1,
                                                         -sticky=>"e");                                                  
        $$argEntryRef->configure(-state => 'normal');          
        # TODO hier fortsetzen          
        print("actArg(Window, after)=<$$actArgRef>\n"); 
                                                
    } 
    else # the window is already open
    {

        # TODO hier fortsetzen 
        $$argEntryRef->configure(-state => 'disabled');
        $$argEntryRef->configure(-textvariable => $actArgRef); 
        $$argEntryRef->configure(-state => 'normal'); 
        $$argsHandleRef->deiconify( );
        $$argsHandleRef->raise( );
    }
    
    print("bin am ende von hadelArgsWindow\n");
}

# Attention: this rouine reads directly from $localXMLstatus,$masterXMLstatus,$sysXMLstatus
sub DoProgramInfoOutput
{
    my $outputFieldRef=$_[0];
    my $execOutStrRef=$_[1];
	
    #print $$execOutStrRef;
	
    $$outputFieldRef->configure(-state => 'normal');
    $$outputFieldRef->delete("1.0", 'end');
    $$outputFieldRef->insert('end', "Simple SSH/Script Starter Version 0.3 (2006/07/12)\n");
    $$outputFieldRef->insert('end', "Report bugs, comments, etc to blue.balloon\@gmx.net\n");
    $$outputFieldRef->insert('end', "--------------------------------------------------\n");
    $$outputFieldRef->insert('end', "Local settings: $localXMLstatus\n");
    $$outputFieldRef->insert('end', "Master settings: $masterXMLstatus\n");
    $$outputFieldRef->insert('end', "System settings: $sysXMLstatus\n");
    $$outputFieldRef->insert('end', "--------------------------------------------------\n");
    # TODO: add all launch informations here (each exec adds this to one big string)
    $$outputFieldRef->insert('end', $$execOutStrRef);
    $$outputFieldRef->configure(-state => 'disabled');
}


sub DoItemInfoOutput
{
    my $outputFieldRef=$_[0];
    my $listbox=$_[1];
    my $descListRef=$_[2];
	
    my $outtext="Nothing to say!\nYet!";
	
    #debug
    print Dumper($descListRef);
	
    my @cmdList = $listbox->curselection();
	#cmdList should ony contain 1 item
    my $command=pop(@cmdList);
    if (!defined($command))
    {
    	    $outtext="No item selected!";
    }
    else
    {
        my $aktDesc=$$descListRef[$command];
        #debug
        print("command <$command> -  desc <$aktDesc>\n");
        if (!$aktDesc)
        {
    	        $outtext="No description available for this item!";
        }
        else
        {
    	        $outtext=$aktDesc;
    	        #chomp($outtext);
    	        $outtext=~s/\n\s+/\n/g;
        }
    }
    $$outputFieldRef->configure(-state => 'normal');
    $$outputFieldRef->delete("1.0", 'end');
    $$outputFieldRef->insert('end', $outtext);	
    $$outputFieldRef->configure(-state => 'disabled');
}

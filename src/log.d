import std.stdio;
import std.file;
import std.datetime;
import std.process;
import std.conv;
import core.sys.posix.pwd, core.sys.posix.unistd, core.stdc.string : strlen;
import std.algorithm : splitter;
version(Notifications) {
	import dnotify;
}

// enable verbose logging
int verbose;
bool writeLogFile = false;

private bool doNotifications;

// shared string variable for username
string username;
string logFilePath;

void init(string logDir)
{
	writeLogFile = true;
	username = getUserName();
	logFilePath = logDir;
	
	if (!exists(logFilePath)){
		// logfile path does not exist
		try {
			mkdirRecurse(logFilePath);
		} 
		catch (std.file.FileException e) {
			// we got an error ..
			writeln("\nUnable to access ", logFilePath);
			writeln("Please manually create '",logFilePath, "' and set appropriate permissions to allow write access");
			writeln("The requested client activity log will instead be located in the users home directory\n");
		}
	}
}

void setNotifications(bool value)
{
	doNotifications = value;
}

void log(T...)(T args)
{
	writeln(args);
	if(writeLogFile){
		// Write to log file
		logfileWriteLine(args);
	}
}

void logAndNotify(T...)(T args)
{
	notify(args);
	log(args);
}

void fileOnly(T...)(T args)
{
	if(writeLogFile){
		// Write to log file
		logfileWriteLine(args);
	}
}

void vlog(T...)(T args)
{
	if (verbose >= 1) {
		writeln(args);
		if(writeLogFile){
			// Write to log file
			logfileWriteLine(args);
		}
	}
}

void vdebug(T...)(T args)
{
	if (verbose >= 2) {
		writeln("[DEBUG] ", args);
		if(writeLogFile){
			// Write to log file
			logfileWriteLine("[DEBUG] ", args);
		}
	}
}

void error(T...)(T args)
{
	stderr.writeln(args);
	if(writeLogFile){
		// Write to log file
		logfileWriteLine(args);
	}
}

void errorAndNotify(T...)(T args)
{
	notify(args);
	error(args);
}

void notify(T...)(T args)
{
	version(Notifications) {
		if (doNotifications) {
			string result;
			foreach (index, arg; args) {
				result ~= to!string(arg);
				if (index != args.length - 1)
					result ~= " ";
			}
			auto n = new Notification("OneDrive", result, "IGNORED");
			try {
				n.show();
			} catch (Throwable e) {
				vlog("Got exception from showing notification: ", e);
			}
		}
	}
}

private void logfileWriteLine(T...)(T args)
{
	// Write to log file
	string logFileName = .logFilePath ~ .username ~ ".onedrive.log";
	auto currentTime = Clock.currTime();
	auto timeString = currentTime.toString();
	File logFile;
	
	// Resolve: std.exception.ErrnoException@std/stdio.d(423): Cannot open file `/var/log/onedrive/xxxxx.onedrive.log' in mode `a' (Permission denied)
	try {
		logFile = File(logFileName, "a");
		} 
	catch (std.exception.ErrnoException e) {
		// We cannot open the log file in logFilePath location for writing
		// The user is not part of the standard 'users' group (GID 100)
		// Change logfile to ~/onedrive.log putting the log file in the users home directory
		string homePath = environment.get("HOME");
		string logFileNameAlternate = homePath ~ "/onedrive.log";
		logFile = File(logFileNameAlternate, "a");
	} 
	// Write to the log file
	logFile.writeln(timeString, " ", args);
	logFile.close();
}

private string getUserName()
{
	auto pw = getpwuid(getuid);
	auto uinfo = pw.pw_gecos[0 .. strlen(pw.pw_gecos)].splitter(',');
	if (!uinfo.empty && uinfo.front.length){
		return uinfo.front.idup;
	} else {
		// Unknown user?
		return "unknown";
	}
}

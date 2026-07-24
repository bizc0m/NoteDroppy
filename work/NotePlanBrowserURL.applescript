on urlEncode(inputText)
	set pythonCode to "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=''))"
	return do shell script "/usr/bin/python3 -c " & quoted form of pythonCode & " <<< " & quoted form of inputText
end urlEncode

on firstBrowserURL()
	try
		set safariURL to do shell script "/usr/bin/osascript -e 'tell application \"Safari\"' -e 'if (count of documents) > 0 then return URL of front document' -e 'end tell' 2>/dev/null"
		if safariURL is not "" then return safariURL
	end try
	
	try
		set cometScript to "tell application \"Comet\" to if (count of windows) > 0 then return URL of active tab of front window"
		set cometURL to do shell script "/usr/bin/osascript -e " & quoted form of cometScript
		if cometURL is not "" then return cometURL
	end try
	try
		set chromeScript to "tell application \"Google Chrome\" to if (count of windows) > 0 then return URL of active tab of front window"
		set chromeURL to do shell script "/usr/bin/osascript -e " & quoted form of chromeScript
		if chromeURL is not "" then return chromeURL
	end try
	try
		set arcScript to "tell application \"Arc\" to if (count of windows) > 0 then return URL of active tab of front window"
		set arcURL to do shell script "/usr/bin/osascript -e " & quoted form of arcScript
		if arcURL is not "" then return arcURL
	end try
	try
		set braveScript to "tell application \"Brave Browser\" to if (count of windows) > 0 then return URL of active tab of front window"
		set braveURL to do shell script "/usr/bin/osascript -e " & quoted form of braveScript
		if braveURL is not "" then return braveURL
	end try
	try
		set edgeScript to "tell application \"Microsoft Edge\" to if (count of windows) > 0 then return URL of active tab of front window"
		set edgeURL to do shell script "/usr/bin/osascript -e " & quoted form of edgeScript
		if edgeURL is not "" then return edgeURL
	end try
	
	return ""
end firstBrowserURL

on run
	set pageURL to my firstBrowserURL()
	
	if pageURL is "" then
		display notification "Aucune URL navigateur trouvee." with title "NotePlan URL"
		return
	end if
	
	set taskText to "- [ ] " & pageURL & " #capture"
	set encodedText to my urlEncode(taskText)
	open location "noteplan://x-callback-url/addText?noteDate=today&text=" & encodedText & "&mode=append&openNote=yes"
	display notification "URL ajoutee dans NotePlan." with title "NotePlan URL"
end run

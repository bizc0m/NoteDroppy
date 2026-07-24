on urlEncode(inputText)
	set pythonCode to "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=''))"
	return do shell script "/usr/bin/python3 -c " & quoted form of pythonCode & " <<< " & quoted form of inputText
end urlEncode

on run
	try
		set clipText to the clipboard as text
	on error
		set clipText to ""
	end try
	
	set clipText to do shell script "/bin/echo " & quoted form of clipText & " | /usr/bin/sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'"
	
	if clipText is "" then
		display dialog "Presse-papiers vide. Copie du texte avec Cmd+C, puis relance NotePlanClip." buttons {"OK"} default button "OK" with title "NotePlanClip"
		return
	end if
	
	set picked to choose from list {"Todo aujourd'hui", "Creer une note"} with title "NotePlanClip" with prompt "Envoyer le presse-papiers vers NotePlan :" default items {"Todo aujourd'hui"}
	if picked is false then return
	set actionName to item 1 of picked
	
	if actionName is "Todo aujourd'hui" then
		set taskText to "- [ ] " & clipText & " #capture"
		set encodedText to my urlEncode(taskText)
		open location "noteplan://x-callback-url/addText?noteDate=today&text=" & encodedText & "&mode=append&openNote=yes"
	else
		set stamp to do shell script "/bin/date '+%Y-%m-%d %H:%M'"
		set noteTitle to "Capture " & stamp
		set noteBody to "## Source" & linefeed & "NotePlanClip - " & stamp & linefeed & linefeed & "## Todo" & linefeed & "- [ ] Traiter cette capture" & linefeed & linefeed & "## Contenu" & linefeed & clipText
		set encodedTitle to my urlEncode(noteTitle)
		set encodedBody to my urlEncode(noteBody)
		open location "noteplan://x-callback-url/addNote?noteTitle=" & encodedTitle & "&text=" & encodedBody & "&folder=Inbox&openNote=yes"
	end if
end run

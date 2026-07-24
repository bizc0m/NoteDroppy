on urlEncode(inputText)
	set pythonCode to "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=''))"
	return do shell script "/usr/bin/python3 -c " & quoted form of pythonCode & " <<< " & quoted form of inputText
end urlEncode

on trimText(inputText)
	return do shell script "/bin/echo " & quoted form of inputText & " | /usr/bin/sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'"
end trimText

on run
	try
		set clipText to the clipboard as text
	on error
		set clipText to ""
	end try
	
	set clipText to my trimText(clipText)
	
	if clipText is "" then
		display notification "Copie d'abord du texte ou une URL avec Cmd+C." with title "NotePlan Todo"
		return
	end if
	
	set taskText to "- [ ] " & clipText & " #capture"
	set encodedText to my urlEncode(taskText)
	open location "noteplan://x-callback-url/addText?noteDate=today&text=" & encodedText & "&mode=append&openNote=yes"
	display notification "Todo ajoutee dans NotePlan." with title "NotePlan Todo"
end run
